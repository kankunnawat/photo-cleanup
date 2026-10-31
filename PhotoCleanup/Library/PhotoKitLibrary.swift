import AVFoundation
import Photos
import Synchronization
import UIKit
import UniformTypeIdentifiers

nonisolated final class PhotoKitLibrary: PhotoLibrary {
    static let keepAlbumTitle = "Keep"
    private static let keepAlbumIDKey = "keepAlbumLocalIdentifier"

    private let imageManager = PHCachingImageManager()
    private let observers = Mutex<[ChangeObserver]>([])

    func accessLevel() -> AccessLevel {
        Self.level(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func requestAccess() async -> AccessLevel {
        Self.level(await PHPhotoLibrary.requestAuthorization(for: .readWrite))
    }

    @concurrent func fetchAssets() async -> [AssetInfo] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: options)
        var infos: [AssetInfo] = []
        infos.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            infos.append(Self.info(for: asset))
        }
        return infos
    }

    @concurrent func protectionSources() async -> ProtectionSources {
        let keep = findKeepAlbum()
        var sources = ProtectionSources()
        if let keep {
            sources.keepAlbum = Self.memberIDs(of: keep)
        } else {
            sources.keepAlbumMissing = UserDefaults.standard.string(forKey: Self.keepAlbumIDKey) != nil
        }

        let favorites = PHFetchOptions()
        favorites.predicate = NSPredicate(format: "favorite == YES")
        sources.favorites = Self.ids(in: PHAsset.fetchAssets(with: favorites))

        let hidden = PHFetchOptions()
        hidden.includeHiddenAssets = true
        hidden.predicate = NSPredicate(format: "isHidden == YES")
        sources.hidden = Self.ids(in: PHAsset.fetchAssets(with: hidden))

        let albums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
        albums.enumerateObjects { album, _, _ in
            guard album.localIdentifier != keep?.localIdentifier else { return }
            sources.albums.append(AlbumInfo(
                id: album.localIdentifier,
                title: album.localizedTitle ?? "Untitled",
                assetIDs: Self.memberIDs(of: album)
            ))
        }
        sources.albums.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        return sources
    }

    @concurrent func existingIDs(among ids: [AssetID]) async -> Set<AssetID> {
        guard !ids.isEmpty else { return [] }
        return Self.ids(in: PHAsset.fetchAssets(withLocalIdentifiers: ids.map(\.rawValue), options: Self.visibleOnly()))
    }

    @concurrent func fileSizes(for ids: [AssetID]) async -> [AssetID: Int64] {
        guard !ids.isEmpty else { return [:] }
        var sizes: [AssetID: Int64] = [:]
        PHAsset.fetchAssets(withLocalIdentifiers: ids.map(\.rawValue), options: nil).enumerateObjects { asset, _, _ in
            if let bytes = Self.fileSize(of: asset) {
                sizes[AssetID(asset.localIdentifier)] = bytes
            }
        }
        return sizes
    }

    /// "fileSize" is undocumented KVC on PHAssetResource, but it is the only size source PhotoKit offers.
    /// Reading a key that is gone would raise, so a resource without it leaves the size unknown.
    private static func fileSize(of asset: PHAsset) -> Int64? {
        var total: Int64 = 0
        for resource in PHAssetResource.assetResources(for: asset) {
            guard resource.responds(to: fileSizeSelector),
                  let bytes = resource.value(forKey: "fileSize") as? NSNumber else { return nil }
            total += bytes.int64Value
        }
        return total
    }

    private static let fileSizeSelector = NSSelectorFromString("fileSize")

    @concurrent func addToKeepAlbum(_ ids: [AssetID]) async throws {
        guard !ids.isEmpty else { return }
        let albumID = try await keepAlbumCreatingIfNeeded().localIdentifier
        let assetIDs = ids.map(\.rawValue)
        try await PHPhotoLibrary.shared().performChanges {
            guard let album = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumID], options: nil).firstObject else { return }
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: assetIDs, options: nil)
            PHAssetCollectionChangeRequest(for: album)?.addAssets(assets)
        }
        guard Self.memberIDs(of: try requireKeepAlbum()).isSuperset(of: ids) else {
            throw PhotoLibraryError.keepAlbumUnavailable
        }
    }

    // MARK: Albums

    @concurrent func createAlbum(title: String) async throws -> AlbumInfo {
        let created = CreatedAlbum()
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
            created.id.withLock { $0 = request.placeholderForCreatedAssetCollection.localIdentifier }
        }
        guard let id = created.id.withLock({ $0 }),
              let album = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [id], options: nil).firstObject else {
            throw PhotoLibraryError.albumUnavailable
        }
        return AlbumInfo(id: album.localIdentifier, title: album.localizedTitle ?? title, assetIDs: Self.memberIDs(of: album))
    }

    @concurrent func add(_ ids: [AssetID], toAlbum albumID: String) async throws {
        try await setMembership(of: ids, inAlbum: albumID, to: true)
    }

    @concurrent func remove(_ ids: [AssetID], fromAlbum albumID: String) async throws {
        try await setMembership(of: ids, inAlbum: albumID, to: false)
    }

    private func setMembership(of ids: [AssetID], inAlbum albumID: String, to isMember: Bool) async throws {
        guard !ids.isEmpty else { return }
        let assetIDs = ids.map(\.rawValue)
        try await PHPhotoLibrary.shared().performChanges {
            guard let album = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumID], options: nil).firstObject,
                  let request = PHAssetCollectionChangeRequest(for: album) else { return }
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: assetIDs, options: nil)
            if isMember {
                request.addAssets(assets)
            } else {
                request.removeAssets(assets)
            }
        }
        guard let album = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumID], options: nil).firstObject else {
            throw PhotoLibraryError.albumUnavailable
        }
        let members = Self.memberIDs(of: album)
        guard isMember ? members.isSuperset(of: ids) : members.isDisjoint(with: ids) else {
            throw PhotoLibraryError.albumUnavailable
        }
    }

    // MARK: Sharing

    @concurrent func exportOriginal(for id: AssetID) async throws -> URL {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id.rawValue], options: nil).firstObject,
              let (resource, filename) = Self.shareResource(for: asset) else {
            throw PhotoLibraryError.assetUnavailable
        }
        let file = try ShareExports.makeFile(named: filename)
        do {
            try await Self.write(resource, to: file)
        } catch {
            // The export error is the one to report; launch clears anything left behind.
            try? ShareExports.discard(file)
            throw error
        }
        return file
    }

    /// The edited version when the asset has edits, else the original. A Live Photo gives its still.
    private static func shareResource(for asset: PHAsset) -> (PHAssetResource, String)? {
        let resources = PHAssetResource.assetResources(for: asset)
        let (editedType, originalType): (PHAssetResourceType, PHAssetResourceType) = asset.mediaType == .video
            ? (.fullSizeVideo, .video)
            : (.fullSizePhoto, .photo)
        guard let original = resources.first(where: { $0.type == originalType }) else { return nil }
        let chosen = resources.first { $0.type == editedType } ?? original
        let name = (original.originalFilename as NSString).deletingPathExtension
        let fileExtension = UTType(chosen.uniformTypeIdentifier)?.preferredFilenameExtension
            ?? (chosen.originalFilename as NSString).pathExtension
        return (chosen, fileExtension.isEmpty ? name : "\(name).\(fileExtension)")
    }

    /// Streams the resource to `file`, downloading it from iCloud if needed.
    private static func write(_ resource: PHAssetResource, to file: URL) async throws {
        let sink = try ExportSink(file: file)
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        let manager = PHAssetResourceManager.default()
        let request = PhotoKitRequest<(any Error)?>(cancelled: CancellationError())
        let requestFailure = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard request.begin(continuation) else { return }
                let requestID = manager.requestData(for: resource, options: options) { data in
                    sink.write(data)
                } completionHandler: { error in
                    request.finish(error)
                }
                if request.started(requestID) {
                    manager.cancelDataRequest(requestID)
                }
            }
        } onCancel: {
            if let requestID = request.cancel() {
                manager.cancelDataRequest(requestID)
            }
        }
        let writeFailure = sink.finish()
        if let failure = requestFailure ?? writeFailure {
            throw failure
        }
    }

    @concurrent func delete(_ ids: [AssetID]) async throws {
        guard !ids.isEmpty else { return }
        let assetIDs = ids.map(\.rawValue)
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(PHAsset.fetchAssets(withLocalIdentifiers: assetIDs, options: Self.visibleOnly()))
            }
        } catch let error as PHPhotosError where error.code == .userCancelled {
            throw PhotoLibraryError.userCancelled
        }
    }

    @concurrent func thumbnail(for id: AssetID, targetSize: CGSize) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id.rawValue], options: nil).firstObject else { return nil }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        let request = PhotoKitRequest<UIImage?>(cancelled: nil)
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard request.begin(continuation) else { return }
                let requestID = imageManager.requestImage(
                    for: asset,
                    targetSize: targetSize,
                    contentMode: .aspectFill,
                    options: options
                ) { image, _ in
                    request.finish(image)
                }
                if request.started(requestID) {
                    imageManager.cancelImageRequest(requestID)
                }
            }
        } onCancel: { [imageManager] in
            if let requestID = request.cancel() {
                imageManager.cancelImageRequest(requestID)
            }
        }
    }

    @MainActor func playerItem(for id: AssetID) async throws -> AVPlayerItem {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id.rawValue], options: nil).firstObject else {
            throw PhotoLibraryError.assetUnavailable
        }
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic
        let request = PhotoKitRequest<Result<PlayerItemHandoff, any Error>>(cancelled: .failure(CancellationError()))
        let result = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard request.begin(continuation) else { return }
                let requestID = imageManager.requestPlayerItem(forVideo: asset, options: options) { item, info in
                    if let item {
                        request.finish(.success(PlayerItemHandoff(item: item)))
                    } else {
                        request.finish(.failure(info?[PHImageErrorKey] as? any Error ?? CocoaError(.fileReadUnknown)))
                    }
                }
                if request.started(requestID) {
                    imageManager.cancelImageRequest(requestID)
                }
            }
        } onCancel: { [imageManager] in
            if let requestID = request.cancel() {
                imageManager.cancelImageRequest(requestID)
            }
        }
        return try result.get().item
    }

    func observeChanges(_ handler: @escaping @Sendable () -> Void) {
        let observer = ChangeObserver(handler: handler)
        observers.withLock { $0.append(observer) }
        PHPhotoLibrary.shared().register(observer)
    }

    // MARK: Keep album

    private func findKeepAlbum() -> PHAssetCollection? {
        let defaults = UserDefaults.standard
        if let storedID = defaults.string(forKey: Self.keepAlbumIDKey),
           let album = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [storedID], options: nil).firstObject {
            return album
        }
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "localizedTitle == %@", Self.keepAlbumTitle)
        guard let album = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: options).firstObject else {
            return nil
        }
        defaults.set(album.localIdentifier, forKey: Self.keepAlbumIDKey)
        return album
    }

    private func requireKeepAlbum() throws -> PHAssetCollection {
        guard let album = findKeepAlbum() else { throw PhotoLibraryError.keepAlbumUnavailable }
        return album
    }

    private func keepAlbumCreatingIfNeeded() async throws -> PHAssetCollection {
        if let album = findKeepAlbum() { return album }
        let title = Self.keepAlbumTitle
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
        }
        return try requireKeepAlbum()
    }

    // MARK: Mapping

    /// Lookups by identifier include hidden assets unless told otherwise. Apply treats a hidden asset
    /// as missing, so it is dropped and never deleted.
    private static func visibleOnly() -> PHFetchOptions {
        let options = PHFetchOptions()
        options.includeHiddenAssets = false
        return options
    }

    private static func info(for asset: PHAsset) -> AssetInfo {
        let kind: MediaKind = switch asset.mediaType {
        case .image: .photo
        case .video: .video
        default: .other
        }
        return AssetInfo(
            id: AssetID(asset.localIdentifier),
            kind: kind,
            isScreenshot: asset.mediaSubtypes.contains(.photoScreenshot),
            creationDate: asset.creationDate,
            pixelWidth: asset.pixelWidth,
            pixelHeight: asset.pixelHeight,
            duration: asset.duration,
            isFavorite: asset.isFavorite
        )
    }

    private static func memberIDs(of album: PHAssetCollection) -> Set<AssetID> {
        ids(in: PHAsset.fetchAssets(in: album, options: nil))
    }

    private static func ids(in result: PHFetchResult<PHAsset>) -> Set<AssetID> {
        var ids = Set<AssetID>(minimumCapacity: result.count)
        result.enumerateObjects { asset, _, _ in
            ids.insert(AssetID(asset.localIdentifier))
        }
        return ids
    }

    private static func level(_ status: PHAuthorizationStatus) -> AccessLevel {
        switch status {
        case .authorized: .full
        case .limited: .limited
        case .notDetermined: .notDetermined
        default: .denied
        }
    }
}

/// PhotoKit hands each request a fresh player item that nothing else references,
/// so moving it from PhotoKit's callback queue to the main actor is safe.
private nonisolated final class PlayerItemHandoff: @unchecked Sendable {
    let item: AVPlayerItem

    init(item: AVPlayerItem) {
        self.item = item
    }
}

/// Resumes a PhotoKit request exactly once: with its result, or with `cancelled` when the task is cancelled,
/// because PhotoKit may never call the result handler of a cancelled request.
/// Image requests and resource data requests both use it, because both request IDs are `Int32`.
private nonisolated final class PhotoKitRequest<Value: Sendable>: Sendable {
    private struct State {
        var continuation: CheckedContinuation<Value, Never>?
        var requestID: PHImageRequestID?
        var isCancelled = false
    }

    private let state = Mutex(State())
    private let cancelled: Value

    init(cancelled: Value) {
        self.cancelled = cancelled
    }

    /// Returns false (and resumes with `cancelled`) when the task was already cancelled.
    func begin(_ continuation: CheckedContinuation<Value, Never>) -> Bool {
        let isCancelled = state.withLock { state in
            if !state.isCancelled { state.continuation = continuation }
            return state.isCancelled
        }
        if isCancelled { continuation.resume(returning: cancelled) }
        return !isCancelled
    }

    /// Records the request; returns true when a cancel arrived meanwhile and the request must be cancelled now.
    func started(_ requestID: PHImageRequestID) -> Bool {
        state.withLock { state in
            state.requestID = requestID
            return state.isCancelled
        }
    }

    func finish(_ value: Value) {
        state.withLock { $0.continuation.take() }?.resume(returning: value)
    }

    /// Resumes with `cancelled` and returns the request to cancel, if it has started.
    func cancel() -> PHImageRequestID? {
        let (continuation, requestID) = state.withLock { state in
            state.isCancelled = true
            return (state.continuation.take(), state.requestID)
        }
        continuation?.resume(returning: cancelled)
        return requestID
    }
}

/// Carries the new album's identifier out of the change block.
private nonisolated final class CreatedAlbum: Sendable {
    let id = Mutex<String?>(nil)
}

/// Writes the chunks PhotoKit delivers. The first write error stops later writes and is reported by `finish`.
private nonisolated final class ExportSink: Sendable {
    private struct State {
        var handle: FileHandle?
        var failure: (any Error)?
    }

    private let state: Mutex<State>

    init(file: URL) throws {
        state = Mutex(State(handle: try FileHandle(forWritingTo: file)))
    }

    func write(_ data: Data) {
        state.withLock { state in
            guard state.failure == nil, let handle = state.handle else { return }
            do {
                try handle.write(contentsOf: data)
            } catch {
                state.failure = error
            }
        }
    }

    /// Closes the file and returns the first write or close error. Chunks that arrive later are dropped.
    func finish() -> (any Error)? {
        state.withLock { state in
            if let handle = state.handle.take() {
                do {
                    try handle.close()
                } catch {
                    state.failure = state.failure ?? error
                }
            }
            return state.failure
        }
    }
}

private nonisolated final class ChangeObserver: NSObject, PHPhotoLibraryChangeObserver, Sendable {
    private let handler: @Sendable () -> Void

    init(handler: @escaping @Sendable () -> Void) {
        self.handler = handler
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        handler()
    }
}
