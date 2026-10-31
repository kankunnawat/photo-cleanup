import SwiftUI

/// Puts photos into albums or takes them out. Each tap writes to Photos at once, one change for all the photos.
struct AlbumPicker: View {
    private enum Write: Equatable {
        case album(String)
        case newAlbum
    }

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let assetIDs: [AssetID]

    @State private var query = ""
    @State private var writing: Write?
    @State private var failure: String?
    @State private var isNaming = false
    @State private var newTitle = ""

    var body: some View {
        let matches = matchingAlbums
        NavigationStack {
            List {
                if let failure {
                    Label(failure, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("albums.error")
                }
                Section {
                    newAlbumRow
                    searchField
                }
                if query.isEmpty, !model.recentAlbums.isEmpty {
                    Section("Recent") {
                        ForEach(model.recentAlbums) { row(for: $0) }
                    }
                }
                Section(query.isEmpty ? "All albums" : "Matching albums") {
                    if matches.isEmpty {
                        Text(query.isEmpty ? "No albums yet." : "No album matches.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(matches) { row(for: $0) }
                }
            }
            .accessibilityIdentifier("albums.sheet")
            .navigationTitle(assetIDs.count == 1 ? "Add to album" : "Add \(assetIDs.count.formatted()) to album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    // Closing mid-write would hide a failure, so the picker stays until the write returns.
                    Button("Done") { dismiss() }
                        .disabled(writing != nil)
                        .accessibilityIdentifier("albums.done")
                }
            }
            .alert("New album", isPresented: $isNaming) {
                TextField("Name", text: $newTitle)
                    .accessibilityIdentifier("albums.newName")
                Button("Cancel", role: .cancel) {}
                Button("Create", action: create)
                    .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text(assetIDs.count == 1 ? "The photo goes into the new album." : "The \(assetIDs.count.formatted()) items go into the new album.")
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(writing != nil)
    }

    private var matchingAlbums: [AlbumInfo] {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return model.sources.albums }
        return model.sources.albums.filter { $0.title.localizedStandardContains(text) }
    }

    private var newAlbumRow: some View {
        Button {
            newTitle = ""
            isNaming = true
        } label: {
            HStack {
                Label("New album", systemImage: "plus")
                Spacer()
                if writing == .newAlbum {
                    ProgressView()
                }
            }
        }
        .disabled(writing != nil)
        .accessibilityIdentifier("albums.new")
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search albums", text: $query)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityIdentifier("albums.search")
            if !query.isEmpty {
                Button("Clear search", systemImage: "xmark.circle.fill") { query = "" }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
            }
        }
    }

    private func row(for album: AlbumInfo) -> some View {
        let membership = AlbumMembership(of: assetIDs, in: album.assetIDs)
        let isProtected = !model.disabledAlbumIDs.contains(album.id)
        return Button {
            toggle(album.id, membership: membership)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(album.title)
                    HStack(spacing: 6) {
                        Text(Formatting.items(album.assetIDs.count))
                            .foregroundStyle(.secondary)
                        if !isProtected {
                            Text("Not protected")
                                .foregroundStyle(.orange)
                        }
                    }
                    .font(.caption)
                }
                Spacer()
                if writing == .album(album.id) {
                    ProgressView()
                } else if membership != .none {
                    Image(systemName: membership == .all ? "checkmark" : "minus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(.rect)
        }
        .tint(.primary)
        .accessibilityValue(Self.value(of: membership))
        .accessibilityIdentifier("albums.row")
    }

    private static func value(of membership: AlbumMembership) -> String {
        switch membership {
        case .all: "In album"
        case .some: "Some in album"
        case .none: "Not in album"
        }
    }

    /// Fills the album when some items are missing; empties it of them only when it already holds them all.
    private func toggle(_ albumID: String, membership: AlbumMembership) {
        perform(.album(albumID)) {
            if membership == .all {
                try await model.remove(assetIDs, fromAlbum: albumID)
            } else {
                try await model.add(assetIDs, toAlbum: albumID)
            }
        }
    }

    private func create() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        perform(.newAlbum) {
            try await model.createAlbum(titled: title, adding: assetIDs)
            query = ""
        }
    }

    /// One write at a time, so a quick second tap never races the first.
    private func perform(_ write: Write, _ body: @escaping () async throws -> Void) {
        guard writing == nil else { return }
        writing = write
        failure = nil
        Task {
            do {
                try await body()
            } catch {
                failure = error.localizedDescription
            }
            writing = nil
        }
    }
}
