import Foundation

/// A sort a screen can offer. Each screen offers some of these and picks its own default.
/// Screens sort only when they open or the user picks an order, so sizes measured later never move an item.
nonisolated enum AssetOrder: Hashable, Sendable {
    case oldestFirst, newestFirst, biggestFirst

    /// Undated assets count as the oldest. Biggest first puts unknown sizes last and breaks size ties oldest first.
    /// Assets still tied keep their incoming order, so the result is fully determined.
    func sorted(_ assets: [AssetInfo], sizes: SizeCache) -> [AssetInfo] {
        sorted(assets) { ($0.creationDate, sizes[$0.id]) }
    }

    /// The same order for IDs; an ID missing from `assetsByID` counts as undated.
    func sorted(_ ids: [AssetID], assetsByID: [AssetID: AssetInfo], sizes: SizeCache) -> [AssetID] {
        sorted(ids) { (assetsByID[$0]?.creationDate, sizes[$0]) }
    }

    private func sorted<Element>(_ elements: [Element], keys: (Element) -> (date: Date?, size: Int64?)) -> [Element] {
        let keyed = elements.enumerated().map { position, element in
            let key = keys(element)
            return (element: element, position: position, date: key.date ?? .distantPast, size: key.size ?? -1)
        }
        return keyed.sorted { a, b in
            switch self {
            case .oldestFirst:
                if a.date != b.date { return a.date < b.date }
            case .newestFirst:
                if a.date != b.date { return a.date > b.date }
            case .biggestFirst:
                if a.size != b.size { return a.size > b.size }
                if a.date != b.date { return a.date < b.date }
            }
            return a.position < b.position
        }
        .map { $0.element }
    }
}
