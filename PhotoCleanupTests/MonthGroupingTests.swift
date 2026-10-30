import Testing
@testable import PhotoCleanup

struct MonthGroupingTests {
    @Test func groupsByMonthNewestFirstWithUndatedLast() {
        let assets = [
            Fixtures.photo("jan-early", Fixtures.date(2025, 1, 2)),
            Fixtures.photo("undated", nil),
            Fixtures.photo("mar", Fixtures.date(2025, 3)),
            Fixtures.photo("jan-late", Fixtures.date(2025, 1, 28)),
            Fixtures.photo("dec", Fixtures.date(2024, 12)),
        ]

        let groups = MonthGrouping.groups(assets, calendar: Fixtures.calendar)

        #expect(groups.map(\.key) == [
            MonthKey(year: 2025, month: 3),
            MonthKey(year: 2025, month: 1),
            MonthKey(year: 2024, month: 12),
            nil,
        ])
        #expect(groups[1].assetIDs == [AssetID("jan-late"), AssetID("jan-early")])
        #expect(groups[3].assetIDs == [AssetID("undated")])
    }

    @Test func noUndatedGroupWhenEveryAssetHasADate() {
        let groups = MonthGrouping.groups([Fixtures.photo("a", Fixtures.date(2025, 5))], calendar: Fixtures.calendar)

        #expect(groups.count == 1)
        #expect(groups[0].key != nil)
    }

    @Test func deckShowsOnlyUndecidedUnprotectedAssets() {
        let ids = ["a", "b", "c", "d"].map(AssetID.init)
        var pending = PendingDecisions()
        pending.set(.keep, for: ids[0])
        pending.set(.trash, for: ids[1])

        let deck = Buckets.reviewDeck(ids, pending: pending, protected: ProtectedSet(ids: [ids[2]]))

        #expect(deck == [ids[3]])
    }

    @Test func monthRowsCountOnlyOpenAssets() {
        let groups = [
            MonthGroup(key: MonthKey(year: 2025, month: 2), assetIDs: ["a", "b", "c"].map(AssetID.init)),
            MonthGroup(key: MonthKey(year: 2025, month: 1), assetIDs: [AssetID("d")]),
        ]
        var pending = PendingDecisions()
        pending.set(.trash, for: AssetID("a"))

        let rows = Buckets.monthRows(groups, pending: pending, protected: ProtectedSet(ids: [AssetID("d")]))

        #expect(rows.map(\.open) == [2, 0])
        #expect(rows.map(\.id) == groups.map(\.id))
    }
}
