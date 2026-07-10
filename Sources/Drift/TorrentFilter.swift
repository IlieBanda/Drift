import SwiftUI

enum TorrentFilter: String, CaseIterable, Identifiable {
    case all, downloading, seeding, paused

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .all: "All"
        case .downloading: "Downloading"
        case .seeding: "Seeding"
        case .paused: "Paused"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "tray.full"
        case .downloading: "arrow.down"
        case .seeding: "arrow.up"
        case .paused: "pause"
        }
    }

    func matches(_ status: Torrent.Status) -> Bool {
        switch self {
        case .all: true
        case .downloading: status == .downloading
        case .seeding: status == .seeding
        case .paused: status == .paused
        }
    }
}
