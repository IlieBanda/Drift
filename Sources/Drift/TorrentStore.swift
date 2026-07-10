import Foundation
import Observation
import UserNotifications

@MainActor @Observable
final class TorrentStore {
    var torrents: [Torrent]
    var selectedIDs: Set<Int> = []
    var filter: TorrentFilter = .all
    var search = ""
    var showAddSheet = false
    var isConnected = false
    var isConnecting = false
    var errorMessage: String?
    var session: SessionSettings?
    var freeSpace: Int64?
    var inspectorTorrentID: Int?
    var inspectorDetail: TorrentDetail?
    private let client = TransmissionClient()
    var servers: [ServerProfile] = []
    var selectedServerID: UUID?
    private var pollTask: Task<Void, Never>?
    let appSettings = AppSettings()
    private var hasLoadedOnce = false
    private var notifiedCompletedIDs: Set<Int> = []

    static let preview = TorrentStore()

    init(torrents: [Torrent] = []) { self.torrents = torrents }

    func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled, let self, self.isConnected else { continue }
                await self.refresh(silently: true)
                if self.inspectorTorrentID != nil { await self.loadInspectorDetail() }
                tick += 1
                if tick % 10 == 0 { await self.loadSession() }
            }
        }
    }
    func stopPolling() { pollTask?.cancel(); pollTask = nil }
    func loadSavedConnection() { let defaults = UserDefaults.standard; let previous = UserDefaults(suiteName: "ru.iliebanda.Drift"); if let data = defaults.data(forKey: "serverProfiles"), let saved = try? JSONDecoder().decode([ServerProfile].self, from: data), !saved.isEmpty { servers = saved } else if let data = previous?.data(forKey: "serverProfiles"), let saved = try? JSONDecoder().decode([ServerProfile].self, from: data), !saved.isEmpty { servers = saved; persistServers() } else if let legacyHost = previous?.string(forKey: "rpcHost") ?? defaults.string(forKey: "rpcHost"), !legacyHost.isEmpty { servers = [ServerProfile(name: "Transmission", host: legacyHost, port: previous?.string(forKey: "rpcPort") ?? defaults.string(forKey: "rpcPort") ?? "9091", username: previous?.string(forKey: "rpcUsername") ?? defaults.string(forKey: "rpcUsername") ?? "")] ; persistServers() } else { servers = [ServerProfile(name: String(localized: "Local Transmission"), host: "localhost")] }; selectedServerID = UUID(uuidString: defaults.string(forKey: "selectedServerID") ?? "") ?? servers.first?.id; if let selected = selectedServer { apply(selected) } }
    var selectedServer: ServerProfile? { servers.first { $0.id == selectedServerID } }
    func selectServer(_ id: UUID) { selectedServerID = id; UserDefaults.standard.set(id.uuidString, forKey: "selectedServerID"); session = nil; freeSpace = nil; if let server = selectedServer { apply(server); Task { await refresh() } } }
    func addServer() { let server = ServerProfile(name: String(localized: "New Server"), host: "192.168.1.100"); servers.append(server); selectedServerID = server.id; persistServers(); apply(server); isConnected = false }
    func deleteServer(_ id: UUID) { guard servers.count > 1 else { return }; servers.removeAll { $0.id == id }; selectedServerID = servers.first?.id; if let selectedServerID { UserDefaults.standard.set(selectedServerID.uuidString, forKey: "selectedServerID") }; persistServers(); if let selectedServer { apply(selectedServer); Task { await refresh() } } }
    func updateServer(_ server: ServerProfile) { guard let index = servers.firstIndex(where: { $0.id == server.id }) else { return }; servers[index] = server; persistServers(); if server.id == selectedServerID { apply(server) } }
    private func persistServers() { UserDefaults.standard.set(try? JSONEncoder().encode(servers), forKey: "serverProfiles") }
    private func apply(_ server: ServerProfile) { updateConnection(host: server.host, port: server.port, username: server.username, password: server.password) }
    var visibleTorrents: [Torrent] { torrents.filter { filter.matches($0.status) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) } }
    var selectedTorrents: [Torrent] { torrents.filter { selectedIDs.contains($0.id) } }
    /// True when every selected torrent is paused, so the group action becomes "resume".
    var selectionIsPaused: Bool { !selectedTorrents.isEmpty && selectedTorrents.allSatisfy { $0.status == .paused } }
    func refresh(silently: Bool = false) async {
        if !silently { isConnecting = true }
        defer { if !silently { isConnecting = false } }
        do {
            let remote = try await client.getTorrents()
            let updated = remote.map(Torrent.init)
            notifyIfCompleted(updated)
            torrents = updated
            let liveIDs = Set(torrents.map(\.id))
            selectedIDs.formIntersection(liveIDs)
            notifiedCompletedIDs.formIntersection(liveIDs)
            let wasConnected = isConnected
            isConnected = true
            errorMessage = nil
            hasLoadedOnce = true
            if !wasConnected { await loadSession() }
        } catch {
            if !silently { isConnected = false }
            errorMessage = friendly(error)
        }
    }
    private func notifyIfCompleted(_ updated: [Torrent]) {
        for torrent in updated where torrent.progress >= 1 && !notifiedCompletedIDs.contains(torrent.id) {
            notifiedCompletedIDs.insert(torrent.id)
            let wasIncomplete = torrents.first(where: { $0.id == torrent.id })?.progress ?? 1 < 1
            guard hasLoadedOnce, appSettings.notifyOnComplete, wasIncomplete else { continue }
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Download Complete")
            content.body = torrent.name
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }
    func loadSession() async {
        session = try? await client.getSession()
        if let downloadDir = session?.downloadDir { freeSpace = try? await client.getFreeSpace(path: downloadDir) }
    }
    func updateSpeedLimits(downEnabled: Bool, down: Int, upEnabled: Bool, up: Int) async {
        do {
            try await client.setSession(["speed-limit-down-enabled": downEnabled, "speed-limit-down": down, "speed-limit-up-enabled": upEnabled, "speed-limit-up": up])
            await loadSession()
        } catch { errorMessage = String(localized: "Could not update speed limits") }
    }
    func updateAltSpeed(enabled: Bool, down: Int, up: Int) async {
        do {
            try await client.setSession(["alt-speed-enabled": enabled, "alt-speed-down": down, "alt-speed-up": up])
            await loadSession()
        } catch { errorMessage = String(localized: "Could not update speed limits") }
    }
    func toggleSlowMode() async {
        guard let session else { return }
        do {
            try await client.setSession(["alt-speed-enabled": !session.altSpeedEnabled])
            await loadSession()
        } catch { errorMessage = String(localized: "Could not update speed limits") }
    }
    private func friendly(_ error: Error) -> String {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return "\(error.localizedDescription) (\(nsError.domain) \(nsError.code))" }
        let code = URLError.Code(rawValue: nsError.code)
        switch code {
        case .timedOut: return String(localized: "Server did not respond. Check the host, port, and that Transmission is running.")
        case .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet: return String(localized: "Transmission server is unavailable on the local network. Check that the Mac is reachable and Remote Access is enabled. (network code \(code.rawValue))")
        case .appTransportSecurityRequiresSecureConnection: return String(localized: "This server requires HTTPS. Use an https:// address.")
        default: return String(localized: "Could not reach the Transmission server (\(code.rawValue)).")
        }
    }
    func updateConnection(host: String, port: String, username: String, password: String) { var value = host.trimmingCharacters(in: .whitespacesAndNewlines); if !value.contains("://") { value = "http://\(value)" }; if let existing = URL(string: value), existing.port == nil { value += ":\(port)" }; guard let url = URL(string: "\(value)/transmission/rpc") else { errorMessage = String(localized: "Enter a valid server address, for example 192.168.100.15"); return }; client.endpoint = url; client.username = username; client.password = password }
    func toggle(_ torrents: [Torrent]) async {
        guard !torrents.isEmpty else { return }
        let shouldStart = torrents.allSatisfy { $0.status == .paused }
        do { try await client.send(shouldStart ? "torrent-start" : "torrent-stop", ids: torrents.map(\.id)); await refresh(silently: true) } catch { errorMessage = String(localized: "Action failed") }
    }
    func pauseAll() async { do { try await client.sendToAll("torrent-stop"); await refresh(silently: true) } catch { errorMessage = String(localized: "Action failed") } }
    func startAll() async { do { try await client.sendToAll("torrent-start"); await refresh(silently: true) } catch { errorMessage = String(localized: "Action failed") } }
    func add(_ magnet: String) async { do { try await client.add(magnet: magnet); await refresh() } catch { errorMessage = String(localized: "Could not add torrent") } }
    func addTorrentFile(data: Data) async { do { try await client.add(metainfo: data.base64EncodedString()); await refresh() } catch { errorMessage = String(localized: "Could not add torrent file") } }
    func delete(_ torrents: [Torrent], deleteData: Bool) async {
        guard !torrents.isEmpty else { return }
        do {
            try await client.remove(ids: torrents.map(\.id), deleteData: deleteData)
            selectedIDs.subtract(torrents.map(\.id))
            if let inspectorTorrentID, torrents.contains(where: { $0.id == inspectorTorrentID }) { closeInspector() }
            await refresh(silently: true)
        } catch { errorMessage = String(localized: "Could not remove torrent") }
    }
    func openInspector(for torrentID: Int) { inspectorTorrentID = torrentID; Task { await loadInspectorDetail() } }
    func closeInspector() { inspectorTorrentID = nil; inspectorDetail = nil }
    func loadInspectorDetail() async {
        guard let inspectorTorrentID else { return }
        guard let remote = try? await client.getTorrentDetail(id: inspectorTorrentID) else { return }
        inspectorDetail = TorrentDetail(remote: remote)
    }
    func setFileWanted(fileIndex: Int, wanted: Bool) async {
        guard let inspectorTorrentID else { return }
        do { try await client.setFilesWanted(id: inspectorTorrentID, indices: [fileIndex], wanted: wanted); await loadInspectorDetail() } catch { errorMessage = String(localized: "Could not update file selection") }
    }
}

