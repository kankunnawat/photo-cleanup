import Foundation

nonisolated struct NearbyDay: Identifiable, Sendable {
    /// The day's first moment in the calendar the days were built in.
    let start: Date
    /// Oldest first.
    let assets: [AssetInfo]

    var id: Date { start }
}

nonisolated enum Nearby {
    /// Days on each side of the center day.
    static let reach = 3

    /// The days from `reach` days before `date`'s day to `reach` days after it that hold any asset, oldest first.
    /// Undated assets have no day, so they are never in it.
    static func days(around date: Date, in assets: [AssetInfo], calendar: Calendar) -> [NearbyDay] {
        let center = calendar.startOfDay(for: date)
        guard let first = calendar.date(byAdding: .day, value: -reach, to: center),
              let end = calendar.date(byAdding: .day, value: reach + 1, to: center) else { return [] }
        var byDay: [Date: [AssetInfo]] = [:]
        for asset in assets {
            guard let created = asset.creationDate, created >= first, created < end else { continue }
            byDay[calendar.startOfDay(for: created), default: []].append(asset)
        }
        return byDay.keys.sorted().map { start in
            let assets = byDay[start, default: []].sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
            return NearbyDay(start: start, assets: assets)
        }
    }
}
