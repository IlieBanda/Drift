import SwiftUI
import UserNotifications

final class DriftAppDelegate: NSObject, NSApplicationDelegate {
    var store: TorrentStore?
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !(store?.appSettings.keepRunningInBackground ?? false)
    }
}

@main
struct DriftApp: App {
    @State private var store = TorrentStore()
    @NSApplicationDelegateAdaptor(DriftAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Drift") {
            ContentView(store: store)
                .frame(minWidth: 980, minHeight: 620)
                .task {
                    appDelegate.store = store
                    LocalNetworkPermission.request()
                    try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                    store.loadSavedConnection(); await store.refresh(); store.startPolling()
                }
                .onOpenURL { url in
                    Task {
                        if url.scheme?.lowercased() == "magnet" {
                            await store.add(url.absoluteString)
                        } else if url.isFileURL, let data = try? Data(contentsOf: url) {
                            await store.addTorrentFile(data: data)
                        }
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Drift") { showAboutPanel() }
            }
            CommandGroup(after: .newItem) {
                Button("Add Torrent…") { store.showAddSheet = true }
                    .keyboardShortcut("o", modifiers: [.command])
            }
            CommandMenu("List Style") {
                ForEach(TorrentRowStyle.allCases) { style in
                    Button {
                        store.appSettings.rowStyle = style
                    } label: {
                        if store.appSettings.rowStyle == style { Label(style.title, systemImage: "checkmark") } else { Text(style.title) }
                    }
                }
            }
            CommandMenu("Torrent") {
                Button("Start All") { Task { await store.startAll() } }.disabled(store.torrents.isEmpty)
                Button("Pause All") { Task { await store.pauseAll() } }.disabled(store.torrents.isEmpty)
            }
            CommandGroup(after: .pasteboard) {
                Button("Select All Torrents") { store.selectedIDs = Set(store.visibleTorrents.map(\.id)) }
                    .keyboardShortcut("a", modifiers: [.command])
                    .disabled(store.visibleTorrents.isEmpty)
                Button("Deselect All") { store.selectedIDs = [] }
                    .keyboardShortcut("a", modifiers: [.command, .shift])
                    .disabled(store.selectedIDs.isEmpty)
            }
        }
        Settings { PreferencesView(store: store) }
    }

    private func showAboutPanel() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let credits = NSMutableAttributedString(
            string: String(localized: "by Ilia Banda") + "\n",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .paragraphStyle: paragraph]
        )
        credits.append(NSAttributedString(
            string: "GitHub",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .paragraphStyle: paragraph,
                .link: URL(string: "https://github.com/IlieBanda/Drift")!
            ]
        ))
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .credits: credits,
            .applicationName: "Drift",
            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): "© 2026"
        ])
    }
}
