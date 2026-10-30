import Foundation

nonisolated struct AlbumInfo: Hashable, Sendable, Identifiable {
    let id: String
    let title: String
    let assetIDs: Set<AssetID>
}

/// Raw library facts the protected set is built from.
nonisolated struct ProtectionSources: Sendable {
    var keepAlbum: Set<AssetID> = []
    /// The app had a Keep album, but it can no longer be found (for example, it was deleted in Photos).
    var keepAlbumMissing = false
    var favorites: Set<AssetID> = []
    var hidden: Set<AssetID> = []
    /// User albums other than Keep.
    var albums: [AlbumInfo] = []
}

nonisolated struct ProtectedSet: Sendable {
    let ids: Set<AssetID>

    init(ids: Set<AssetID> = []) {
        self.ids = ids
    }

    /// Albums are protected unless the user switched them off, so new albums start protected.
    init(sources: ProtectionSources, disabledAlbumIDs: Set<String>) {
        var ids = sources.keepAlbum.union(sources.favorites).union(sources.hidden)
        for album in sources.albums where !disabledAlbumIDs.contains(album.id) {
            ids.formUnion(album.assetIDs)
        }
        self.ids = ids
    }

    func contains(_ id: AssetID) -> Bool {
        ids.contains(id)
    }
}
