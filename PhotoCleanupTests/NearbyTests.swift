import Foundation
import Testing
@testable import PhotoCleanup

struct NearbyTests {
    let calendar = Fixtures.calendar

    private func at(_ month: Int, _ day: Int, _ hour: Int = 12, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2025, month: month, day: day, hour: hour, minute: minute))!
    }

    private func days(around date: Date, _ assets: [AssetInfo]) -> [[String]] {
        Nearby.days(around: date, in: assets, calendar: calendar).map { $0.assets.map(\.id.rawValue) }
    }

    @Test func holdsThreeDaysEachSideAndDropsTheFourth() {
        let assets = [
            Fixtures.photo("minus4", at(6, 11, 23, minute: 59)),
            Fixtures.photo("minus3", at(6, 12, 0)),
            Fixtures.photo("center", at(6, 15)),
            Fixtures.photo("plus3", at(6, 18, 23, minute: 59)),
            Fixtures.photo("plus4", at(6, 19, 0)),
        ]

        #expect(days(around: at(6, 15, 8), assets) == [["minus3"], ["center"], ["plus3"]])
    }

    @Test func crossesAMonthEnd() {
        let assets = [
            Fixtures.photo("apr25", at(4, 25)),
            Fixtures.photo("apr26", at(4, 26)),
            Fixtures.photo("apr29", at(4, 29)),
            Fixtures.photo("may2", at(5, 2)),
            Fixtures.photo("may3", at(5, 3)),
        ]

        let window = Nearby.days(around: at(4, 29), in: assets, calendar: calendar)

        #expect(window.map { $0.assets.map(\.id.rawValue) } == [["apr26"], ["apr29"], ["may2"]])
        #expect(window.map(\.start) == [at(4, 26, 0), at(4, 29, 0), at(5, 2, 0)])
    }

    @Test func leavesOutUndatedAssets() {
        let assets = [Fixtures.photo("undated", nil), Fixtures.photo("dated", at(6, 15))]

        #expect(days(around: at(6, 15), assets) == [["dated"]])
    }

    @Test func groupsByDayOldestFirstWhateverTheLibraryOrder() {
        let assets = [
            Fixtures.video("evening", at(6, 15, 20)),
            Fixtures.photo("nextDay", at(6, 16, 9)),
            Fixtures.photo("morning", at(6, 15, 7)),
            Fixtures.photo("dayBefore", at(6, 14, 22)),
            Fixtures.photo("noon", at(6, 15, 12)),
        ]

        #expect(days(around: at(6, 15), assets) == [["dayBefore"], ["morning", "noon", "evening"], ["nextDay"]])
    }

    @Test func usesTheGivenCalendarsTimeZone() {
        var bangkok = Calendar(identifier: .gregorian)
        bangkok.timeZone = TimeZone(identifier: "Asia/Bangkok")!
        // 20:00 UTC on June 18 is 03:00 on June 19 in Bangkok, the fourth day after June 15.
        let assets = [Fixtures.photo("late", at(6, 18, 20)), Fixtures.photo("center", at(6, 15))]

        #expect(days(around: at(6, 15), assets) == [["center"], ["late"]])
        #expect(Nearby.days(around: at(6, 15), in: assets, calendar: bangkok).map { $0.assets.map(\.id.rawValue) } == [["center"]])
    }
}
