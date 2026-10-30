import Foundation

/// Where app state lives: JSON files in Application Support, small flags in UserDefaults.
struct Persistence {
    static let noticeDismissedKey = "iCloudNoticeDismissed"
    private static let disabledAlbumsKey = "disabledProtectedAlbumIDs"
    private static let recentAlbumsKey = "recentAlbumIDs"

    let pending: JSONFileStore<PendingDecisions>
    let sizes: JSONFileStore<SizeCache>
    let log: JSONFileStore<CleanupLog>
    let defaults: UserDefaults

    init(directory: URL, defaults: UserDefaults) {
        pending = JSONFileStore(url: directory.appending(path: "pending.json"))
        sizes = JSONFileStore(url: directory.appending(path: "sizes.json"))
        log = JSONFileStore(url: directory.appending(path: "cleanup-log.json"))
        self.defaults = defaults
    }

    static func live() -> Persistence {
        Persistence(directory: .applicationSupportDirectory.appending(path: "PhotoCleanup"), defaults: .standard)
    }

    func loadDisabledAlbumIDs() -> Set<String> {
        Set(defaults.stringArray(forKey: Self.disabledAlbumsKey) ?? [])
    }

    func saveDisabledAlbumIDs(_ ids: Set<String>) {
        defaults.set(ids.sorted(), forKey: Self.disabledAlbumsKey)
    }

    func loadRecentAlbumIDs() -> [String] {
        defaults.stringArray(forKey: Self.recentAlbumsKey) ?? []
    }

    func saveRecentAlbumIDs(_ ids: [String]) {
        defaults.set(ids, forKey: Self.recentAlbumsKey)
    }

    /// Starts UI tests from a clean slate with the first-launch notice already seen.
    func resetForUITesting() throws {
        try pending.remove()
        try sizes.remove()
        try log.remove()
        defaults.removeObject(forKey: Self.disabledAlbumsKey)
        defaults.removeObject(forKey: Self.recentAlbumsKey)
        defaults.set(true, forKey: Self.noticeDismissedKey)
    }
}
