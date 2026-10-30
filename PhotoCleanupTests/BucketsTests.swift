import Foundation
import Testing
@testable import PhotoCleanup

struct FreeUpCandidatesTests {
    let cutoff = Fixtures.date(2025, 6, 1)

    private func select(
        _ assets: [AssetInfo],
        kind: FreeUpKind = .all,
        order: FreeUpOrder = .oldestFirst,
        protected: ProtectedSet = ProtectedSet(),
        pending: PendingDecisions = PendingDecisions(),
        sizes: SizeCache = SizeCache()
    ) -> FreeUpSelection {
        Buckets.freeUpCandidates(assets, before: cutoff, kind: kind, order: order, protected: protected, pending: pending, sizes: sizes)
    }

    @Test func includesOnlyAssetsBeforeTheCutoffOldestFirst() {
        let assets = [
            Fixtures.photo("recent", Fixtures.date(2025, 7)),
            Fixtures.photo("old", Fixtures.date(2025, 2)),
            Fixtures.photo("older", Fixtures.date(2024, 2)),
            Fixtures.photo("undated", nil),
        ]

        let selection = select(assets)

        #expect(selection.candidates.map(\.id) == [AssetID("older"), AssetID("old")])
        #expect(selection.skippedProtected == 0)
    }

    @Test func excludesProtectedAndCountsThem() {
        let assets = [
            Fixtures.photo("kept", Fixtures.date(2025, 1)),
            Fixtures.photo("fav", Fixtures.date(2025, 1), favorite: true),
            Fixtures.photo("plain", Fixtures.date(2025, 1)),
            Fixtures.photo("recent-kept", Fixtures.date(2025, 9)),
        ]
        let protected = ProtectedSet(
            sources: ProtectionSources(keepAlbum: [AssetID("kept"), AssetID("recent-kept")], favorites: [AssetID("fav")]),
            disabledAlbumIDs: []
        )

        let selection = select(assets, protected: protected)

        #expect(selection.candidates.map(\.id) == [AssetID("plain")])
        #expect(selection.skippedProtected == 2)
    }

    @Test func listsPendingKeepAsKeptAndPendingTrashAsCandidate() {
        let assets = [
            Fixtures.photo("keep-me", Fixtures.date(2025, 1)),
            Fixtures.photo("trash-me", Fixtures.date(2025, 2)),
        ]
        var pending = PendingDecisions()
        pending.set(.keep, for: AssetID("keep-me"))
        pending.set(.trash, for: AssetID("trash-me"))

        let selection = select(assets, pending: pending)

        #expect(selection.candidates.map(\.id) == [AssetID("keep-me"), AssetID("trash-me")])
        #expect(selection.kept == [AssetID("keep-me")])
    }

    @Test func filterKeepsOnlyTheChosenKindAndOtherOnlyUnderAll() {
        let assets = [
            Fixtures.photo("photo", Fixtures.date(2025, 1)),
            Fixtures.video("video", Fixtures.date(2025, 2)),
            AssetInfo(id: AssetID("other"), kind: .other, creationDate: Fixtures.date(2025, 3)),
        ]

        #expect(select(assets, kind: .all).candidates.map(\.id) == [AssetID("photo"), AssetID("video"), AssetID("other")])
        #expect(select(assets, kind: .photos).candidates.map(\.id) == [AssetID("photo")])
        #expect(select(assets, kind: .videos).candidates.map(\.id) == [AssetID("video")])
    }

    @Test func skippedCountsOnlyProtectedAssetsOfTheShownKind() {
        let assets = [
            Fixtures.photo("protected-photo", Fixtures.date(2025, 1)),
            Fixtures.video("protected-video", Fixtures.date(2025, 1)),
            Fixtures.video("plain-video", Fixtures.date(2025, 1)),
        ]
        let protected = ProtectedSet(ids: [AssetID("protected-photo"), AssetID("protected-video")])

        let selection = select(assets, kind: .videos, protected: protected)

        #expect(selection.candidates.map(\.id) == [AssetID("plain-video")])
        #expect(selection.skippedProtected == 1)
    }

    @Test func pendingKeepsLandInKeptUnderAFilter() {
        let assets = [
            Fixtures.photo("kept-photo", Fixtures.date(2025, 1)),
            Fixtures.video("kept-video", Fixtures.date(2025, 1)),
            Fixtures.video("open-video", Fixtures.date(2025, 2)),
        ]
        var pending = PendingDecisions()
        pending.set(.keep, for: [AssetID("kept-photo"), AssetID("kept-video")])

        let selection = select(assets, kind: .videos, pending: pending)

        #expect(selection.candidates.map(\.id) == [AssetID("kept-video"), AssetID("open-video")])
        #expect(selection.kept == [AssetID("kept-video")])
    }

    @Test func biggestFirstPutsUnknownSizesLastOldestFirst() {
        let assets = [
            Fixtures.photo("unknown-new", Fixtures.date(2025, 3)),
            Fixtures.photo("small", Fixtures.date(2025, 1)),
            Fixtures.photo("unknown-old", Fixtures.date(2024, 3)),
            Fixtures.video("big", Fixtures.date(2025, 2)),
        ]
        let sizes = SizeCache(bytes: [AssetID("small"): 10, AssetID("big"): 500])

        let selection = select(assets, order: .biggestFirst, sizes: sizes)

        #expect(selection.candidates.map(\.id) == [AssetID("big"), AssetID("small"), AssetID("unknown-old"), AssetID("unknown-new")])
    }

    @Test func biggestFirstBreaksSizeTiesOldestFirst() {
        let assets = [
            Fixtures.photo("tie-new", Fixtures.date(2025, 3)),
            Fixtures.photo("tie-old", Fixtures.date(2024, 3)),
            Fixtures.photo("tie-mid", Fixtures.date(2025, 1)),
        ]
        let sizes = SizeCache(bytes: [AssetID("tie-new"): 70, AssetID("tie-old"): 70, AssetID("tie-mid"): 70])

        let selection = select(assets, order: .biggestFirst, sizes: sizes)

        #expect(selection.candidates.map(\.id) == [AssetID("tie-old"), AssetID("tie-mid"), AssetID("tie-new")])
    }
}

struct TrashableTests {
    @Test func protectedIDsNeverReachPendingTrash() {
        let ids = ["plain", "fav", "album", "other"].map(AssetID.init)
        let protected = ProtectedSet(
            sources: ProtectionSources(
                favorites: [AssetID("fav")],
                albums: [AlbumInfo(id: "trip", title: "Trip", assetIDs: [AssetID("album")])]
            ),
            disabledAlbumIDs: []
        )
        var pending = PendingDecisions()

        pending.set(.trash, for: Buckets.trashable(ids, protected: protected))

        #expect(pending.trash == [AssetID("plain"), AssetID("other")])
    }
}

struct ProtectedSetTests {
    @Test func unionsKeepFavoritesHiddenAndEnabledAlbums() {
        let sources = ProtectionSources(
            keepAlbum: [AssetID("k")],
            favorites: [AssetID("f")],
            hidden: [AssetID("h")],
            albums: [
                AlbumInfo(id: "on", title: "Trip", assetIDs: [AssetID("t")]),
                AlbumInfo(id: "off", title: "Memes", assetIDs: [AssetID("m")]),
            ]
        )

        let protected = ProtectedSet(sources: sources, disabledAlbumIDs: ["off"])

        #expect(protected.ids == Set(["k", "f", "h", "t"].map(AssetID.init)))
    }

    @Test func albumsNotSwitchedOffAreProtectedByDefault() {
        let sources = ProtectionSources(albums: [AlbumInfo(id: "new", title: "New", assetIDs: [AssetID("n")])])

        #expect(ProtectedSet(sources: sources, disabledAlbumIDs: ["some-old-album"]).contains(AssetID("n")))
    }
}

struct ScreenshotBucketTests {
    @Test func listsUnprotectedUndecidedScreenshotsNewestFirst() {
        let assets = [
            Fixtures.photo("shot-old", Fixtures.date(2024, 1), screenshot: true),
            Fixtures.photo("shot-new", Fixtures.date(2025, 1), screenshot: true),
            Fixtures.photo("shot-fav", Fixtures.date(2025, 2), screenshot: true),
            Fixtures.photo("shot-queued", Fixtures.date(2025, 3), screenshot: true),
            Fixtures.photo("photo", Fixtures.date(2025, 1)),
        ]
        var pending = PendingDecisions()
        pending.set(.trash, for: AssetID("shot-queued"))

        let shots = Buckets.screenshots(assets, protected: ProtectedSet(ids: [AssetID("shot-fav")]), pending: pending)

        #expect(shots.map(\.id) == [AssetID("shot-new"), AssetID("shot-old")])
    }
}

struct LargeVideoBucketTests {
    @Test func sortsUnprotectedVideosBiggestFirstWithUnknownSizesLast() {
        let assets = [
            Fixtures.video("small", Fixtures.date(2025, 1)),
            Fixtures.video("unknown", Fixtures.date(2025, 1)),
            Fixtures.video("big", Fixtures.date(2025, 1)),
            Fixtures.video("kept", Fixtures.date(2025, 1)),
            Fixtures.photo("huge-photo", Fixtures.date(2025, 1)),
        ]
        let sizes = SizeCache(bytes: [
            AssetID("small"): 10,
            AssetID("big"): 500,
            AssetID("kept"): 900,
            AssetID("huge-photo"): 9_000,
        ])

        let videos = Buckets.largeVideos(
            assets,
            protected: ProtectedSet(ids: [AssetID("kept")]),
            pending: PendingDecisions(),
            sizes: sizes
        )

        #expect(videos.map(\.id) == [AssetID("big"), AssetID("small"), AssetID("unknown")])
    }
}

struct SizeCacheTests {
    @Test func totalsKnownSizesAndListsMissing() throws {
        var cache = SizeCache()
        cache.merge([AssetID("a"): 100, AssetID("b"): 50])

        #expect(cache.total(of: [AssetID("a"), AssetID("b"), AssetID("c")]) == 150)
        #expect(cache.missing(from: [AssetID("a"), AssetID("c")]) == [AssetID("c")])
    }

    @Test func persistsThroughTheFileStore() throws {
        let store = JSONFileStore<SizeCache>(url: .temporaryDirectory.appending(path: "\(UUID().uuidString)/sizes.json"))
        defer { try? store.remove() }
        try store.save(SizeCache(bytes: [AssetID("x/y:z"): 1_234_567_890_123]))

        #expect(try store.load()?[AssetID("x/y:z")] == 1_234_567_890_123)
    }
}
