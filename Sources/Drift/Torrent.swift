import SwiftUI

struct Torrent: Identifiable, Hashable {
    let id: Int
    var name: String
    var status: Status
    var progress: Double
    var speed: String
    var uploadSpeed: String
    var size: String
    var downloaded: String
    var eta: String
    var uploaded: String
    var ratio: Double
    var peersConnected: Int
    var peersSendingToUs: Int
    var peersGettingFromUs: Int

    enum Status: String, CaseIterable {
        case downloading, seeding, paused
        var title: LocalizedStringKey {
            switch self {
            case .downloading: "Downloading"
            case .seeding: "Seeding"
            case .paused: "Paused"
            }
        }
    }

    init(id: Int, name: String, status: Status, progress: Double, speed: String, uploadSpeed: String = "—", size: String, downloaded: String = "—", eta: String, uploaded: String = "—", ratio: Double = 0, peersConnected: Int = 0, peersSendingToUs: Int = 0, peersGettingFromUs: Int = 0) {
        self.id = id; self.name = name; self.status = status; self.progress = progress; self.speed = speed; self.uploadSpeed = uploadSpeed; self.size = size; self.downloaded = downloaded; self.eta = eta; self.uploaded = uploaded; self.ratio = ratio
        self.peersConnected = peersConnected; self.peersSendingToUs = peersSendingToUs; self.peersGettingFromUs = peersGettingFromUs
    }

    init(remote: RemoteTorrent) {
        id = remote.id
        name = remote.name; progress = remote.percentDone; speed = remote.rateDownload > 0 ? ByteCountFormatter.string(fromByteCount: Int64(remote.rateDownload), countStyle: .binary) + "/s" : "—"; uploadSpeed = remote.rateUpload > 0 ? ByteCountFormatter.string(fromByteCount: Int64(remote.rateUpload), countStyle: .binary) + "/s" : "—"; size = ByteCountFormatter.string(fromByteCount: remote.totalSize, countStyle: .file); eta = Torrent.formattedETA(remote.eta); status = switch remote.status { case 6, 5: .seeding; case 0, 1, 2: .paused; default: .downloading }
        downloaded = ByteCountFormatter.string(fromByteCount: remote.downloadedEver, countStyle: .file)
        uploaded = remote.uploadedEver > 0 ? ByteCountFormatter.string(fromByteCount: remote.uploadedEver, countStyle: .file) : "—"
        ratio = remote.uploadRatio
        peersConnected = remote.peersConnected; peersSendingToUs = remote.peersSendingToUs; peersGettingFromUs = remote.peersGettingFromUs
    }

    /// Transmission reports -1 for "no ratio yet" and -2 for "unlimited seeding".
    var ratioText: String {
        ratio < 0 ? "—" : ratio.formatted(.number.precision(.fractionLength(2)))
    }

    /// Tighter than `.formatted(.percent)`, which inserts a locale space before "%" (e.g. Russian "100 %").
    static func percentText(_ progress: Double) -> String {
        "\(Int((progress * 100).rounded()))%"
    }

    /// Transmission reports -1 when it can't estimate a completion time yet.
    static func formattedETA(_ seconds: Int) -> String {
        guard seconds > 0 else { return "—" }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 1
        switch seconds {
        case ..<60: formatter.allowedUnits = [.second]
        case ..<3600: formatter.allowedUnits = [.minute]
        case ..<86400: formatter.allowedUnits = [.hour, .minute]
        default: formatter.allowedUnits = [.day, .hour]
        }
        return formatter.string(from: TimeInterval(seconds)) ?? "—"
    }
}
