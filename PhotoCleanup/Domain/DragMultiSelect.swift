import CoreGraphics
import Foundation

/// Hit-testing and range painting for a drag across a flat grid of tiles, as in Photos.
nonisolated struct DragMultiSelect: Sendable {
    enum ScrollDirection: Sendable, Equatable {
        case up, down
    }

    /// Index of the frame that contains `point`, or nil when the point misses every frame.
    static func index(at point: CGPoint, frames: [CGRect]) -> Int? {
        frames.firstIndex { $0.contains(point) }
    }

    /// The way to auto-scroll while the finger sits within `edge` of the viewport's top or bottom.
    static func autoScrollDirection(
        pointerY: CGFloat,
        viewportMinY: CGFloat,
        viewportMaxY: CGFloat,
        edge: CGFloat = 56
    ) -> ScrollDirection? {
        guard viewportMaxY > viewportMinY else { return nil }
        if pointerY < viewportMinY + edge { return .up }
        if pointerY > viewportMaxY - edge { return .down }
        return nil
    }

    /// One finger-drag that paints a contiguous range on or off.
    /// The tile under the finger at the start decides select vs deselect; dragging back shrinks the range.
    struct Session: Sendable, Equatable {
        let paintsSelected: Bool
        private let ids: [AssetID]
        private let anchor: Int
        private let baseline: Set<AssetID>
        private(set) var lastHit: Int

        init(anchor: Int, ids: [AssetID], selected: Set<AssetID>) {
            self.ids = ids
            self.anchor = anchor
            baseline = selected
            lastHit = anchor
            paintsSelected = !selected.contains(ids[anchor])
        }

        var selection: Set<AssetID> {
            let painted = ids[min(anchor, lastHit)...max(anchor, lastHit)]
            return paintsSelected ? baseline.union(painted) : baseline.subtracting(painted)
        }

        /// The selection with the finger over `index`, or nil when `ids` no longer match the list the drag began on.
        /// A nil `index` (gutter or section header) keeps the last tile hit.
        mutating func move(to index: Int?, ids: [AssetID]) -> Set<AssetID>? {
            // Indices painted so far would map to different assets after a library change.
            guard ids == self.ids else { return nil }
            if let index, ids.indices.contains(index) { lastHit = index }
            return selection
        }
    }
}
