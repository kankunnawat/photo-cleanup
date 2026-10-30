import Foundation
import Observation

@Observable
final class AppModel {
    struct SizeProgress: Equatable {
        let measured: Int
        let total: Int
    }

    struct PendingSummary: Equatable {
        var keepCount = 0
        var trashCount = 0
        var trashBytes: Int64 = 0

        var isEmpty: Bool { keepCount == 0 && trashCount == 0 }
    }

    let library: any PhotoLibrary
    private let persistence: Persistence

    private(set) var access: AccessLevel
    private(set) var hasLoaded = false
    private(set) var snapshot = LibrarySnapshot.empty
    private(set) var protected = ProtectedSet()
    private(set) var sizes = SizeCache()
    private(set) var sizeProgress: SizeProgress?
    private(set) var log = CleanupLog()
    private(set) var pending = PendingDecisions() {
        didSet {
            schedulePendingSave()
            decisionsChanged()
        }
    }
    var disabledAlbumIDs: Set<String> {
        didSet {
            persistence.saveDisabledAlbumIDs(disabledAlbumIDs)
            protected = ProtectedSet(sources: sources, disabledAlbumIDs: disabledAlbumIDs)
            decisionsChanged()
        }
    }
    /// Albums last added to from the picker, most recent first.
    private(set) var recentAlbumIDs: [String] {
        didSet { persistence.saveRecentAlbumIDs(recentAlbumIDs) }
    }
    var errorMessage: String?

    // Derived from the snapshot, decisions, protection and sizes. Rebuilt only when one of those changes,
    // so view bodies read them instead of scanning the library.
    private(set) var monthRows: [MonthRow] = []
    private(set) var openCount = 0
    private(set) var screenshots: [AssetInfo] = []
    private(set) var largeVideos: [AssetInfo] = []
    private(set) var totalBytes: Int64 = 0
    private(set) var pendingSummary = PendingSummary()
    /// Bumps whenever the library, decisions or protection change; screens that keep their own list watch it.
    private(set) var revision = 0

    private var isObserving = false
    private var refreshTask: Task<Void, Never>?
    private var refreshAgain = false
    private var albumWrites = 0
    private var refreshDebounce: Task<Void, Never>?
    private var sizeTask: Task<Void, Never>?
    private var sizesLoad: Task<Void, Never>?
    private var pendingSaveDebounce: Task<Void, Never>?
    private var hasUnsavedPending = false
    private var pendingWrite: Task<Void, Never>?
    private var sizesWrite: Task<Void, Never>?

    private static let sizePublishInterval = Duration.seconds(2)
    private static let sizeSaveInterval = Duration.seconds(10)
    private static let pendingSaveDelay = Duration.milliseconds(500)
    private static let recentAlbumLimit = 3

    init(library: any PhotoLibrary, persistence: Persistence) {
        self.library = library
        self.persistence = persistence
        access = library.accessLevel()
        disabledAlbumIDs = persistence.loadDisabledAlbumIDs()
        recentAlbumIDs = persistence.loadRecentAlbumIDs()
        if let pending = load(persistence.pending) { self.pending = pending }
        if let log = load(persistence.log) { self.log = log }
        recomputePendingSummary()
    }

    var assets: [AssetInfo] { snapshot.assets }
    var assetsByID: [AssetID: AssetInfo] { snapshot.assetsByID }
    var months: [MonthGroup] { snapshot.months }
    var sources: ProtectionSources { snapshot.sources }
    var isMeasuringSizes: Bool { sizeProgress != nil }

    // MARK: Library snapshot

    func start() async {
        access = library.accessLevel()
        guard access == .full else { return }
        if sizesLoad == nil {
            sizesLoad = Task { await loadSizes() }
        }
        // The fill must see the stored sizes, or it measures the whole library again.
        await sizesLoad?.value
        if !isObserving {
            isObserving = true
            library.observeChanges { [weak self] in
                Task { @MainActor in self?.scheduleRefresh() }
            }
        }
        await refresh()
    }

    func requestAccess() async {
        access = await library.requestAccess()
        await start()
    }

    /// At most one refresh runs at a time. A call during a refresh asks for exactly one more pass
    /// and returns once that pass has landed.
    func refresh() async {
        if let running = refreshTask {
            refreshAgain = true
            await running.value
            return
        }
        let task = Task { await runRefreshes() }
        refreshTask = task
        await task.value
    }

    private func runRefreshes() async {
        repeat {
            refreshAgain = false
            let writesBefore = albumWrites
            let loaded = await LibrarySnapshot.load(from: library, disabledAlbumIDs: disabledAlbumIDs, calendar: .current)
            // A read that began before an album write would undo that write on screen, so read again.
            if albumWrites == writesBefore {
                install(loaded)
            } else {
                refreshAgain = true
            }
        } while refreshAgain
        refreshTask = nil
    }

    private func install(_ snapshot: LibrarySnapshot) {
        self.snapshot = snapshot
        protected = snapshot.disabledAlbumIDs == disabledAlbumIDs
            ? snapshot.protected
            : ProtectedSet(sources: snapshot.sources, disabledAlbumIDs: disabledAlbumIDs)
        hasLoaded = true
        let albumIDs = Set(snapshot.sources.albums.map(\.id))
        if !recentAlbumIDs.allSatisfy(albumIDs.contains) {
            recentAlbumIDs.removeAll { !albumIDs.contains($0) }
        }
        decisionsChanged()
        recomputeSizeTotals()
        fillSizes()
    }

    private func scheduleRefresh() {
        refreshDebounce?.cancel()
        refreshDebounce = Task {
            do {
                try await Task.sleep(for: .milliseconds(400))
            } catch {
                return
            }
            await refresh()
        }
    }

    // MARK: Derived lists

    private func decisionsChanged() {
        monthRows = Buckets.monthRows(snapshot.months, pending: pending, protected: protected)
        openCount = monthRows.reduce(0) { $0 + $1.open }
        screenshots = Buckets.screenshots(snapshot.screenshots, protected: protected, pending: pending)
        recomputeLargeVideos()
        recomputePendingSummary()
        revision += 1
    }

    private func recomputeLargeVideos() {
        largeVideos = Buckets.largeVideos(snapshot.videos, protected: protected, pending: pending, sizes: sizes)
    }

    private func recomputePendingSummary() {
        let trash = pending.trash
        pendingSummary = PendingSummary(
            keepCount: pending.keeps.count,
            trashCount: trash.count,
            trashBytes: sizes.total(of: trash)
        )
    }

    private func recomputeSizeTotals() {
        totalBytes = sizes.total(of: snapshot.assets.map(\.id))
        recomputeLargeVideos()
        recomputePendingSummary()
    }

    // MARK: Sizes

    /// Measures in chunks but publishes to observers at most every couple of seconds,
    /// so a first fill doesn't re-render every screen per chunk.
    private func fillSizes() {
        guard sizeTask == nil else { return }
        sizeTask = Task {
            let clock = ContinuousClock()
            var attempted = Set<AssetID>()
            var unpublished: [AssetID: Int64] = [:]
            var lastPublish = clock.now
            var lastSave = clock.now
            // Repeats to pick up assets a refresh added meanwhile; `attempted` stops retrying assets that yield no size.
            while true {
                let queue = sizes.missing(from: assets.map(\.id)).filter { !attempted.contains($0) }
                guard !queue.isEmpty else { break }
                sizeProgress = SizeProgress(measured: 0, total: queue.count)
                for start in stride(from: 0, to: queue.count, by: 200) {
                    let chunk = Array(queue[start..<min(start + 200, queue.count)])
                    attempted.formUnion(chunk)
                    unpublished.merge(await library.fileSizes(for: chunk)) { _, new in new }
                    let isLast = start + chunk.count == queue.count
                    guard isLast || clock.now - lastPublish >= Self.sizePublishInterval else { continue }
                    publishSizes(unpublished, progress: SizeProgress(measured: start + chunk.count, total: queue.count))
                    unpublished.removeAll()
                    lastPublish = clock.now
                    if clock.now - lastSave >= Self.sizeSaveInterval {
                        saveSizes()
                        lastSave = clock.now
                    }
                }
            }
            sizes.prune(keeping: Set(assetsByID.keys))
            saveSizes()
            sizeProgress = nil
            recomputeSizeTotals()
            sizeTask = nil
        }
    }

    private func publishSizes(_ measured: [AssetID: Int64], progress: SizeProgress) {
        sizes.merge(measured)
        sizeProgress = progress
        recomputeSizeTotals()
    }

    // MARK: Decisions

    func decide(_ decision: Decision, for id: AssetID) {
        pending.set(decision, for: id)
    }

    /// One write to `pending` for the whole batch, so observers update once.
    func decide(_ decision: Decision, for ids: [AssetID]) {
        var updated = pending
        updated.set(decision, for: ids)
        pending = updated
    }

    /// Bulk modes go through here, so a protected asset never reaches pending trash.
    func queueTrash(_ ids: [AssetID]) {
        pending.set(.trash, for: Buckets.trashable(ids, protected: protected))
    }

    func freeUpSelection(before cutoff: Date, kind: FreeUpKind, order: FreeUpOrder) -> FreeUpSelection {
        Buckets.freeUpCandidates(assets, before: cutoff, kind: kind, order: order, protected: protected, pending: pending, sizes: sizes)
    }

    /// Free up's Delete, as one change: tiles the user kept become pending keeps, the rest pending trash.
    func queueFreeUp(trash: [AssetID], keep: [AssetID]) {
        var updated = pending
        updated.set(.keep, for: keep)
        updated.set(.trash, for: Buckets.trashable(trash, protected: protected))
        pending = updated
    }

    func clearDecision(for id: AssetID) {
        pending.clear(id)
    }

    func clearDecisions(for ids: [AssetID]) {
        var updated = pending
        updated.clear(ids)
        pending = updated
    }

    /// A deck swipe; only the deck's own history can undo it.
    func swipe(_ decision: Decision, for id: AssetID, history: inout DeckHistory) {
        history.swipe(decision, for: id, in: &pending)
    }

    @discardableResult
    func undo(_ history: inout DeckHistory) -> AssetID? {
        var updated = pending
        guard let id = history.undo(in: &updated) else { return nil }
        pending = updated
        return id
    }

    func state(of id: AssetID) -> AssetState {
        AssetState(id: id, inLibrary: assetsByID[id] != nil, pending: pending, keepAlbum: sources.keepAlbum)
    }

    // MARK: Albums

    /// Recently used albums that still exist, most recent first.
    var recentAlbums: [AlbumInfo] {
        recentAlbumIDs.compactMap { id in sources.albums.first { $0.id == id } }
    }

    /// Writes to Photos, then updates the albums here at once instead of waiting for the change observer.
    func add(_ id: AssetID, toAlbum albumID: String) async throws {
        try await library.add(id, toAlbum: albumID)
        changeMembers(ofAlbum: albumID) { $0.insert(id) }
        recentAlbumIDs = Array(([albumID] + recentAlbumIDs.filter { $0 != albumID }).prefix(Self.recentAlbumLimit))
        // Apply would skip a now-protected delete; clearing it keeps Apply's counts honest.
        if !disabledAlbumIDs.contains(albumID), pending.decision(for: id) == .trash {
            pending.clear(id)
        }
    }

    /// Never queues a delete: the photo just becomes reviewable again if nothing else protects it.
    func remove(_ id: AssetID, fromAlbum albumID: String) async throws {
        try await library.remove(id, fromAlbum: albumID)
        changeMembers(ofAlbum: albumID) { $0.remove(id) }
    }

    func createAlbum(titled title: String, adding id: AssetID) async throws {
        let album = try await library.createAlbum(title: title)
        // A refresh that landed during the create may already list it.
        changeAlbums { albums in
            if !albums.contains(where: { $0.id == album.id }) { albums.append(album) }
        }
        try await add(id, toAlbum: album.id)
    }

    private func changeMembers(ofAlbum albumID: String, _ change: (inout Set<AssetID>) -> Void) {
        changeAlbums { albums in
            guard let index = albums.firstIndex(where: { $0.id == albumID }) else { return }
            var members = albums[index].assetIDs
            change(&members)
            albums[index] = AlbumInfo(id: albumID, title: albums[index].title, assetIDs: members)
        }
    }

    private func changeAlbums(_ change: (inout [AlbumInfo]) -> Void) {
        var albums = sources.albums
        change(&albums)
        snapshot.replaceAlbums(albums)
        albumWrites += 1
        // `replaceAlbums` already rebuilt the snapshot's set; build another only for changed switches.
        protected = snapshot.disabledAlbumIDs == disabledAlbumIDs
            ? snapshot.protected
            : ProtectedSet(sources: snapshot.sources, disabledAlbumIDs: disabledAlbumIDs)
        decisionsChanged()
    }

    // MARK: Apply

    func apply() async -> ApplyReport {
        let report = await ApplyRunner(library: library).run(
            pending: pending,
            disabledAlbumIDs: disabledAlbumIDs,
            sizes: sizes,
            now: .now
        )
        pending = report.pending
        if !report.measuredSizes.isEmpty {
            sizes.merge(report.measuredSizes)
            recomputeSizeTotals()
        }
        if let entry = report.logEntry {
            log.append(entry)
            save(log, to: persistence.log)
        }
        await refresh()
        return report
    }

    // MARK: Persistence

    private func loadSizes() async {
        do {
            if let stored = try await persistence.sizes.loadInBackground() {
                sizes = stored
                recomputeSizeTotals()
            }
        } catch {
            errorMessage = "Saved data could not be read and was reset: \(error.localizedDescription)"
        }
    }

    private func schedulePendingSave() {
        hasUnsavedPending = true
        pendingSaveDebounce?.cancel()
        pendingSaveDebounce = Task {
            do {
                try await Task.sleep(for: Self.pendingSaveDelay)
            } catch {
                return
            }
            flushPendingSave()
        }
    }

    /// Writes pending decisions now instead of after the debounce; called when the scene leaves the foreground.
    func flushPendingSave() {
        pendingSaveDebounce?.cancel()
        pendingSaveDebounce = nil
        guard hasUnsavedPending else { return }
        hasUnsavedPending = false
        pendingWrite = write(pending, to: persistence.pending, after: pendingWrite)
    }

    private func saveSizes() {
        sizesWrite = write(sizes, to: persistence.sizes, after: sizesWrite)
    }

    /// Encodes and writes off the main actor. Each write waits for the previous one to the same file,
    /// so an older value never lands last.
    private func write<Value>(_ value: Value, to store: JSONFileStore<Value>, after previous: Task<Void, Never>?) -> Task<Void, Never> {
        Task {
            await previous?.value
            do {
                try await store.saveInBackground(value)
            } catch {
                errorMessage = "Could not save: \(error.localizedDescription)"
            }
        }
    }

    private func load<Value>(_ store: JSONFileStore<Value>) -> Value? {
        do {
            return try store.load()
        } catch {
            errorMessage = "Saved data could not be read and was reset: \(error.localizedDescription)"
            return nil
        }
    }

    private func save<Value>(_ value: Value, to store: JSONFileStore<Value>) {
        do {
            try store.save(value)
        } catch {
            errorMessage = "Could not save: \(error.localizedDescription)"
        }
    }
}
