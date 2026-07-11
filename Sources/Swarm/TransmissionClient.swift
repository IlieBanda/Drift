import Foundation

protocol RPCEnvelope: Decodable { var result: String { get } }
struct RPCResponse: RPCEnvelope { let arguments: TorrentArguments?; let result: String }
struct TorrentArguments: Decodable { let torrents: [RemoteTorrent]? }
struct RemoteTorrent: Decodable { let id: Int; let name: String; let status: Int; let percentDone: Double; let rateDownload: Int; let rateUpload: Int; let totalSize: Int64; let eta: Int; let uploadedEver: Int64; let downloadedEver: Int64; let uploadRatio: Double; let peersConnected: Int; let peersSendingToUs: Int; let peersGettingFromUs: Int }
struct SessionGetResponse: RPCEnvelope { let arguments: SessionSettings; let result: String }
struct FreeSpaceResponse: RPCEnvelope { let arguments: FreeSpaceArguments; let result: String }
struct FreeSpaceArguments: Decodable { let sizeBytes: Int64; enum CodingKeys: String, CodingKey { case sizeBytes = "size-bytes" } }
struct TorrentDetailResponse: RPCEnvelope { let arguments: TorrentDetailArguments; let result: String }
struct TorrentDetailArguments: Decodable { let torrents: [RemoteTorrentDetail] }

struct RemoteTorrentDetail: Decodable {
    let id: Int
    let name: String
    let hashString: String
    let comment: String
    let isPrivate: Bool
    let addedDate: Int
    let doneDate: Int
    let totalSize: Int64
    let sizeWhenDone: Int64
    let downloadedEver: Int64
    let uploadedEver: Int64
    let corruptEver: Int64
    let uploadRatio: Double
    let errorString: String
    let rateDownload: Int
    let rateUpload: Int
    let peersConnected: Int
    let trackerStats: [RemoteTrackerStat]
    let peers: [RemotePeer]
    let files: [RemoteFileEntry]
    let fileStats: [RemoteFileStat]
}

struct RemoteTrackerStat: Decodable {
    let announce: String
    let host: String
    let tier: Int
    let seederCount: Int
    let leecherCount: Int
    let lastAnnounceSucceeded: Bool
    let lastAnnounceResult: String
    let lastAnnounceTime: Int
}

struct RemotePeer: Decodable {
    let address: String
    let clientName: String
    let progress: Double
    let rateToClient: Int
    let rateToPeer: Int
    let isEncrypted: Bool
}

struct RemoteFileEntry: Decodable { let name: String; let length: Int64; let bytesCompleted: Int64 }
struct RemoteFileStat: Decodable { let wanted: Bool; let priority: Int; let bytesCompleted: Int64 }

final class TransmissionClient {
    var endpoint: URL
    var username: String
    var password: String
    private var sessionID: String?
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 15
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }()

    init(endpoint: URL = URL(string: "http://localhost:9091/transmission/rpc")!, username: String = "", password: String = "") { self.endpoint = endpoint; self.username = username; self.password = password }

    enum ClientError: LocalizedError { case http(Int); case rpc(String); var errorDescription: String? { switch self { case .http(let code): "Transmission returned HTTP \(code)"; case .rpc(let result): "Transmission RPC error: \(result)" } } }

    func getTorrents() async throws -> [RemoteTorrent] {
        let response: RPCResponse = try await request(method: "torrent-get", arguments: ["fields": ["id", "name", "status", "percentDone", "rateDownload", "rateUpload", "totalSize", "eta", "uploadedEver", "downloadedEver", "uploadRatio", "peersConnected", "peersSendingToUs", "peersGettingFromUs"]])
        return response.arguments?.torrents ?? []
    }

    func send(_ method: String, ids: [Int]) async throws { _ = try await request(method: method, arguments: ["ids": ids]) as RPCResponse }

    func sendToAll(_ method: String) async throws { _ = try await request(method: method, arguments: [:]) as RPCResponse }

    func add(magnet: String) async throws { _ = try await request(method: "torrent-add", arguments: ["filename": magnet]) as RPCResponse }

    func add(metainfo: String) async throws { _ = try await request(method: "torrent-add", arguments: ["metainfo": metainfo]) as RPCResponse }

    func remove(ids: [Int], deleteData: Bool) async throws { _ = try await request(method: "torrent-remove", arguments: ["ids": ids, "delete-local-data": deleteData]) as RPCResponse }

    func getSession() async throws -> SessionSettings {
        let response: SessionGetResponse = try await request(method: "session-get", arguments: [:])
        return response.arguments
    }

    func setSession(_ arguments: [String: Any]) async throws { _ = try await request(method: "session-set", arguments: arguments) as RPCResponse }

    func getFreeSpace(path: String) async throws -> Int64 {
        let response: FreeSpaceResponse = try await request(method: "free-space", arguments: ["path": path])
        return response.arguments.sizeBytes
    }

    func getTorrentDetail(id: Int) async throws -> RemoteTorrentDetail? {
        let fields = ["id", "name", "hashString", "comment", "isPrivate", "addedDate", "doneDate", "totalSize", "sizeWhenDone", "downloadedEver", "uploadedEver", "corruptEver", "uploadRatio", "errorString", "rateDownload", "rateUpload", "peersConnected", "trackerStats", "peers", "files", "fileStats"]
        let response: TorrentDetailResponse = try await request(method: "torrent-get", arguments: ["ids": [id], "fields": fields])
        return response.arguments.torrents.first
    }

    func setFilesWanted(id: Int, indices: [Int], wanted: Bool) async throws {
        let key = wanted ? "files-wanted" : "files-unwanted"
        _ = try await request(method: "torrent-set", arguments: ["ids": [id], key: indices]) as RPCResponse
    }

    func setFilePriority(id: Int, indices: [Int], priority: FilePriority) async throws {
        _ = try await request(method: "torrent-set", arguments: ["ids": [id], priority.rpcKey: indices]) as RPCResponse
    }

    func setLocation(ids: [Int], location: String, move: Bool) async throws {
        _ = try await request(method: "torrent-set-location", arguments: ["ids": ids, "location": location, "move": move]) as RPCResponse
    }

    func renamePath(id: Int, path: String, name: String) async throws {
        _ = try await request(method: "torrent-rename-path", arguments: ["ids": [id], "path": path, "name": name]) as RPCResponse
    }

    private func request<T: Decodable>(method: String, arguments: [String: Any]) async throws -> T {
        for attempt in 0...1 {
            let (data, response) = try await performRequest(method: method, arguments: arguments)
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            if http.statusCode == 409, let id = http.value(forHTTPHeaderField: "X-Transmission-Session-Id"), attempt == 0 {
                sessionID = id
                continue
            }
            guard 200..<300 ~= http.statusCode else { throw ClientError.http(http.statusCode) }
            let decoded = try JSONDecoder().decode(T.self, from: data)
            if let rpc = decoded as? any RPCEnvelope, rpc.result != "success" { throw ClientError.rpc(rpc.result) }
            return decoded
        }
        throw URLError(.userAuthenticationRequired)
    }

    private func performRequest(method: String, arguments: [String: Any]) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: endpoint); request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !username.isEmpty { let token = Data("\(username):\(password)".utf8).base64EncodedString(); request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization") }
        var body: [String: Any] = ["method": method]; body["arguments"] = arguments; request.httpBody = try JSONSerialization.data(withJSONObject: body)
        if let sessionID { request.setValue(sessionID, forHTTPHeaderField: "X-Transmission-Session-Id") }
        return try await session.data(for: request)
    }
}

