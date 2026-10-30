import Testing
@testable import PhotoCleanup

struct AssetOrderTests {
    let assets = [
        Fixtures.photo("mid", Fixtures.date(2025, 2)),
        Fixtures.photo("undated", nil),
        Fixtures.photo("new", Fixtures.date(2025, 3)),
        Fixtures.photo("old", Fixtures.date(2025, 1)),
    ]

    private func names(_ order: AssetOrder, _ assets: [AssetInfo], sizes: SizeCache = SizeCache()) -> [String] {
        order.sorted(assets, sizes: sizes).map(\.id.rawValue)
    }

    @Test func dateOrdersCountUndatedAsTheOldest() {
        #expect(names(.oldestFirst, assets) == ["undated", "old", "mid", "new"])
        #expect(names(.newestFirst, assets) == ["new", "mid", "old", "undated"])
    }

    @Test(arguments: [AssetOrder.oldestFirst, .newestFirst])
    func sameDateKeepsTheIncomingOrder(order: AssetOrder) {
        let twins = [
            Fixtures.photo("second", Fixtures.date(2025, 1)),
            Fixtures.photo("first", Fixtures.date(2025, 1)),
            Fixtures.photo("third", Fixtures.date(2025, 1)),
        ]

        #expect(names(order, twins) == ["second", "first", "third"])
    }

    @Test func biggestFirstPutsUnknownSizesLast() {
        let sizes = SizeCache(bytes: [AssetID("old"): 10, AssetID("new"): 500])

        #expect(names(.biggestFirst, assets, sizes: sizes) == ["new", "old", "undated", "mid"])
    }

    @Test func biggestFirstBreaksSizeTiesOldestFirstThenByIncomingOrder() {
        let tied = [
            Fixtures.photo("new", Fixtures.date(2025, 3)),
            Fixtures.photo("same-day-b", Fixtures.date(2025, 1)),
            Fixtures.photo("same-day-a", Fixtures.date(2025, 1)),
            Fixtures.photo("big", Fixtures.date(2025, 6)),
        ]
        let sizes = SizeCache(bytes: [
            AssetID("new"): 70,
            AssetID("same-day-b"): 70,
            AssetID("same-day-a"): 70,
            AssetID("big"): 900,
        ])

        #expect(names(.biggestFirst, tied, sizes: sizes) == ["big", "same-day-b", "same-day-a", "new"])
    }

    @Test func idsMissingFromTheLibraryCountAsUndated() {
        let byID = Dictionary(uniqueKeysWithValues: assets.map { ($0.id, $0) })
        let ids = [AssetID("gone"), AssetID("old"), AssetID("new")]
        let sizes = SizeCache(bytes: [AssetID("gone"): 900, AssetID("old"): 10])

        #expect(AssetOrder.oldestFirst.sorted(ids, assetsByID: byID, sizes: sizes) == [AssetID("gone"), AssetID("old"), AssetID("new")])
        #expect(AssetOrder.newestFirst.sorted(ids, assetsByID: byID, sizes: sizes) == [AssetID("new"), AssetID("old"), AssetID("gone")])
        #expect(AssetOrder.biggestFirst.sorted(ids, assetsByID: byID, sizes: sizes) == [AssetID("gone"), AssetID("old"), AssetID("new")])
    }
}
