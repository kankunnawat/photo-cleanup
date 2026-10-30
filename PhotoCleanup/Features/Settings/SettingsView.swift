import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            Section {
                alwaysOn("Keep album", count: model.sources.keepAlbum.count, symbol: "heart.fill", tint: .keepGreen)
                alwaysOn("Favorites", count: model.sources.favorites.count, symbol: "star.fill")
                alwaysOn("Hidden", count: model.sources.hidden.count, symbol: "eye.slash.fill")
            } header: {
                Text("Always protected")
            }

            Section {
                if model.sources.albums.isEmpty {
                    Text("No albums yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.sources.albums) { album in
                    Toggle(isOn: protectionBinding(for: album.id)) {
                        VStack(alignment: .leading) {
                            Text(album.title)
                            Text(Formatting.items(album.assetIDs.count))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Protected albums")
            } footer: {
                Text("Photos in a switched-on album are never offered for deletion. New albums start switched on.")
            }

            Section("About deleting") {
                Group {
                    Text(SafetyCopy.iCloud)
                    Text(SafetyCopy.recentlyDeleted)
                    Text(SafetyCopy.upTo)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }

    private func alwaysOn(_ title: String, count: Int, symbol: String, tint: Color = .accentColor) -> some View {
        Toggle(isOn: .constant(true)) {
            Label {
                VStack(alignment: .leading) {
                    Text(title)
                    Text(Formatting.items(count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
            }
        }
        .disabled(true)
    }

    private func protectionBinding(for albumID: String) -> Binding<Bool> {
        Binding(
            get: { !model.disabledAlbumIDs.contains(albumID) },
            set: { isOn in
                if isOn {
                    model.disabledAlbumIDs.remove(albumID)
                } else {
                    model.disabledAlbumIDs.insert(albumID)
                }
            }
        )
    }
}
