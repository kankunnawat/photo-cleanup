/// The cards of one swipe deck, dealt when it opens: the open assets of the filter's kinds.
/// Deciding a card keeps it in `queue`, so the deck's Undo can bring it back, and a sort only reorders the queue.
nonisolated struct SwipeDeck: Sendable {
    let filter: MediaFilter
    /// Every dealt card, decided or not, in the order they show.
    private(set) var queue: [AssetID]
    /// The order the cards were dealt in, which a sort with no order puts back.
    private let dealt: [AssetID]

    init(
        dealing ids: [AssetID],
        filter: MediaFilter,
        assetsByID: [AssetID: AssetInfo],
        pending: PendingDecisions,
        protected: ProtectedSet
    ) {
        self.filter = filter
        dealt = Buckets.reviewDeck(Buckets.matching(ids, filter, assetsByID: assetsByID), pending: pending, protected: protected)
        queue = dealt
    }

    /// The cards still to decide, in display order.
    func open(pending: PendingDecisions, protected: ProtectedSet, assetsByID: [AssetID: AssetInfo]) -> [AssetID] {
        Buckets.reviewDeck(queue, pending: pending, protected: protected).filter { assetsByID[$0] != nil }
    }

    /// Reorders the dealt cards without adding or dropping one. Nil puts back the order they were dealt in.
    mutating func sort(_ order: AssetOrder?, assetsByID: [AssetID: AssetInfo], sizes: SizeCache) {
        queue = order?.sorted(dealt, assetsByID: assetsByID, sizes: sizes) ?? dealt
    }
}
