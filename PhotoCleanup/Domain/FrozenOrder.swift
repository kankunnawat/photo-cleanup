/// A list order fixed when a screen opens or the user picks a sort, so sizes measured later never move an item.
nonisolated struct FrozenOrder: Sendable {
    private let ids: [AssetID]
    private let members: Set<AssetID>

    init(_ ids: [AssetID]) {
        self.ids = ids
        members = Set(ids)
    }

    /// `items` in the frozen order. Items no longer in `items` drop out; items the order has not seen go last, in their own order.
    func arrange(_ items: [AssetInfo]) -> [AssetInfo] {
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { byID[$0] } + items.filter { !members.contains($0.id) }
    }
}
