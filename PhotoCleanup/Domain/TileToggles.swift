/// Grid tiles fixed when a screen opens. Tapping flips a tile in place, so no tile moves under the finger.
nonisolated struct TileToggles: Sendable {
    /// Display order; never changes after creation.
    let ids: [AssetID]
    private let members: Set<AssetID>
    private(set) var flipped: Set<AssetID>

    /// Flipped IDs that are not in `ids` are dropped.
    init(ids: [AssetID], flipped: Set<AssetID> = []) {
        self.ids = ids
        members = Set(ids)
        self.flipped = flipped.intersection(members)
    }

    func isFlipped(_ id: AssetID) -> Bool {
        flipped.contains(id)
    }

    /// Returns whether the tile is flipped afterwards. IDs that are not tiles are ignored.
    @discardableResult
    mutating func toggle(_ id: AssetID) -> Bool {
        guard members.contains(id) else { return false }
        if flipped.remove(id) != nil { return false }
        flipped.insert(id)
        return true
    }

    var unflipped: [AssetID] { ids.filter { !flipped.contains($0) } }
    var flippedInOrder: [AssetID] { ids.filter { flipped.contains($0) } }
    var unflippedCount: Int { ids.count - flipped.count }
}
