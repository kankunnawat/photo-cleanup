import AVFoundation
import UIKit

nonisolated enum AccessLevel: Sendable, Equatable {
    case notDetermined
    case denied
    case limited
    case full
}

nonisolated enum PhotoLibraryError: LocalizedError, Equatable {
    /// The user tapped Cancel (or Don't Allow) on the system delete confirmation.
    case userCancelled
    case keepAlbumUnavailable
    case albumUnavailable
    /// The asset, or the file behind it, is gone; for example deleted in Photos while the viewer was open.
    case assetUnavailable

    var errorDescription: String? {
        switch self {
        case .userCancelled: "You cancelled the delete."
        case .keepAlbumUnavailable: "The Keep album could not be found or created."
        case .albumUnavailable: "The album could not be found or changed."
        case .assetUnavailable: "This item is no longer in your library."
        }
    }
}

/// The only boundary to PhotoKit. The app uses `PhotoKitLibrary`; tests use an in-memory fake.
nonisolated protocol PhotoLibrary: Sendable {
    func accessLevel() -> AccessLevel
    func requestAccess() async -> AccessLevel
    /// Every visible asset (hidden assets excluded), newest first.
    func fetchAssets() async -> [AssetInfo]
    func protectionSources() async -> ProtectionSources
    func existingIDs(among ids: [AssetID]) async -> Set<AssetID>
    func fileSizes(for ids: [AssetID]) async -> [AssetID: Int64]
    func addToKeepAlbum(_ ids: [AssetID]) async throws
    /// Returns the new, empty album.
    func createAlbum(title: String) async throws -> AlbumInfo
    func add(_ id: AssetID, toAlbum albumID: String) async throws
    func remove(_ id: AssetID, fromAlbum albumID: String) async throws
    /// Writes the photo or video (the edited version if it has edits) to a new file from `ShareExports`.
    /// A Live Photo gives its still. Cancelling the task cancels an iCloud download.
    func exportOriginal(for id: AssetID) async throws -> URL
    /// One system confirmation for the whole batch.
    func delete(_ ids: [AssetID]) async throws
    func thumbnail(for id: AssetID, targetSize: CGSize) async -> UIImage?
    @MainActor func playerItem(for id: AssetID) async throws -> AVPlayerItem
    /// Calls `handler` (on any thread) whenever the library changes.
    func observeChanges(_ handler: @escaping @Sendable () -> Void)
}
