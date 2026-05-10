import SwiftUI

struct ChannelManagerView: View {
    @Binding var channels: [Channel]
    var activeChannelID: UUID
    var onSave: () -> Void

    @State private var localChannels: [Channel] = []
    @State private var newName = ""
    @State private var newKind: NewChannelKind = .search
    @State private var queryText = ""
    @State private var collectionID = ""
    @State private var collectionTitle = ""
    @State private var username = ""
    @State private var displayName = ""

    @Environment(\.dismiss) private var dismiss

    private enum NewChannelKind: CaseIterable { case search, collection, user }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List {
                Section("channel.your_channels".localized) {
                    if localChannels.isEmpty {
                        Text("channel.no_channels".localized).foregroundStyle(.secondary)
                    }
                    ForEach(localChannels) { channel in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(channel.name).fontWeight(.medium)
                                    if channel.id == activeChannelID {
                                        Text("channel.active".localized)
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    }
                                }
                                Text(channel.kind.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if channel.id != activeChannelID, localChannels.count > 1 {
                                Button {
                                    deleteChannel(channel)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 13))
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.secondary)
                                .help("channel.delete".localized)
                            }
                        }
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("channel.add_channel".localized).font(.headline)

                TextField("channel.channel_name".localized, text: $newName)
                    .textFieldStyle(.roundedBorder)

                Picker("channel.type".localized, selection: $newKind) {
                    Text("channel.search".localized).tag(NewChannelKind.search)
                    Text("channel.collection".localized).tag(NewChannelKind.collection)
                    Text("channel.user".localized).tag(NewChannelKind.user)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                switch newKind {
                case .search:
                    TextField("channel.search_query".localized, text: $queryText)
                        .textFieldStyle(.roundedBorder)
                case .collection:
                    TextField("channel.collection_id".localized, text: $collectionID)
                        .textFieldStyle(.roundedBorder)
                    TextField("channel.collection_title".localized, text: $collectionTitle)
                        .textFieldStyle(.roundedBorder)
                case .user:
                    TextField("channel.username".localized, text: $username)
                        .textFieldStyle(.roundedBorder)
                    TextField("channel.display_name".localized, text: $displayName)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Button("channel.add".localized) { addChannel() }
                        .disabled(!canAdd)
                    Spacer()
                    Button("channel.done".localized) {
                        channels = localChannels
                        onSave()
                        dismiss()
                    }
                }
            }
            .padding()
        }
        .frame(width: 400, height: 420)
        .onAppear { localChannels = channels }
        .onDisappear {
            channels = localChannels
            onSave()
        }
    }

    private var canAdd: Bool {
        guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        switch newKind {
        case .search:
            return !queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .collection:
            return !collectionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !collectionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .user:
            return !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func addChannel() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let kind: ChannelKind
        switch newKind {
        case .search:
            kind = .search(query: queryText.trimmingCharacters(in: .whitespacesAndNewlines))
        case .collection:
            kind = .collection(
                id: collectionID.trimmingCharacters(in: .whitespacesAndNewlines),
                title: collectionTitle.trimmingCharacters(in: .whitespacesAndNewlines))
        case .user:
            kind = .user(
                username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                name: displayName.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        localChannels.append(Channel(id: UUID(), name: name, kind: kind))
        channels = localChannels
        onSave()

        newName = ""
        queryText = ""
        collectionID = ""
        collectionTitle = ""
        username = ""
        displayName = ""
    }

    private func deleteChannel(_ channel: Channel) {
        guard channel.id != activeChannelID else { return }
        guard localChannels.count > 1 else { return }
        localChannels.removeAll { $0.id == channel.id }
        channels = localChannels
        onSave()
    }
}
