import CoreGraphics
import Testing
@testable import PhotoCleanup

struct DragMultiSelectTests {
    private let side: CGFloat = 10
    private let spacing: CGFloat = 2

    /// 3×3 cells of 10 pt with 2 pt gaps. Cell (col, row) occupies [col*12, col*12+10] × [row*12, row*12+10].
    private func index(at x: CGFloat, _ y: CGFloat, count: Int = 9, columns: Int = 3) -> Int? {
        DragMultiSelect.index(
            at: CGPoint(x: x, y: y),
            itemCount: count,
            columns: columns,
            cellSide: side,
            spacing: spacing
        )
    }

    @Test func uniformHitTestFindsEachCellAndMissesGutters() {
        #expect(index(at: 0, 0) == 0)
        #expect(index(at: 9.9, 9.9) == 0)
        #expect(index(at: 12, 0) == 1)
        #expect(index(at: 24, 0) == 2)
        #expect(index(at: 0, 12) == 3)
        #expect(index(at: 24, 24) == 8)

        #expect(index(at: 10.5, 0) == nil, "Horizontal gutter")
        #expect(index(at: 0, 10.5) == nil, "Vertical gutter")
        #expect(index(at: -1, 0) == nil)
        #expect(index(at: 0, 36) == nil, "Past the last row")
        #expect(index(at: 36, 0) == nil, "Past the last column")
    }

    @Test func uniformHitTestIgnoresCellsPastItemCount() {
        // Two items in a 3-column grid: only (0,0) and (1,0) exist.
        #expect(index(at: 0, 0, count: 2) == 0)
        #expect(index(at: 12, 0, count: 2) == 1)
        #expect(index(at: 24, 0, count: 2) == nil)
        #expect(index(at: 0, 12, count: 2) == nil)
    }

    @Test func frameHitTestPicksTheContainingFrame() {
        let frames = [
            CGRect(x: 0, y: 0, width: 10, height: 10),
            CGRect(x: 0, y: 40, width: 10, height: 10), // gap for a section header
            CGRect(x: 12, y: 40, width: 10, height: 10),
        ]

        #expect(DragMultiSelect.index(at: CGPoint(x: 5, y: 5), frames: frames) == 0)
        #expect(DragMultiSelect.index(at: CGPoint(x: 5, y: 25), frames: frames) == nil)
        #expect(DragMultiSelect.index(at: CGPoint(x: 5, y: 45), frames: frames) == 1)
        #expect(DragMultiSelect.index(at: CGPoint(x: 15, y: 45), frames: frames) == 2)
    }

    @Test func startingOnAnUnselectedTileSelectsTheRange() {
        let session = DragMultiSelect.Session(anchor: 1, selected: [])

        #expect(session.paintsSelected)
        #expect(session.selection(current: 1, itemCount: 6) == [1])
        #expect(session.selection(current: 4, itemCount: 6) == [1, 2, 3, 4])
        #expect(session.selection(current: 2, itemCount: 6) == [1, 2], "Dragging back shrinks the range")
    }

    @Test func startingOnASelectedTileDeselectsTheRange() {
        let session = DragMultiSelect.Session(anchor: 2, selected: [0, 1, 2, 3, 4])

        #expect(!session.paintsSelected)
        #expect(session.selection(current: 4, itemCount: 6) == [0, 1])
        #expect(session.selection(current: 0, itemCount: 6) == [3, 4])
    }

    @Test func rangeLeavesTilesOutsideItAtTheirBaseline() {
        let session = DragMultiSelect.Session(anchor: 3, selected: [0, 5])

        #expect(session.selection(current: 4, itemCount: 6) == [0, 3, 4, 5])
    }

    @Test func selectedIDsFollowThePaintedIndices() {
        let ids = ["a", "b", "c", "d"].map(AssetID.init)
        let session = DragMultiSelect.Session(anchor: 0, selected: [])

        #expect(session.selectedIDs(current: 2, ids: ids) == [ids[0], ids[1], ids[2]])
    }

    @Test func autoScrollDeltaPushesAwayFromTheNearEdge() {
        #expect(DragMultiSelect.autoScrollDelta(pointerY: 10, viewportMinY: 0, viewportMaxY: 200) < 0)
        #expect(DragMultiSelect.autoScrollDelta(pointerY: 190, viewportMinY: 0, viewportMaxY: 200) > 0)
        #expect(DragMultiSelect.autoScrollDelta(pointerY: 100, viewportMinY: 0, viewportMaxY: 200) == 0)
    }

    @Test func rangeClampsToTheItemCount() {
        #expect(DragMultiSelect.range(from: 0, to: 99, itemCount: 4) == 0...3)
        #expect(DragMultiSelect.range(from: -2, to: 1, itemCount: 4) == 0...1)
        #expect(DragMultiSelect.range(from: 0, to: 0, itemCount: 0) == nil)
    }
}
