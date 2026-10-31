import Foundation

/// How many of the picked items an album holds, which decides what a tap on its row does.
nonisolated enum AlbumMembership: Sendable, Equatable {
    case all
    case some
    case none

    init(of ids: [AssetID], in members: Set<AssetID>) {
        let inAlbum = ids.count { members.contains($0) }
        self = if inAlbum == 0 {
            .none
        } else if inAlbum == ids.count {
            .all
        } else {
            .some
        }
    }
}
