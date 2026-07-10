import SwiftUI
import UniformTypeIdentifiers

extension View {
    /// Liquid Glass (macOS 26+) on a shape, falling back to a plain fill on earlier systems.
    @ViewBuilder
    func adaptiveGlass<S: Shape, F: ShapeStyle>(in shape: S, fallback: F) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(fallback, in: shape)
        }
    }
}

struct ContentView: View {
    var store: TorrentStore
    @State private var pendingDelete: [Torrent] = []
    @State private var showSlowModePopover = false
    @State private var renamingTorrent: Torrent?
    @State private var locationTargets: [Torrent] = []

    /// Right-clicking a row outside the current selection acts on that row alone, as in Finder.
    private func actionTargets(for torrent: Torrent) -> [Torrent] {
        store.selectedIDs.contains(torrent.id) ? store.selectedTorrents : [torrent]
    }

    /// Drives the crossfade between connecting/offline/empty/list states.
    private enum ContentState: Equatable { case connecting, offline, noResults, empty, list }
    private var contentState: ContentState {
        if store.isConnecting { .connecting }
        else if !store.isConnected { .offline }
        else if store.visibleTorrents.isEmpty && !store.search.isEmpty { .noResults }
        else if store.visibleTorrents.isEmpty { .empty }
        else { .list }
    }

    var body: some View {
        NavigationSplitView {
            Sidebar(store: store)
        } detail: {
            VStack(spacing: 0) {
                if store.isConnecting { ProgressView("Connecting to Transmission…").frame(maxWidth: .infinity, maxHeight: .infinity).transition(.opacity) }
                else if !store.isConnected { OfflineView(store: store).transition(.opacity) }
                else if store.visibleTorrents.isEmpty && !store.search.isEmpty { NoSearchResultsView(query: store.search).transition(.opacity) }
                else if store.visibleTorrents.isEmpty { EmptyTorrentsView { store.showAddSheet = true }.transition(.opacity) }
                else {
                    List(selection: Bindable(store).selectedIDs) {
                        ForEach(store.visibleTorrents) { torrent in
                            TorrentRow(torrent: torrent, style: store.appSettings.rowStyle).tag(torrent.id)
                                .contextMenu {
                                    let targets = actionTargets(for: torrent)
                                    let allPaused = targets.allSatisfy { $0.status == .paused }
                                    Button(allPaused ? "Resume" : "Pause", systemImage: allPaused ? "play.fill" : "pause.fill") { Task { await store.toggle(targets) } }
                                    Button("Ask Tracker for More Peers", systemImage: "arrow.triangle.2.circlepath") { Task { await store.reannounce(targets) } }
                                    Button("Verify Local Data", systemImage: "checkmark.shield") { Task { await store.verify(targets) } }
                                    if targets.count == 1 {
                                        Button("Copy Magnet Link", systemImage: "link") { Task { await store.copyMagnetLink(for: torrent) } }
                                    }
                                    Divider()
                                    Menu("Queue") {
                                        Button("Move to Top", systemImage: "arrow.up.to.line") { Task { await store.moveInQueue(targets, .top) } }
                                        Button("Move Up", systemImage: "chevron.up") { Task { await store.moveInQueue(targets, .up) } }
                                        Button("Move Down", systemImage: "chevron.down") { Task { await store.moveInQueue(targets, .down) } }
                                        Button("Move to Bottom", systemImage: "arrow.down.to.line") { Task { await store.moveInQueue(targets, .bottom) } }
                                    }
                                    Divider()
                                    if targets.count == 1 {
                                        Button("Rename…", systemImage: "pencil") { renamingTorrent = torrent }
                                    }
                                    Button("Set Location…", systemImage: "folder") { locationTargets = targets }
                                    Divider()
                                    Button("Get Info", systemImage: "info.circle") { if store.inspectorTorrentID == torrent.id { store.closeInspector() } else { store.openInspector(for: torrent.id) } }
                                    Divider()
                                    Button(targets.count > 1 ? "Remove \(targets.count) Torrents…" : "Remove Torrent…", systemImage: "trash", role: .destructive) { pendingDelete = targets }
                                }
                        }
                    }
                    .listStyle(.inset)
                    .onDeleteCommand { if !store.selectedIDs.isEmpty { pendingDelete = store.selectedTorrents } }
                    .onChange(of: store.selectedIDs) { _, newValue in
                        guard store.inspectorTorrentID != nil, let onlyID = newValue.count == 1 ? newValue.first : nil else { return }
                        store.openInspector(for: onlyID)
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: contentState)
            .navigationTitle(store.filter.title)
            .searchable(text: Bindable(store).search, placement: .toolbar, prompt: "Search torrents")
            .sheet(isPresented: Bindable(store).showAddSheet) {
                AddTorrentView(onAddMagnet: { magnet in Task { await store.add(magnet) } }, onAddFile: { data in Task { await store.addTorrentFile(data: data) } })
            }
            .sheet(item: $renamingTorrent) { torrent in
                RenameTorrentSheet(torrent: torrent) { newName in Task { await store.rename(torrent, to: newName) } }
            }
            .sheet(isPresented: Binding(get: { !locationTargets.isEmpty }, set: { if !$0 { locationTargets = [] } })) {
                SetLocationSheet(torrents: locationTargets) { location, move in Task { await store.setLocation(locationTargets, location: location, move: move) } }
            }
            .dropDestination(for: URL.self) { urls, _ in
                let torrentFiles = urls.filter { $0.pathExtension.lowercased() == "torrent" }
                guard !torrentFiles.isEmpty else { return false }
                for url in torrentFiles { if let data = try? Data(contentsOf: url) { Task { await store.addTorrentFile(data: data) } } }
                return true
            }
            .toolbar {
                if store.selectedIDs.count > 1 {
                    ToolbarItem(placement: .navigation) {
                        Text("\(store.selectedIDs.count) selected").foregroundStyle(.secondary)
                    }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    if !store.isConnected && !store.isConnecting {
                        SettingsLink { Label("Connect", systemImage: "bolt.horizontal.circle") }
                    }
                    if let session = store.session {
                        SlowModeButton(session: session, store: store, showPopover: $showSlowModePopover)
                    }
                    Button { Task { await store.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                    if !store.selectedIDs.isEmpty {
                        Button { Task { await store.toggle(store.selectedTorrents) } } label: { Image(systemName: store.selectionIsPaused ? "play.fill" : "pause.fill") }
                        Button(role: .destructive) { pendingDelete = store.selectedTorrents } label: { Image(systemName: "trash") }
                    }
                    if store.selectedIDs.count == 1, let id = store.selectedIDs.first {
                        Button {
                            if store.inspectorTorrentID == id { store.closeInspector() } else { store.openInspector(for: id) }
                        } label: { Image(systemName: "info.circle") }
                    }
                    Button { store.showAddSheet = true } label: { Image(systemName: "plus") }.help("Add Torrent").disabled(!store.isConnected)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .inspector(isPresented: Binding(get: { store.inspectorTorrentID != nil }, set: { if !$0 { store.closeInspector() } })) {
            TorrentInspectorView(store: store)
        }
        .alert("Drift", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) { Button("OK") {} } message: { Text(store.errorMessage ?? "") }
        .confirmationDialog(pendingDelete.count > 1 ? "Remove \(pendingDelete.count) torrents?" : "Remove torrent?", isPresented: Binding(get: { !pendingDelete.isEmpty }, set: { if !$0 { pendingDelete = [] } })) {
            let targets = pendingDelete
            Button("Remove", role: .destructive) { Task { await store.delete(targets, deleteData: false) }; pendingDelete = [] }
            Button("Remove and Delete Files", role: .destructive) { Task { await store.delete(targets, deleteData: true) }; pendingDelete = [] }
            Button("Cancel", role: .cancel) { pendingDelete = [] }
        } message: {
            Text(pendingDelete.count == 1 ? "\(pendingDelete[0].name) will be removed from Transmission." : "\(pendingDelete.count) torrents will be removed from Transmission.")
        }
    }
}

struct SlowModeButton: View {
    let session: SessionSettings
    var store: TorrentStore
    @Binding var showPopover: Bool
    var body: some View {
        Button { Task { await store.toggleSlowMode() } } label: {
            Image(systemName: "tortoise")
                .foregroundStyle(session.altSpeedEnabled ? Color.orange : Color.primary)
                .padding(.leading, 2)
        }
        .help("Slow Mode (alternate speed limits) — right-click to configure")
        .contextMenu { Button("Configure Speed Limits…", systemImage: "slider.horizontal.3") { showPopover = true } }
        .popover(isPresented: $showPopover) { SlowModePopover(store: store) }
    }
}

struct SlowModePopover: View {
    var store: TorrentStore
    @State private var enabled = false
    @State private var down = 0
    @State private var up = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Slow Mode").font(.headline)
            Toggle("Limit speed", isOn: $enabled)
            LabeledContent("Download KB/s") { TextField("", value: $down, format: .number).textFieldStyle(.roundedBorder).frame(width: 80) }
            LabeledContent("Upload KB/s") { TextField("", value: $up, format: .number).textFieldStyle(.roundedBorder).frame(width: 80) }
            HStack { Spacer(); Button("Apply") { Task { await store.updateAltSpeed(enabled: enabled, down: down, up: up) } }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction) }
        }
        .padding(18).frame(width: 260)
        .onAppear {
            guard let session = store.session else { return }
            enabled = session.altSpeedEnabled; down = session.altSpeedDown; up = session.altSpeedUp
        }
    }
}

struct Sidebar: View {
    var store: TorrentStore
    static let freeSpaceFormatter: ByteCountFormatter = { let f = ByteCountFormatter(); f.countStyle = .file; return f }()
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) { DriftSidebarMark().frame(width: 52, height: 52); Text(verbatim: "Drift").font(.system(size: 24, weight: .bold)); Spacer() }.padding(20)
            Text("TRANSMISSION").font(.caption2.monospaced().bold()).foregroundStyle(.secondary).padding(.horizontal, 20).padding(.top, 8)
            ForEach(TorrentFilter.allCases) { filter in
                Button { store.filter = filter } label: {
                    HStack(spacing: 10) {
                        Image(systemName: filter.systemImage).frame(width: 16, alignment: .center).foregroundStyle(filter.tint)
                        Text(filter.title)
                        Spacer()
                        let count = store.count(for: filter)
                        if count > 0 {
                            Text("\(count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6).padding(.vertical, 1)
                                .adaptiveGlass(in: Capsule(), fallback: .quaternary.opacity(0.5))
                        }
                    }
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(store.filter == filter ? .primary : .secondary)
                .padding(.horizontal, 20)
            }
            Spacer()
            if store.isConnected && store.speedHistory.count > 1 {
                SidebarActivityView(store: store)
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Circle().fill(store.isConnected ? .green : .orange).frame(width: 6)
                    Menu {
                        ForEach(store.servers) { server in
                            Button { store.selectServer(server.id) } label: {
                                if server.id == store.selectedServerID { Label(server.name, systemImage: "checkmark") } else { Text(server.name) }
                            }
                        }
                    } label: {
                        Text(store.selectedServer?.name ?? String(localized: "Add a server"))
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    SettingsLink { Image(systemName: "gearshape") }.buttonStyle(.plain).foregroundStyle(.secondary).help("Manage servers")
                }
                if let host = store.selectedServer?.host {
                    Text(host)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if store.isConnected, let freeSpace = store.freeSpace {
                        Text("\(Self.freeSpaceFormatter.string(fromByteCount: freeSpace)) \(String(localized: "free"))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
        }.frame(minWidth: 220)
    }
}

/// Live network activity for the whole session: a 2-minute sparkline of total
/// download/upload rates, sampled on every poll tick.
struct SidebarActivityView: View {
    var store: TorrentStore
    static let rateFormatter: ByteCountFormatter = { let f = ByteCountFormatter(); f.countStyle = .binary; return f }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ACTIVITY").font(.caption2.monospaced().bold()).foregroundStyle(.secondary)
            SpeedSparkline(samples: store.speedHistory)
                .frame(height: 36)
            HStack(spacing: 12) {
                Label(rateText(store.totalDownRate), systemImage: "arrow.down")
                    .foregroundStyle(store.totalDownRate > 0 ? Color.blue : Color.secondary)
                Label(rateText(store.totalUpRate), systemImage: "arrow.up")
                    .foregroundStyle(store.totalUpRate > 0 ? Color.green : Color.secondary)
            }
            .font(.caption.monospacedDigit())
            .labelStyle(.titleAndIcon)
        }
        .padding(.horizontal, 20).padding(.bottom, 14)
    }

    private func rateText(_ rate: Int) -> String {
        rate > 0 ? Self.rateFormatter.string(fromByteCount: Int64(rate)) + "/s" : "—"
    }
}

struct SpeedSparkline: View {
    let samples: [SpeedSample]

    var body: some View {
        GeometryReader { geo in
            let peak = max(samples.map { max($0.down, $0.up) }.max() ?? 1, 1)
            ZStack {
                area(of: \.down, peak: peak, in: geo.size).fill(Color.blue.opacity(0.15))
                line(of: \.down, peak: peak, in: geo.size).stroke(Color.blue, lineWidth: 1.5)
                line(of: \.up, peak: peak, in: geo.size).stroke(Color.green, lineWidth: 1.5)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: samples)
    }

    private func points(of key: KeyPath<SpeedSample, Int>, peak: Int, in size: CGSize) -> [CGPoint] {
        let count = max(samples.count - 1, 1)
        return samples.enumerated().map { index, sample in
            CGPoint(x: size.width * CGFloat(index) / CGFloat(count),
                    y: size.height - size.height * CGFloat(sample[keyPath: key]) / CGFloat(peak))
        }
    }

    private func line(of key: KeyPath<SpeedSample, Int>, peak: Int, in size: CGSize) -> Path {
        Path { path in
            let pts = points(of: key, peak: peak, in: size)
            guard let first = pts.first else { return }
            path.move(to: first)
            for pt in pts.dropFirst() { path.addLine(to: pt) }
        }
    }

    private func area(of key: KeyPath<SpeedSample, Int>, peak: Int, in size: CGSize) -> Path {
        Path { path in
            let pts = points(of: key, peak: peak, in: size)
            guard let first = pts.first, let last = pts.last else { return }
            path.move(to: CGPoint(x: first.x, y: size.height))
            for pt in pts { path.addLine(to: pt) }
            path.addLine(to: CGPoint(x: last.x, y: size.height))
            path.closeSubpath()
        }
    }
}

/// Replaces `ProgressView(value:).tint()`, whose color is unreliable in light mode on macOS
/// (AppKit's linear NSProgressIndicator backing ignores the tint under some appearances).
struct TintedProgressBar: View {
    let value: Double
    let tint: Color
    var height: CGFloat = 6
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.2))
                Capsule().fill(tint).frame(width: proxy.size.width * max(0, min(1, value)))
            }
        }
        .frame(height: height)
    }
}

struct OfflineView: View { var store: TorrentStore; var body: some View { VStack(spacing: 16) { Image(systemName: "bolt.horizontal.circle").font(.system(size: 52)).foregroundStyle(.secondary); Text("Connect to Transmission").font(.title2.bold()); Text("Drift needs a Transmission RPC connection to show your downloads.").foregroundStyle(.secondary); HStack { SettingsLink { Label("Connection settings", systemImage: "gearshape") }.buttonStyle(.borderedProminent); Button { Task { await store.refresh() } } label: { Label("Try again", systemImage: "arrow.clockwise") }.buttonStyle(.bordered) } }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(40) } }
struct EmptyTorrentsView: View { let add: () -> Void; var body: some View { let content = ContentUnavailableView { Label("No torrents yet", systemImage: "tray") } description: { Text("Your Transmission downloads will appear here.") } actions: { Button("Add Magnet Link", action: add).buttonStyle(.borderedProminent) }; return content.frame(maxWidth: .infinity, maxHeight: .infinity) } }
struct NoSearchResultsView: View { let query: String; var body: some View { ContentUnavailableView.search(text: query).frame(maxWidth: .infinity, maxHeight: .infinity) } }
struct TorrentRow: View {
    let torrent: Torrent
    var style: TorrentRowStyle = .detailed
    var body: some View {
        switch style {
        case .detailed: TorrentRowDetailed(torrent: torrent)
        case .card: TorrentRowCard(torrent: torrent)
        }
    }
}

/// Mirrors the two-line info format of the native Transmission app: size/progress/ETA above the
/// bar, peer counts and live speeds below it.
struct TorrentRowDetailed: View {
    let torrent: Torrent
    @State private var animatedProgress: Double = 0
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill((torrent.status == .paused ? Color.secondary : (torrent.status == .seeding ? Color.green : Color.blue)).opacity(0.15))
                Image(systemName: torrent.status == .seeding ? "arrow.up" : torrent.status == .paused ? "pause.fill" : "arrow.down")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(torrent.status == .paused ? Color.secondary : (torrent.status == .seeding ? Color.green : Color.blue))
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(torrent.name).font(.system(size: 14, weight: .medium)).lineLimit(1)
                Text(progressLine).font(.caption).foregroundStyle(.secondary)
                TintedProgressBar(value: animatedProgress, tint: torrent.status == .seeding ? Color.green : Color.blue)
                if let peersLine {
                    Text(peersLine).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            if animatedProgress >= 1 {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 16)).foregroundStyle(.secondary)
            } else {
                Text(Torrent.percentText(animatedProgress))
                    .font(.system(size: 13, weight: .medium, design: .rounded)).monospacedDigit()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .adaptiveGlass(in: Capsule(), fallback: .quaternary.opacity(0.4))
            }
        }
        .padding(.vertical, 4)
        .onAppear { animatedProgress = torrent.progress }
        .onChange(of: torrent.progress) { _, newValue in withAnimation(.easeInOut(duration: 0.6)) { animatedProgress = newValue } }
    }
    private var progressLine: String {
        switch torrent.status {
        case .downloading:
            let remaining = String(localized: "Remaining")
            let of = String(localized: "of")
            return "\(torrent.downloaded) \(of) \(torrent.size) — \(remaining) \(torrent.eta)"
        case .seeding:
            let uploadedLabel = String(localized: "uploaded"); let ratioLabel = String(localized: "ratio")
            return "\(torrent.size), \(uploadedLabel) \(torrent.uploaded) (\(ratioLabel) \(torrent.ratioText))"
        case .paused:
            return torrent.size
        }
    }
    /// nil when the line would carry no information (idle seeding, paused) — keeps quiet rows compact.
    private var peersLine: String? {
        switch torrent.status {
        case .downloading:
            let from = String(localized: "Downloading from"); let of = String(localized: "of"); let peers = String(localized: "peers")
            var line = "\(from) \(torrent.peersSendingToUs) \(of) \(torrent.peersConnected) \(peers)"
            let downloadLabel = String(localized: "D:"); let uploadLabel = String(localized: "U:")
            if torrent.speed != "—" { line += " — \(downloadLabel) \(torrent.speed)" }
            if torrent.uploadSpeed != "—" { line += ", \(uploadLabel) \(torrent.uploadSpeed)" }
            return line
        case .seeding:
            guard torrent.peersGettingFromUs > 0 || torrent.uploadSpeed != "—" else { return nil }
            let to = String(localized: "Seeding to"); let of = String(localized: "of"); let peers = String(localized: "peers")
            var line = "\(to) \(torrent.peersGettingFromUs) \(of) \(torrent.peersConnected) \(peers)"
            let uploadLabel = String(localized: "U:")
            if torrent.uploadSpeed != "—" { line += " — \(uploadLabel) \(torrent.uploadSpeed)" }
            return line
        case .paused:
            return nil
        }
    }
}

/// A card-style row with more breathing room, for users who prefer a lighter, less data-dense list.
struct TorrentRowCard: View {
    let torrent: Torrent
    @State private var animatedProgress: Double = 0
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                Circle().trim(from: 0, to: animatedProgress).stroke(torrent.status == .seeding ? Color.green : Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90))
                Image(systemName: torrent.status == .seeding ? "arrow.up" : torrent.status == .paused ? "pause.fill" : "arrow.down").font(.caption.bold()).foregroundStyle(torrent.status == .paused ? Color.secondary : Color.primary)
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text(torrent.name).font(.body.weight(.semibold))
                HStack { Text(torrent.status.title); Text(verbatim: "·"); Text(torrent.size); Text(verbatim: "·"); Text(torrent.speed) }.font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(Torrent.percentText(animatedProgress)).font(.title3.monospacedDigit().weight(.medium)).foregroundStyle(.secondary)
        }
        .padding(14)
        .adaptiveGlass(in: RoundedRectangle(cornerRadius: 14), fallback: .quaternary.opacity(0.25))
        .padding(.vertical, 4)
        .onAppear { animatedProgress = torrent.progress }
        .onChange(of: torrent.progress) { _, newValue in withAnimation(.easeInOut(duration: 0.6)) { animatedProgress = newValue } }
    }
}

/// Mirrors the native Transmission.app list row: a file icon, a thin progress bar, and a terse status line.
struct TorrentRowNative: View {
    let torrent: Torrent
    @State private var animatedProgress: Double = 0
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "folder.fill").font(.title2).foregroundStyle(.blue.opacity(torrent.status == .paused ? 0.5 : 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(torrent.name).font(.system(size: 13, weight: .regular)).lineLimit(1)
                Text(statusLine).font(.system(size: 11)).foregroundStyle(.secondary)
                TintedProgressBar(value: animatedProgress, tint: torrent.status == .seeding ? Color.green : Color.blue, height: 4)
                Text(activityLine).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .onAppear { animatedProgress = torrent.progress }
        .onChange(of: torrent.progress) { _, newValue in withAnimation(.easeInOut(duration: 0.6)) { animatedProgress = newValue } }
    }
    private var statusLine: String {
        guard torrent.status == .seeding else { return torrent.size }
        let uploaded = String(localized: "Uploaded"); let ratio = String(localized: "Ratio")
        return "\(torrent.size) · \(uploaded) \(torrent.uploaded) · \(ratio) \(torrent.ratioText)"
    }
    private var activityLine: String {
        switch torrent.status {
        case .seeding: "\(String(localized: "Seeding")) — ↑ \(torrent.speed)"
        case .downloading: "\(String(localized: "Downloading")) — ↓ \(torrent.speed)"
        case .paused: String(localized: "Paused")
        }
    }
}

struct AddTorrentView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var link = ""
    @State private var isTargeted = false
    @State private var showFileImporter = false
    let onAddMagnet: (String) -> Void
    let onAddFile: (Data) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Add Torrent").font(.title2.bold())
            TextField("Magnet link or torrent URL", text: $link).textFieldStyle(.roundedBorder)
            VStack(spacing: 8) {
                Image(systemName: "arrow.down.doc").font(.title).foregroundStyle(.secondary)
                Text("Drop a .torrent file here").font(.callout).foregroundStyle(.secondary)
                Button("Choose File…") { showFileImporter = true }.buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 20)
            .background(isTargeted ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(isTargeted ? Color.accentColor : Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5])))
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first(where: { $0.pathExtension.lowercased() == "torrent" }), let data = try? Data(contentsOf: url) else { return false }
                onAddFile(data); dismiss(); return true
            } isTargeted: { isTargeted = $0 }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.bordered).keyboardShortcut(.cancelAction)
                Button("Add") { onAddMagnet(link); dismiss() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24).frame(width: 480)
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [UTType(filenameExtension: "torrent") ?? .data]) { result in
            if case .success(let url) = result, let data = try? Data(contentsOf: url) { onAddFile(data); dismiss() }
        }
    }
}

struct RenameTorrentSheet: View {
    @Environment(\.dismiss) private var dismiss
    let torrent: Torrent
    @State private var name: String
    let onRename: (String) -> Void

    init(torrent: Torrent, onRename: @escaping (String) -> Void) {
        self.torrent = torrent
        self._name = State(initialValue: torrent.name)
        self.onRename = onRename
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Rename Torrent").font(.title2.bold())
            TextField("Name", text: $name).textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.bordered).keyboardShortcut(.cancelAction)
                Button("Rename") { onRename(name); dismiss() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24).frame(width: 420)
    }
}

struct SetLocationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let torrents: [Torrent]
    @State private var location = ""
    @State private var moveData = true
    let onSet: (String, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Set Location").font(.title2.bold())
            Text(torrents.count > 1 ? "New download folder for \(torrents.count) torrents, on the Transmission server." : "New download folder for \"\(torrents.first?.name ?? "")\", on the Transmission server.")
                .font(.caption).foregroundStyle(.secondary)
            TextField("/path/on/server", text: $location).textFieldStyle(.roundedBorder)
            Toggle("Move data from the current location", isOn: $moveData)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.bordered).keyboardShortcut(.cancelAction)
                Button("Set Location") { onSet(location, moveData); dismiss() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24).frame(width: 460)
    }
}

struct ServersTab: View {
    var store: TorrentStore
    /// Which server's settings are shown in the editor pane — independent of `store.selectedServerID`
    /// (the actually-connected server). Browsing the list to inspect/edit a different server must
    /// not silently switch the active connection; only "Save" in `ServerEditor` does that.
    @State private var editingServerID: UUID?
    @State private var pendingDeleteServer: ServerProfile?
    private var editingServer: ServerProfile? { store.servers.first { $0.id == editingServerID } ?? store.selectedServer }
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("SERVERS").font(.caption2.monospaced().bold()).foregroundStyle(.secondary)
                ForEach(store.servers) { server in
                    let isEditing = server.id == (editingServerID ?? store.selectedServerID)
                    Button { editingServerID = server.id } label: {
                        HStack(spacing: 10) { Image(systemName: "server.rack").foregroundStyle(server.id == store.selectedServerID ? .blue : .secondary); VStack(alignment: .leading, spacing: 2) { Text(server.name).lineLimit(1); Text(server.host).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle) }; Spacer(); if server.id == store.selectedServerID { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.blue) } }
                        .padding(9)
                        .contentShape(Rectangle())
                    }.buttonStyle(.plain).background(isEditing ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
                        .contextMenu {
                            Button("Remove Server…", systemImage: "trash", role: .destructive) { pendingDeleteServer = server }
                                .disabled(store.servers.count <= 1)
                        }
                }
                Spacer()
                Button { editingServerID = store.addServer() } label: { Label("Add Server", systemImage: "plus") }.buttonStyle(.bordered)
            }.padding(18).frame(width: 240).background(.quaternary.opacity(0.35))
            Divider()
            VStack(alignment: .leading, spacing: 18) {
                if let editingServer { ServerEditor(server: editingServer, store: store).id(editingServer.id) }
                Spacer()
                ConnectionGuide()
            }.padding(28).frame(width: 430)
        }.frame(width: 670, height: 490)
        .confirmationDialog("Remove “\(pendingDeleteServer?.name ?? "")”?", isPresented: Binding(get: { pendingDeleteServer != nil }, set: { if !$0 { pendingDeleteServer = nil } })) {
            Button("Remove", role: .destructive) {
                guard let id = pendingDeleteServer?.id else { return }
                if editingServerID == id { editingServerID = nil }
                store.deleteServer(id)
                pendingDeleteServer = nil
            }
            Button("Cancel", role: .cancel) { pendingDeleteServer = nil }
        } message: {
            Text("This removes its saved connection details and password.")
        }
    }
}

struct ServerEditor: View {
    var server: ServerProfile
    var store: TorrentStore
    @State private var name = ""
    @State private var host = ""
    @State private var port = ""
    @State private var username = ""
    @State private var password = ""

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedHost: String { host.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isValid: Bool { !trimmedName.isEmpty && !trimmedHost.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Connection").font(.title2.bold())
                Text("Connect Drift to a Transmission RPC server.").foregroundStyle(.secondary)
            }
            LabeledField(title: "Name", text: $name, placeholder: "Home server")
            HStack(spacing: 10) {
                LabeledField(title: "Host", text: $host, placeholder: "192.168.100.15")
                LabeledField(title: "Port", text: $port, placeholder: "9091").frame(width: 90)
            }
            LabeledField(title: "Username", text: $username, placeholder: "Optional")
            VStack(alignment: .leading, spacing: 6) {
                Text("Password").font(.caption).foregroundStyle(.secondary)
                SecureField("Optional", text: $password).textFieldStyle(.roundedBorder)
            }
            HStack {
                Spacer()
                Button("Save") {
                    store.updateServer(ServerProfile(id: server.id, name: trimmedName, host: trimmedHost, port: port, username: username, password: password))
                    store.selectServer(server.id)
                    Task { await store.refresh() }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .onAppear { name = server.name; host = server.host; port = server.port; username = server.username; password = server.password }
    }
}
struct LabeledField: View { let title: LocalizedStringKey; @Binding var text: String; let placeholder: LocalizedStringKey; var body: some View { VStack(alignment: .leading, spacing: 6) { Text(title).font(.caption).foregroundStyle(.secondary); TextField(placeholder, text: $text).textFieldStyle(.roundedBorder) } } }
struct ConnectionGuide: View { var body: some View { VStack(alignment: .leading, spacing: 8) { Text("Quick setup").font(.headline); Text("In Transmission, open Settings → Remote and enable remote access. Use the server IP and RPC port above.").font(.caption).foregroundStyle(.secondary); Link("Read the RPC guide ↗", destination: URL(string: "https://github.com/transmission/transmission/blob/main/docs/rpc-spec.md")!).font(.caption) }.padding(14).adaptiveGlass(in: RoundedRectangle(cornerRadius: 12), fallback: .quaternary.opacity(0.5)) } }

