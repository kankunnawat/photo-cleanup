import Foundation

nonisolated struct MonthKey: Hashable, Comparable, Sendable {
    let year: Int
    let month: Int

    static func < (lhs: MonthKey, rhs: MonthKey) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }

    func firstDay(in calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: 1))
    }
}

nonisolated struct MonthGroup: Identifiable, Hashable, Sendable {
    /// `nil` holds assets without a creation date.
    let key: MonthKey?
    /// Newest first.
    let assetIDs: [AssetID]

    var id: String {
        key.map { "\($0.year)-\($0.month)" } ?? "undated"
    }
}

nonisolated enum MonthGrouping {
    /// Months newest first, undated assets last.
    static func groups(_ assets: [AssetInfo], calendar: Calendar) -> [MonthGroup] {
        var dated: [MonthKey: [AssetInfo]] = [:]
        var undated: [AssetID] = []
        for asset in assets {
            guard let date = asset.creationDate else {
                undated.append(asset.id)
                continue
            }
            let parts = calendar.dateComponents([.year, .month], from: date)
            guard let year = parts.year, let month = parts.month else {
                undated.append(asset.id)
                continue
            }
            dated[MonthKey(year: year, month: month), default: []].append(asset)
        }
        var groups = dated.keys.sorted(by: >).map { key in
            let ids = dated[key, default: []]
                .sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
                .map(\.id)
            return MonthGroup(key: key, assetIDs: ids)
        }
        if !undated.isEmpty {
            groups.append(MonthGroup(key: nil, assetIDs: undated))
        }
        return groups
    }
}
