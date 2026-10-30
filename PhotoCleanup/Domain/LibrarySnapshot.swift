import Foundation

/// One consistent read of the library, built off the main actor so a refresh lands on the model in one step.
nonisolated struct LibrarySnapshot: Sendable {
    let assets: [AssetInfo]
    let assetsByID: [AssetID: AssetInfo]
    let months: [MonthGroup]
    private(set) var sources: ProtectionSources
    /// The album switches `protected` was built with.
    let disabledAlbumIDs: Set<String>
    private(set) var protected: ProtectedSet
    /// Every screenshot, newest first; the screenshot bucket filters this instead of the whole library.
    let screenshots: [AssetInfo]
    let videos: [AssetInfo]
    let photoCount: Int

    static let empty = LibrarySnapshot(assets: [], sources: ProtectionSources(), disabledAlbumIDs: [], calendar: .current)

    init(assets: [AssetInfo], sources: ProtectionSources, disabledAlbumIDs: Set<String>, calendar: Calendar) {
        self.assets = assets
        assetsByID = Dictionary(assets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        months = MonthGrouping.groups(assets, calendar: calendar)
        self.sources = sources
        self.disabledAlbumIDs = disabledAlbumIDs
        protected = ProtectedSet(sources: sources, disabledAlbumIDs: disabledAlbumIDs)
        screenshots = assets
            .filter(\.isScreenshot)
            .sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
        videos = assets.filter { $0.kind == .video }
        photoCount = assets.count { $0.kind == .photo }
    }

    /// Applies an album write the app just made, without reading the whole library again.
    mutating func replaceAlbums(_ albums: [AlbumInfo]) {
        sources.albums = albums.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        protected = ProtectedSet(sources: sources, disabledAlbumIDs: disabledAlbumIDs)
    }

    @concurrent static func load(
        from library: any PhotoLibrary,
        disabledAlbumIDs: Set<String>,
        calendar: Calendar
    ) async -> LibrarySnapshot {
        async let assets = library.fetchAssets()
        async let sources = library.protectionSources()
        return LibrarySnapshot(
            assets: await assets,
            sources: await sources,
            disabledAlbumIDs: disabledAlbumIDs,
            calendar: calendar
        )
    }
}
