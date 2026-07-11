import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct PreferencesView: View {
    var store: TorrentStore
    var body: some View {
        TabView {
            GeneralTab(store: store).tabItem { Label("General", systemImage: "gearshape") }
            SpeedLimitsTab(store: store).tabItem { Label("Speed Limits", systemImage: "speedometer") }
            ServersTab(store: store).tabItem { Label("Servers", systemImage: "server.rack") }
        }
        .frame(width: 670, height: 490)
    }
}

struct GeneralTab: View {
    var store: TorrentStore
    @State private var defaultAppError: String?
    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: Bindable(store.appSettings).launchAtLogin)
                Toggle("Keep Swarm running after closing the window", isOn: Bindable(store.appSettings).keepRunningInBackground)
            }
            Section {
                Toggle("Notify when a torrent finishes downloading", isOn: Bindable(store.appSettings).notifyOnComplete)
            }
            Section("Default App") {
                Button("Make Swarm the default app for magnet links") {
                    NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: "magnet") { error in
                        if let error { defaultAppError = error.localizedDescription }
                    }
                }
                Button("Make Swarm the default app for .torrent files") {
                    guard let type = UTType(filenameExtension: "torrent") else { return }
                    NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpen: type) { error in
                        if let error { defaultAppError = error.localizedDescription }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
        .alert("Swarm", isPresented: Binding(get: { store.appSettings.launchAtLoginError != nil }, set: { if !$0 { store.appSettings.launchAtLoginError = nil } })) {
            Button("OK") {}
        } message: { Text(store.appSettings.launchAtLoginError ?? "") }
        .alert("Swarm", isPresented: Binding(get: { defaultAppError != nil }, set: { if !$0 { defaultAppError = nil } })) {
            Button("OK") {}
        } message: { Text(defaultAppError ?? "") }
    }
}

struct SpeedLimitsTab: View {
    var store: TorrentStore
    @State private var downEnabled = false
    @State private var down = 0
    @State private var upEnabled = false
    @State private var up = 0
    @State private var altEnabled = false
    @State private var altDown = 0
    @State private var altUp = 0

    var body: some View {
        Form {
            if store.session == nil {
                Text("Connect to a server to manage speed limits.").foregroundStyle(.secondary)
            } else {
                Section("Normal Limits") {
                    Toggle("Limit download speed", isOn: $downEnabled)
                    LabeledContent("KB/s") { TextField("", value: $down, format: .number).textFieldStyle(.roundedBorder).frame(width: 90) }.disabled(!downEnabled)
                    Toggle("Limit upload speed", isOn: $upEnabled)
                    LabeledContent("KB/s") { TextField("", value: $up, format: .number).textFieldStyle(.roundedBorder).frame(width: 90) }.disabled(!upEnabled)
                }
                Section("Slow Mode") {
                    Toggle("Use alternate limits", isOn: $altEnabled)
                    LabeledContent("Download KB/s") { TextField("", value: $altDown, format: .number).textFieldStyle(.roundedBorder).frame(width: 90) }
                    LabeledContent("Upload KB/s") { TextField("", value: $altUp, format: .number).textFieldStyle(.roundedBorder).frame(width: 90) }
                }
                Section {
                    HStack { Spacer(); Button("Apply") { Task { await save() } }.buttonStyle(.borderedProminent) }
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
        .onAppear { load() }
        .onChange(of: store.session?.speedLimitDown) { _, _ in load() }
    }

    private func load() {
        guard let session = store.session else { return }
        downEnabled = session.speedLimitDownEnabled; down = session.speedLimitDown
        upEnabled = session.speedLimitUpEnabled; up = session.speedLimitUp
        altEnabled = session.altSpeedEnabled; altDown = session.altSpeedDown; altUp = session.altSpeedUp
    }
    private func save() async {
        await store.updateSpeedLimits(downEnabled: downEnabled, down: down, upEnabled: upEnabled, up: up)
        await store.updateAltSpeed(enabled: altEnabled, down: altDown, up: altUp)
    }
}
