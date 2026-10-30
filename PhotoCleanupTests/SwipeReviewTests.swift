import Foundation
import Testing
@testable import PhotoCleanup

struct SwipeDeckTests {
    let newest = AssetID("newest")
    let big = AssetID("big")
    let mid = AssetID("mid")
    let oldest = AssetID("oldest")
    let assetsByID = Dictionary(uniqueKeysWithValues: [
        Fixtures.photo("newest", Fixtures.date(2025, 4)),
        Fixtures.video("big", Fixtures.date(2025, 3)),
        Fixtures.photo("mid", Fixtures.date(2025, 2)),
        Fixtures.video("oldest", Fixtures.date(2025, 1)),
    ].map { ($0.id, $0) })
    let sizes = SizeCache(bytes: [AssetID("newest"): 10, AssetID("big"): 900, AssetID("mid"): 50, AssetID("oldest"): 300])

    private func deal(
        _ ids: [AssetID]? = nil,
        filter: MediaFilter = .all,
        pending: PendingDecisions = PendingDecisions(),
        protected: ProtectedSet = ProtectedSet()
    ) -> SwipeDeck {
        SwipeDeck(dealing: ids ?? [newest, big, mid, oldest], filter: filter, assetsByID: assetsByID, pending: pending, protected: protected)
    }

    private func open(_ deck: SwipeDeck, _ pending: PendingDecisions) -> [AssetID] {
        deck.open(pending: pending, protected: ProtectedSet(), assetsByID: assetsByID)
    }

    @Test func dealsOnlyOpenCardsOfTheFilteredKind() {
        var pending = PendingDecisions()
        pending.set(.keep, for: oldest)
        let protected = ProtectedSet(ids: [mid])

        #expect(deal(pending: pending, protected: protected).queue == [newest, big])
        #expect(deal(filter: .videos, pending: pending, protected: protected).queue == [big])
        #expect(deal(filter: .photos, pending: pending, protected: protected).queue == [newest])
    }

    @Test func aSortReordersEveryDealtCardAndKeepsTheOpenCount() {
        var pending = PendingDecisions()
        var history = DeckHistory()
        var deck = deal()
        history.swipe(.trash, for: newest, in: &pending)

        deck.sort(.biggestFirst, assetsByID: assetsByID, sizes: sizes)

        #expect(deck.queue == [big, oldest, mid, newest])
        #expect(open(deck, pending) == [big, oldest, mid])
    }

    @Test func bringToFrontMovesOnlyThatCardAndIgnoresAnUnknownOne() {
        var deck = deal()
        deck.sort(.biggestFirst, assetsByID: assetsByID, sizes: sizes)

        deck.bringToFront(mid)
        #expect(deck.queue == [mid, big, oldest, newest])

        deck.bringToFront(AssetID("missing"))
        #expect(deck.queue == [mid, big, oldest, newest])
    }

    @Test func noOrderPutsBackTheDealtOrder() {
        var deck = deal([mid, oldest, newest, big])

        deck.sort(.biggestFirst, assetsByID: assetsByID, sizes: sizes)
        deck.sort(nil, assetsByID: assetsByID, sizes: sizes)

        #expect(deck.queue == [mid, oldest, newest, big])
    }
}

final class SwipeReviewModelTests {
    let suite = "SwipeReviewModelTests-\(UUID().uuidString)"
    let directory: URL
    let defaults: UserDefaults
    let persistence: Persistence

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: suite)
        defaults = try #require(UserDefaults(suiteName: suite))
        persistence = Persistence(directory: directory, defaults: defaults)
    }

    isolated deinit {
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: directory)
    }

    @Test func undoPutsTheCardBackOnTopWithOrWithoutASort() async {
        let ids = ["newest", "big", "mid", "oldest"].map(AssetID.init)
        let (newest, big, mid, oldest) = (ids[0], ids[1], ids[2], ids[3])
        let model = AppModel(library: FakePhotoLibrary(assets: [
            Fixtures.photo("newest", Fixtures.date(2025, 4)),
            Fixtures.video("big", Fixtures.date(2025, 3)),
            Fixtures.photo("mid", Fixtures.date(2025, 2)),
            Fixtures.video("oldest", Fixtures.date(2025, 1)),
        ]), persistence: persistence)
        await model.start()
        var deck = SwipeDeck(dealing: ids, filter: .all, assetsByID: model.assetsByID, pending: model.pending, protected: model.protected)
        var history = DeckHistory()
        let open = { (deck: SwipeDeck) in deck.open(pending: model.pending, protected: model.protected, assetsByID: model.assetsByID) }

        model.swipe(.trash, for: newest, history: &history)
        model.swipe(.keep, for: big, history: &history)
        model.undo(&history, in: &deck)
        #expect(open(deck) == [big, mid, oldest])

        deck.sort(.biggestFirst, assetsByID: model.assetsByID, sizes: SizeCache(bytes: [newest: 10, big: 900, mid: 50, oldest: 300]))
        #expect(open(deck) == [big, oldest, mid])
        model.undo(&history, in: &deck)

        #expect(model.pending.isEmpty)
        #expect(open(deck) == [newest, big, oldest, mid])
    }

    @Test func monthRowsFollowTheFilterButHomesOpenCountDoesNot() async {
        let library = FakePhotoLibrary(assets: [
            Fixtures.photo("feb-photo", Fixtures.date(2025, 2)),
            Fixtures.video("feb-video", Fixtures.date(2025, 2, 10)),
            Fixtures.video("feb-video-2", Fixtures.date(2025, 2, 5)),
            Fixtures.photo("jan-photo", Fixtures.date(2025, 1)),
        ])
        let model = AppModel(library: library, persistence: persistence)
        await model.start()
        #expect(model.openCount == 4)
        #expect(model.monthRows.map(\.total) == [3, 1])

        model.swipeFilter = .videos

        #expect(model.monthRows.map(\.open) == [2, 0])
        #expect(model.monthRows.map(\.total) == [2, 0])
        #expect(model.openCount == 4)

        model.decide(.trash, for: AssetID("feb-video"))

        #expect(model.monthRows.map(\.open) == [1, 0])
        #expect(model.openCount == 3)
    }
}
