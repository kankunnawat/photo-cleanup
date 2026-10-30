import AVFoundation
import UIKit
@testable import PhotoCleanup

actor FakePhotoLibrary: PhotoLibrary {
    enum Call: Equatable {
        case addToKeepAlbum([AssetID])
        case delete([AssetID])
        case createAlbum(String)
        case add(AssetID, toAlbum: String)
        case remove(AssetID, fromAlbum: String)
    }

    enum DeleteBehavior {
        case succeed
        case userCancels
        case fail
    }

    struct Failure: LocalizedError {
        var errorDescription: String? { "disk on fire" }
    }

    private(set) var assets: [AssetInfo]
    private(set) var keepAlbum: Set<AssetID> = []
    private(set) var calls: [Call] = []
    var favorites: Set<AssetID> = []
    var hidden: Set<AssetID> = []
    var albums: [AlbumInfo] = []
    var sizes: [AssetID: Int64] = [:]
    var deleteBehavior: DeleteBehavior = .succeed
    var keepAlbumFails = false
    var albumWritesFail = false
    /// The next `protectionSources` call waits until `releaseProtectionSources()`.
    var holdNextProtectionSources = false
    private(set) var protectionSourcesCalls = 0
    private var protectionSourcesGate: CheckedContinuation<Void, Never>?
    private var createdAlbums = 0

    init(assets: [AssetInfo]) {
        self.assets = assets
    }

    func configure(_ change: @Sendable (isolated FakePhotoLibrary) -> Void) {
        change(self)
    }

    nonisolated func accessLevel() -> AccessLevel { .full }
    func requestAccess() async -> AccessLevel { .full }
    func fetchAssets() async -> [AssetInfo] { assets }

    func protectionSources() async -> ProtectionSources {
        protectionSourcesCalls += 1
        // Read before waiting, so a held call returns what the library held when it began.
        let sources = ProtectionSources(keepAlbum: keepAlbum, favorites: favorites, hidden: hidden, albums: albums)
        if holdNextProtectionSources {
            holdNextProtectionSources = false
            await withCheckedContinuation { protectionSourcesGate = $0 }
        }
        return sources
    }

    /// Waits until a held `protectionSources` call is parked on the gate.
    func waitUntilProtectionSourcesHeld() async {
        while protectionSourcesGate == nil {
            await Task.yield()
        }
    }

    func releaseProtectionSources() {
        protectionSourcesGate?.resume()
        protectionSourcesGate = nil
    }

    func existingIDs(among ids: [AssetID]) async -> Set<AssetID> {
        Set(ids).intersection(assets.map(\.id))
    }

    func fileSizes(for ids: [AssetID]) async -> [AssetID: Int64] {
        sizes.filter { ids.contains($0.key) }
    }

    func addToKeepAlbum(_ ids: [AssetID]) async throws {
        calls.append(.addToKeepAlbum(ids))
        if keepAlbumFails { throw PhotoLibraryError.keepAlbumUnavailable }
        keepAlbum.formUnion(ids)
    }

    func createAlbum(title: String) async throws -> AlbumInfo {
        calls.append(.createAlbum(title))
        if albumWritesFail { throw PhotoLibraryError.albumUnavailable }
        createdAlbums += 1
        let album = AlbumInfo(id: "created-\(createdAlbums)", title: title, assetIDs: [])
        albums.append(album)
        return album
    }

    func add(_ id: AssetID, toAlbum albumID: String) async throws {
        calls.append(.add(id, toAlbum: albumID))
        try changeAlbum(albumID) { $0.insert(id) }
    }

    func remove(_ id: AssetID, fromAlbum albumID: String) async throws {
        calls.append(.remove(id, fromAlbum: albumID))
        try changeAlbum(albumID) { $0.remove(id) }
    }

    private func changeAlbum(_ albumID: String, _ change: (inout Set<AssetID>) -> Void) throws {
        guard !albumWritesFail, let index = albums.firstIndex(where: { $0.id == albumID }) else {
            throw PhotoLibraryError.albumUnavailable
        }
        var members = albums[index].assetIDs
        change(&members)
        albums[index] = AlbumInfo(id: albumID, title: albums[index].title, assetIDs: members)
    }

    func exportOriginal(for id: AssetID) async throws -> URL {
        throw Failure()
    }

    func delete(_ ids: [AssetID]) async throws {
        calls.append(.delete(ids))
        switch deleteBehavior {
        case .succeed:
            let doomed = Set(ids)
            assets.removeAll { doomed.contains($0.id) }
        case .userCancels:
            throw PhotoLibraryError.userCancelled
        case .fail:
            throw Failure()
        }
    }

    func thumbnail(for id: AssetID, targetSize: CGSize) async -> UIImage? { nil }

    @MainActor func playerItem(for id: AssetID) async throws -> AVPlayerItem {
        throw Failure()
    }

    nonisolated func observeChanges(_ handler: @escaping @Sendable () -> Void) {}
}
