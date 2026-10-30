import Foundation
import Testing
@testable import PhotoCleanup

struct ApplyPlanTests {
    @Test func dropsMissingAndNewlyProtectedAndSplitsTheRest() {
        var pending = PendingDecisions()
        pending.set(.keep, for: AssetID("keep"))
        pending.set(.keep, for: AssetID("keep-gone"))
        pending.set(.trash, for: AssetID("trash"))
        pending.set(.trash, for: AssetID("trash-gone"))
        pending.set(.trash, for: AssetID("trash-now-favorite"))
        let existing = Set(["keep", "trash", "trash-now-favorite"].map(AssetID.init))

        let plan = ApplyPlan(pending: pending, existing: existing, protected: ProtectedSet(ids: [AssetID("trash-now-favorite")]))

        #expect(plan.keeps == [AssetID("keep")])
        #expect(plan.trash == [AssetID("trash")])
        #expect(plan.missing == [AssetID("keep-gone"), AssetID("trash-gone")])
        #expect(plan.newlyProtected == [AssetID("trash-now-favorite")])
    }
}

struct ApplyRunnerTests {
    let assets = [
        Fixtures.photo("a", Fixtures.date(2025, 1)),
        Fixtures.photo("b", Fixtures.date(2025, 1)),
        Fixtures.photo("c", Fixtures.date(2025, 1)),
        Fixtures.photo("d", Fixtures.date(2025, 1)),
    ]
    let now = Fixtures.date(2026, 1)

    func pending(keep: [String], trash: [String]) -> PendingDecisions {
        var pending = PendingDecisions()
        pending.set(.keep, for: keep.map(AssetID.init))
        pending.set(.trash, for: trash.map(AssetID.init))
        return pending
    }

    @Test func addsKeepsBeforeOneDeleteCallAndLogsBytes() async {
        let library = FakePhotoLibrary(assets: assets)
        let sizes = SizeCache(bytes: [AssetID("b"): 1_000, AssetID("c"): 2_000])

        let report = await ApplyRunner(library: library).run(
            pending: pending(keep: ["a"], trash: ["b", "c"]),
            disabledAlbumIDs: [],
            sizes: sizes,
            now: now
        )

        #expect(await library.calls == [
            .addToKeepAlbum([AssetID("a")]),
            .delete([AssetID("b"), AssetID("c")]),
        ])
        #expect(report.outcome == .completed)
        #expect(report.pending.isEmpty)
        #expect(report.keptCount == 1)
        #expect(report.logEntry == CleanupLog.Entry(date: now, deletedCount: 2, bytes: 3_000))
        #expect(await library.keepAlbum == [AssetID("a")])
        #expect(await library.assets.map(\.id) == [AssetID("a"), AssetID("d")])
    }

    @Test func measuresUncachedTrashSizesBeforeDeletingSoTheLogIsRight() async {
        let library = FakePhotoLibrary(assets: assets)
        await library.configure { $0.sizes = [AssetID("b"): 1_000, AssetID("c"): 2_000] }

        let report = await ApplyRunner(library: library).run(
            pending: pending(keep: [], trash: ["b", "c"]),
            disabledAlbumIDs: [],
            sizes: SizeCache(bytes: [AssetID("b"): 1_000]),
            now: now
        )

        #expect(report.logEntry?.bytes == 3_000)
        #expect(report.measuredSizes == [AssetID("c"): 2_000])
    }

    @Test func cancelledDeleteKeepsTrashPendingButSettlesKeeps() async {
        let library = FakePhotoLibrary(assets: assets)
        await library.configure { $0.deleteBehavior = .userCancels }

        let report = await ApplyRunner(library: library).run(
            pending: pending(keep: ["a"], trash: ["b"]),
            disabledAlbumIDs: [],
            sizes: SizeCache(),
            now: now
        )

        #expect(report.outcome == .deleteCancelled)
        #expect(report.pending.entries == [.init(id: AssetID("b"), decision: .trash)])
        #expect(report.logEntry == nil)
        #expect(await library.assets.count == 4)
        #expect(await library.keepAlbum == [AssetID("a")])
    }

    @Test func failedKeepAddStopsBeforeAnyDelete() async {
        let library = FakePhotoLibrary(assets: assets)
        await library.configure { $0.keepAlbumFails = true }

        let report = await ApplyRunner(library: library).run(
            pending: pending(keep: ["a"], trash: ["b"]),
            disabledAlbumIDs: [],
            sizes: SizeCache(),
            now: now
        )

        #expect(await library.calls == [.addToKeepAlbum([AssetID("a")])])
        #expect(report.outcome == .failed("Could not add photos to the Keep album: The Keep album could not be found or created."))
        #expect(report.pending.entries == [
            .init(id: AssetID("a"), decision: .keep),
            .init(id: AssetID("b"), decision: .trash),
        ])
        #expect(report.logEntry == nil)
        #expect(await library.assets.count == 4)
    }

    @Test func realDeleteErrorSurfacesAndKeepsTrashPending() async {
        let library = FakePhotoLibrary(assets: assets)
        await library.configure { $0.deleteBehavior = .fail }

        let report = await ApplyRunner(library: library).run(
            pending: pending(keep: [], trash: ["b"]),
            disabledAlbumIDs: [],
            sizes: SizeCache(),
            now: now
        )

        #expect(report.outcome == .failed("Could not delete: disk on fire"))
        #expect(report.pending.trash == [AssetID("b")])
    }

    @Test func neverDeletesAssetsThatBecameProtectedOrDisappeared() async {
        let library = FakePhotoLibrary(assets: assets)
        await library.configure {
            $0.favorites = [AssetID("b")]
            $0.albums = [AlbumInfo(id: "trip", title: "Trip", assetIDs: [AssetID("c")])]
        }

        let report = await ApplyRunner(library: library).run(
            pending: pending(keep: [], trash: ["b", "c", "d", "gone"]),
            disabledAlbumIDs: [],
            sizes: SizeCache(),
            now: now
        )

        #expect(await library.calls == [.delete([AssetID("d")])])
        #expect(report.droppedProtected == 2)
        #expect(report.droppedMissing == 1)
        #expect(report.pending.isEmpty)
    }

    @Test func switchedOffAlbumNoLongerProtects() async {
        let library = FakePhotoLibrary(assets: assets)
        await library.configure { $0.albums = [AlbumInfo(id: "memes", title: "Memes", assetIDs: [AssetID("c")])] }

        _ = await ApplyRunner(library: library).run(
            pending: pending(keep: [], trash: ["c"]),
            disabledAlbumIDs: ["memes"],
            sizes: SizeCache(),
            now: now
        )

        #expect(await library.calls == [.delete([AssetID("c")])])
    }

    @Test func keepsOnlyRunMakesNoDeleteCall() async {
        let library = FakePhotoLibrary(assets: assets)

        let report = await ApplyRunner(library: library).run(
            pending: pending(keep: ["a", "b"], trash: []),
            disabledAlbumIDs: [],
            sizes: SizeCache(),
            now: now
        )

        #expect(await library.calls == [.addToKeepAlbum([AssetID("a"), AssetID("b")])])
        #expect(report.outcome == .completed)
        #expect(report.logEntry == nil)
    }
}

struct AssetStateTests {
    @Test func resolvesEachState() {
        var pending = PendingDecisions()
        pending.set(.keep, for: AssetID("pk"))
        pending.set(.trash, for: AssetID("pt"))
        let keep: Set = [AssetID("kept")]

        func state(_ name: String, inLibrary: Bool = true) -> AssetState {
            AssetState(id: AssetID(name), inLibrary: inLibrary, pending: pending, keepAlbum: keep)
        }

        #expect(state("new") == .undecided)
        #expect(state("pk") == .pendingKeep)
        #expect(state("pt") == .pendingTrash)
        #expect(state("kept") == .kept)
        #expect(state("pt", inLibrary: false) == .deleted)
    }
}
