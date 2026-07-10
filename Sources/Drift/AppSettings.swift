import Foundation
import Observation
import ServiceManagement

enum TorrentRowStyle: String, CaseIterable, Identifiable {
    case detailed, card
    var id: String { rawValue }
    var title: String {
        switch self {
        case .detailed: String(localized: "Detailed")
        case .card: String(localized: "Card")
        }
    }
}

@MainActor @Observable
final class AppSettings {
    var notifyOnComplete: Bool { didSet { UserDefaults.standard.set(notifyOnComplete, forKey: "notifyOnComplete") } }
    var keepRunningInBackground: Bool { didSet { UserDefaults.standard.set(keepRunningInBackground, forKey: "keepRunningInBackground") } }
    var rowStyle: TorrentRowStyle { didSet { UserDefaults.standard.set(rowStyle.rawValue, forKey: "rowStyle") } }
    var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != (SMAppService.mainApp.status == .enabled) else { return }
            do {
                if launchAtLogin { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                launchAtLoginError = error.localizedDescription
                launchAtLogin.toggle()
            }
        }
    }
    var launchAtLoginError: String?

    init() {
        notifyOnComplete = UserDefaults.standard.object(forKey: "notifyOnComplete") as? Bool ?? true
        keepRunningInBackground = UserDefaults.standard.object(forKey: "keepRunningInBackground") as? Bool ?? false
        rowStyle = TorrentRowStyle(rawValue: UserDefaults.standard.string(forKey: "rowStyle") ?? "") ?? .detailed
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
