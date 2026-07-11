import SwiftUI

struct TorrentDetail: Identifiable {
    let id: Int
    let name: String
    let hash: String
    let comment: String
    let isPrivate: Bool
    let addedDate: Date
    let doneDate: Date?
    let totalSize: String
    let downloaded: String
    let uploaded: String
    let corrupt: String
    let ratio: Double
    let errorString: String
    let downloadSpeed: String
    let uploadSpeed: String
    let peersConnected: Int
    let trackers: [TrackerInfo]
    let peers: [PeerInfo]
    let files: [FileEntry]

    init(remote: RemoteTorrentDetail) {
        id = remote.id
        name = remote.name
        hash = remote.hashString
        comment = remote.comment
        isPrivate = remote.isPrivate
        addedDate = Date(timeIntervalSince1970: TimeInterval(remote.addedDate))
        doneDate = remote.doneDate > 0 ? Date(timeIntervalSince1970: TimeInterval(remote.doneDate)) : nil
        totalSize = ByteCountFormatter.string(fromByteCount: remote.totalSize, countStyle: .file)
        downloaded = ByteCountFormatter.string(fromByteCount: remote.downloadedEver, countStyle: .file)
        uploaded = ByteCountFormatter.string(fromByteCount: remote.uploadedEver, countStyle: .file)
        corrupt = ByteCountFormatter.string(fromByteCount: remote.corruptEver, countStyle: .file)
        ratio = remote.uploadRatio
        errorString = remote.errorString
        downloadSpeed = remote.rateDownload > 0 ? ByteCountFormatter.string(fromByteCount: Int64(remote.rateDownload), countStyle: .binary) + "/s" : "—"
        uploadSpeed = remote.rateUpload > 0 ? ByteCountFormatter.string(fromByteCount: Int64(remote.rateUpload), countStyle: .binary) + "/s" : "—"
        peersConnected = remote.peersConnected
        trackers = remote.trackerStats.map(TrackerInfo.init)
        peers = remote.peers.map(PeerInfo.init)
        let stats = remote.fileStats
        files = remote.files.enumerated().map { index, file in
            FileEntry(
                index: index,
                name: file.name,
                size: file.length,
                bytesCompleted: file.bytesCompleted,
                wanted: index < stats.count ? stats[index].wanted : true,
                priority: FilePriority(rpcValue: index < stats.count ? stats[index].priority : 0)
            )
        }
    }

    var ratioText: String { ratio < 0 ? "—" : ratio.formatted(.number.precision(.fractionLength(2))) }
}

struct TrackerInfo: Identifiable {
    var id: String { announce }
    let announce: String
    let host: String
    let seeders: Int
    let leechers: Int
    let succeeded: Bool
    let lastResult: String

    init(remote: RemoteTrackerStat) {
        announce = remote.announce
        host = remote.host
        seeders = remote.seederCount
        leechers = remote.leecherCount
        succeeded = remote.lastAnnounceSucceeded
        lastResult = remote.lastAnnounceResult
    }
}

struct PeerInfo: Identifiable {
    var id: String { address }
    let address: String
    let client: String
    let progress: Double
    let downloadSpeed: String
    let uploadSpeed: String
    let isEncrypted: Bool

    init(remote: RemotePeer) {
        address = remote.address
        client = remote.clientName
        progress = remote.progress
        downloadSpeed = remote.rateToClient > 0 ? ByteCountFormatter.string(fromByteCount: Int64(remote.rateToClient), countStyle: .binary) + "/s" : "—"
        uploadSpeed = remote.rateToPeer > 0 ? ByteCountFormatter.string(fromByteCount: Int64(remote.rateToPeer), countStyle: .binary) + "/s" : "—"
        isEncrypted = remote.isEncrypted
    }
}

struct FileEntry: Identifiable {
    var id: Int { index }
    let index: Int
    let name: String
    let size: Int64
    let bytesCompleted: Int64
    let wanted: Bool
    let priority: FilePriority

    var sizeText: String { ByteCountFormatter.string(fromByteCount: size, countStyle: .file) }
    var progress: Double { size > 0 ? Double(bytesCompleted) / Double(size) : 0 }
}

enum FilePriority: Int, CaseIterable {
    case low = -1
    case normal = 0
    case high = 1

    init(rpcValue: Int) { self = FilePriority(rawValue: rpcValue) ?? .normal }

    var rpcKey: String {
        switch self {
        case .low: "priority-low"
        case .normal: "priority-normal"
        case .high: "priority-high"
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .low: "Low"
        case .normal: "Normal"
        case .high: "High"
        }
    }
}
