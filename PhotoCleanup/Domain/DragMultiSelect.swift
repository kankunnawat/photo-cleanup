import CoreGraphics
import Foundation

/// Hit-testing and range painting for a drag across a flat grid of tiles, as in Photos.
nonisolated struct DragMultiSelect: Sendable {
    /// Index of the cell that contains `point` in a uniform grid with square cells.
    /// `point` is relative to the top-leading corner of the first cell.
    /// Points that land in the spacing gutters miss.
    static func index(
        at point: CGPoint,
        itemCount: Int,
        columns: Int,
        cellSide: CGFloat,
        spacing: CGFloat
    ) -> Int? {
        guard itemCount > 0, columns > 0, cellSide > 0, spacing >= 0 else { return nil }
        guard point.x >= 0, point.y >= 0 else { return nil }
        let stride = cellSide + spacing
        let column = Int((point.x / stride).rounded(.down))
        let row = Int((point.y / stride).rounded(.down))
        guard column >= 0, column < columns, row >= 0 else { return nil }
        let xInCell = point.x - CGFloat(column) * stride
        let yInCell = point.y - CGFloat(row) * stride
        guard xInCell <= cellSide, yInCell <= cellSide else { return nil }
        let index = row * columns + column
        guard index < itemCount else { return nil }
        return index
    }

    /// Index of the frame that contains `point`, or nil when the point misses every frame.
    static func index(at point: CGPoint, frames: [CGRect]) -> Int? {
        frames.firstIndex { $0.contains(point) }
    }

    /// Contiguous indices from `anchor` through `current`, inclusive, clamped to `0..<itemCount`.
    static func range(from anchor: Int, to current: Int, itemCount: Int) -> ClosedRange<Int>? {
        guard itemCount > 0 else { return nil }
        let lo = min(anchor, current)
        let hi = max(anchor, current)
        guard hi >= 0, lo < itemCount else { return nil }
        return max(lo, 0)...min(hi, itemCount - 1)
    }

    /// Vertical content offset change for edge auto-scroll.
    /// Negative moves content down (finger near the top of the viewport); positive the other way.
    static func autoScrollDelta(
        pointerY: CGFloat,
        viewportMinY: CGFloat,
        viewportMaxY: CGFloat,
        edge: CGFloat = 56,
        speed: CGFloat = 24
    ) -> CGFloat {
        guard viewportMaxY > viewportMinY, edge > 0, speed > 0 else { return 0 }
        if pointerY < viewportMinY + edge { return -speed }
        if pointerY > viewportMaxY - edge { return speed }
        return 0
    }

    /// One finger-drag that paints a contiguous index range on or off.
    /// The tile under the finger at the start decides select vs deselect; dragging back shrinks the range.
    struct Session: Sendable, Equatable {
        /// True when the drag selects; false when it deselects.
        let paintsSelected: Bool
        /// Index where the finger went down.
        let anchor: Int
        /// Selected indices as they were before the drag began.
        private let baseline: Set<Int>

        init(anchor: Int, selected: Set<Int>) {
            self.anchor = anchor
            baseline = selected
            paintsSelected = !selected.contains(anchor)
        }

        /// Selected indices if the finger is over `current`.
        func selection(current: Int, itemCount: Int) -> Set<Int> {
            var result = baseline
            guard let painted = DragMultiSelect.range(from: anchor, to: current, itemCount: itemCount) else {
                return result
            }
            for index in painted {
                if paintsSelected {
                    result.insert(index)
                } else {
                    result.remove(index)
                }
            }
            return result
        }

        /// `ids` membership for the selection at `current`, in list order.
        func selectedIDs(current: Int, ids: [AssetID]) -> Set<AssetID> {
            Set(selection(current: current, itemCount: ids.count).map { ids[$0] })
        }
    }
}
