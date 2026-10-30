/// One section of the Apply grid, fixed when the screen opens so tiles never move under the user's taps.
/// Each tile holds the section's decision, the opposite one after a tap, or none once taken back.
nonisolated struct ApplySection: Sendable {
    /// Display order. Tiles leave only through `dropTiles(disagreeingWith:)`; the rest never move.
    private(set) var ids: [AssetID]
    let decision: Decision
    private var members: Set<AssetID>
    private var switched: Set<AssetID> = []
    private var takenBack: Set<AssetID> = []

    init(ids: [AssetID], decision: Decision) {
        self.ids = ids
        self.decision = decision
        members = Set(ids)
    }

    func contains(_ id: AssetID) -> Bool {
        members.contains(id)
    }

    /// Nil means taken back, or not a tile of this section.
    func decision(for id: AssetID) -> Decision? {
        guard members.contains(id), !takenBack.contains(id) else { return nil }
        return switched.contains(id) ? decision.opposite : decision
    }

    /// Switches between keep and delete; a taken-back tile gets the section's decision again.
    /// Returns the tile's new decision, or nil for an ID that is not a tile.
    @discardableResult
    mutating func tap(_ id: AssetID) -> Decision? {
        guard members.contains(id) else { return nil }
        if takenBack.remove(id) != nil { return decision }
        if switched.remove(id) != nil { return decision }
        switched.insert(id)
        return decision.opposite
    }

    mutating func takeBackAll() {
        switched = []
        takenBack = members
    }

    mutating func restoreAll() {
        switched = []
        takenBack = []
    }

    /// Drops every tile whose decision no longer matches `pending`. That happens only when pending
    /// changed outside this screen (an album add clearing a delete); tiles the user switched, took back
    /// or left alone still match, so they stay where they are.
    mutating func dropTiles(disagreeingWith pending: PendingDecisions) {
        let dropped = Set(ids.filter { decision(for: $0) != pending.decision(for: $0) })
        guard !dropped.isEmpty else { return }
        ids.removeAll(where: dropped.contains)
        members.subtract(dropped)
        switched.subtract(dropped)
        takenBack.subtract(dropped)
    }

    /// False once every tile is taken back.
    var hasDecisions: Bool { takenBack.count < ids.count }

    func count(of decision: Decision) -> Int {
        decision == self.decision ? ids.count - switched.count - takenBack.count : switched.count
    }
}
