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

        let rows = Buckets.monthRows(groups, filter: .all, assetsByID: [:], pending: pending, protected: ProtectedSet(ids: [AssetID("d")]))

        #expect(rows.map(\.open) == [2, 0])
        #expect(rows.map(\.total) == [3, 1])
        #expect(rows.map(\.id) == groups.map(\.id))
    }

    @Test func monthRowsUnderAFilterCountOnlyThatKindAndSkipMonthsWithoutIt() {
        let assets = [
            Fixtures.photo("photo", Fixtures.date(2025, 2)),
            Fixtures.video("open-video", Fixtures.date(2025, 2)),
            Fixtures.video("queued-video", Fixtures.date(2025, 2)),
            AssetInfo(id: AssetID("other"), kind: .other, creationDate: Fixtures.date(2025, 2)),
            Fixtures.photo("only-photo", Fixtures.date(2025, 1)),
        ]
        let groups = MonthGrouping.groups(assets, calendar: Fixtures.calendar)
        let byID = Dictionary(uniqueKeysWithValues: assets.map { ($0.id, $0) })
        var pending = PendingDecisions()
        pending.set(.trash, for: AssetID("queued-video"))
        pending.set(.keep, for: AssetID("only-photo"))

        let rows = { (filter: MediaFilter) in
            Buckets.monthRows(groups, filter: filter, assetsByID: byID, pending: pending, protected: ProtectedSet())
        }

        #expect(rows(.all).map(\.id) == groups.map(\.id))
        #expect(rows(.all).map(\.open) == [3, 0])
        #expect(rows(.all).map(\.total) == [4, 1])
        #expect(rows(.videos).map(\.id) == [groups[0].id])
        #expect(rows(.videos).map(\.open) == [1])
        #expect(rows(.videos).map(\.total) == [2])
        // A month whose photos all have a decision keeps its row.
        #expect(rows(.photos).map(\.id) == groups.map(\.id))
        #expect(rows(.photos).map(\.open) == [1, 0])
        #expect(rows(.photos).map(\.total) == [1, 1])
    }
}
