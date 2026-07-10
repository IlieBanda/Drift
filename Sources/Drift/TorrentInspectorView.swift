import SwiftUI

struct TorrentInspectorView: View {
    var store: TorrentStore
    var body: some View {
        Group {
            if let detail = store.inspectorDetail {
                TorrentInspectorContent(detail: detail, store: store)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .inspectorColumnWidth(min: 300, ideal: 340, max: 420)
    }
}

private enum InspectorTab: CaseIterable {
    case activity, trackers, peers, files, general
    var icon: String {
        switch self {
        case .activity: "waveform.path.ecg"
        case .trackers: "antenna.radiowaves.left.and.right"
        case .peers: "person.2"
        case .files: "doc.on.doc"
        case .general: "info.circle"
        }
    }
    var title: LocalizedStringKey {
        switch self {
        case .activity: "Activity"
        case .trackers: "Trackers"
        case .peers: "Peers"
        case .files: "Files"
        case .general: "General"
        }
    }
}

private struct TorrentInspectorContent: View {
    let detail: TorrentDetail
    var store: TorrentStore
    @State private var selectedTab: InspectorTab = .activity
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(detail.name).font(.headline).lineLimit(2)
                if !detail.errorString.isEmpty {
                    Label(detail.errorString, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange)
                }
            }
            .padding(16)
            HStack(spacing: 2) {
                ForEach(InspectorTab.allCases, id: \.self) { tab in
                    Button { selectedTab = tab } label: {
                        Image(systemName: tab.icon)
                            .font(.system(size: 13))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selectedTab == tab ? Color.primary : Color.secondary)
                    .background(selectedTab == tab ? Color.primary.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 6))
                    .help(tab.title)
                }
            }
            .padding(4)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
            Group {
                switch selectedTab {
                case .activity: InspectorActivityTab(detail: detail)
                case .trackers: InspectorTrackersTab(detail: detail)
                case .peers: InspectorPeersTab(detail: detail)
                case .files: InspectorFilesTab(detail: detail, store: store)
                case .general: InspectorGeneralTab(detail: detail)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct InspectorEmptyState: View {
    let icon: String
    let text: LocalizedStringKey
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title3).foregroundStyle(.secondary)
            Text(text).font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

private struct InfoRow: View {
    let label: LocalizedStringKey
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary).lineLimit(1).layoutPriority(1)
            Spacer(minLength: 12)
            Text(value).multilineTextAlignment(.trailing).textSelection(.enabled).lineLimit(2)
        }
        .font(.callout)
    }
}

private struct InspectorGeneralTab: View {
    let detail: TorrentDetail
    var body: some View {
        Form {
            InfoRow(label: "Hash", value: detail.hash)
            InfoRow(label: "Private Torrent", value: detail.isPrivate ? String(localized: "Yes") : String(localized: "No"))
            InfoRow(label: "Added", value: detail.addedDate.formatted(date: .abbreviated, time: .shortened))
            if let doneDate = detail.doneDate {
                InfoRow(label: "Completed", value: doneDate.formatted(date: .abbreviated, time: .shortened))
            }
            if !detail.comment.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Comment").font(.callout).foregroundStyle(.secondary)
                    Text(detail.comment).font(.callout).textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

private struct InspectorActivityTab: View {
    let detail: TorrentDetail
    var body: some View {
        Form {
            InfoRow(label: "Total Size", value: detail.totalSize)
            InfoRow(label: "Downloaded", value: detail.downloaded)
            InfoRow(label: "Uploaded", value: detail.uploaded)
            InfoRow(label: "Ratio", value: detail.ratioText)
            InfoRow(label: "Corrupt", value: detail.corrupt)
            InfoRow(label: "Download Speed", value: detail.downloadSpeed)
            InfoRow(label: "Upload Speed", value: detail.uploadSpeed)
            InfoRow(label: "Connected Peers", value: "\(detail.peersConnected)")
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

private struct InspectorTrackersTab: View {
    let detail: TorrentDetail
    var body: some View {
        Group {
            if detail.trackers.isEmpty {
                InspectorEmptyState(icon: "antenna.radiowaves.left.and.right.slash", text: "No Trackers")
            } else {
                List(detail.trackers) { tracker in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tracker.host).font(.callout.weight(.medium)).lineLimit(1)
                        HStack(spacing: 10) {
                            Label("\(tracker.seeders)", systemImage: "arrow.up.circle").font(.caption).foregroundStyle(.secondary)
                            Label("\(tracker.leechers)", systemImage: "arrow.down.circle").font(.caption).foregroundStyle(.secondary)
                            if !tracker.succeeded && !tracker.lastResult.isEmpty {
                                Text(tracker.lastResult).font(.caption).foregroundStyle(.orange).lineLimit(1)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.inset)
            }
        }
    }
}

private struct InspectorPeersTab: View {
    let detail: TorrentDetail
    var body: some View {
        Group {
            if detail.peers.isEmpty {
                InspectorEmptyState(icon: "person.slash", text: "No Peers Connected")
            } else {
                List(detail.peers) { peer in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(peer.address).font(.callout.monospacedDigit())
                            if peer.isEncrypted { Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.secondary) }
                        }
                        HStack(spacing: 10) {
                            Text(peer.client).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            Spacer()
                            Text(peer.downloadSpeed).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            Text(peer.uploadSpeed).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.inset)
            }
        }
    }
}

private struct InspectorFilesTab: View {
    let detail: TorrentDetail
    var store: TorrentStore
    var body: some View {
        List(detail.files) { file in
            HStack(spacing: 10) {
                Toggle("", isOn: Binding(get: { file.wanted }, set: { newValue in Task { await store.setFileWanted(fileIndex: file.index, wanted: newValue) } }))
                    .labelsHidden()
                VStack(alignment: .leading, spacing: 3) {
                    Text(file.name).font(.callout).lineLimit(1).foregroundStyle(file.wanted ? Color.primary : Color.secondary)
                    HStack { ProgressView(value: file.progress).frame(width: 100); Text(file.sizeText).font(.caption2).foregroundStyle(.secondary) }
                }
                Spacer()
                Picker("", selection: Binding(get: { file.priority }, set: { newValue in Task { await store.setFilePriority(fileIndex: file.index, priority: newValue) } })) {
                    ForEach(FilePriority.allCases, id: \.self) { priority in Text(priority.title).tag(priority) }
                }
                .labelsHidden()
                .frame(width: 90)
                .disabled(!file.wanted)
            }
            .padding(.vertical, 2)
        }
        .listStyle(.inset)
    }
}
