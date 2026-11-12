import CoreGraphics
import Testing
@testable import PhotoCleanup

struct DragMultiSelectTests {
    private let ids = ["a", "b", "c", "d", "e", "f"].map(AssetID.init)

    @Test func frameHitTestPicksTheContainingFrame() {
        let frames = [
            CGRect(x: 0, y: 0, width: 10, height: 10),
            CGRect(x: 0, y: 40, width: 10, height: 10),
            CGRect(x: 12, y: 40, width: 10, height: 10),
        ]

        #expect(DragMultiSelect.index(at: CGPoint(x: 5, y: 5), frames: frames) == 0)
        #expect(DragMultiSelect.index(at: CGPoint(x: 5, y: 25), frames: frames) == nil, "Gap for a section header")
        #expect(DragMultiSelect.index(at: CGPoint(x: 5, y: 45), frames: frames) == 1)
        #expect(DragMultiSelect.index(at: CGPoint(x: 15, y: 45), frames: frames) == 2)
    }

    @Test func startingOnAnUnselectedTileSelectsTheRange() {
        var session = DragMultiSelect.Session(anchor: 1, ids: ids, selected: [])

        #expect(session.paintsSelected)
        #expect(session.selection == [ids[1]])
        #expect(session.move(to: 4, ids: ids) == Set(ids[1...4]))
        #expect(session.move(to: 2, ids: ids) == Set(ids[1...2]), "Dragging back shrinks the range")
    }

    @Test func startingOnASelectedTileDeselectsTheRange() {
        var session = DragMultiSelect.Session(anchor: 2, ids: ids, selected: Set(ids[0...4]))

        #expect(!session.paintsSelected)
        #expect(session.move(to: 4, ids: ids) == Set(ids[0...1]))
        #expect(session.move(to: 0, ids: ids) == Set(ids[3...4]))
    }

    @Test func rangeLeavesTilesOutsideItAtTheirBaseline() {
        let outside = AssetID("elsewhere")
        var session = DragMultiSelect.Session(anchor: 3, ids: ids, selected: [ids[0], ids[5], outside])

        #expect(session.move(to: 4, ids: ids) == [ids[0], ids[3], ids[4], ids[5], outside])
    }

    @Test func aMissKeepsTheLastTileHit() {
        var session = DragMultiSelect.Session(anchor: 1, ids: ids, selected: [])
        _ = session.move(to: 4, ids: ids)

        #expect(session.move(to: nil, ids: ids) == Set(ids[1...4]), "A finger over a gutter fell back from the last tile")
        #expect(session.lastHit == 4, "Edge scroll would aim from the wrong tile")
    }

    @Test func aChangedListEndsTheDrag() {
        var session = DragMultiSelect.Session(anchor: 1, ids: ids, selected: [])
        let refreshed = [AssetID("new")] + ids

        #expect(session.move(to: 3, ids: refreshed) == nil, "Indices painted on the old list would select other assets")
    }

    @Test func autoScrollPointsAwayFromTheNearEdge() {
        #expect(DragMultiSelect.autoScrollDirection(pointerY: 10, viewportMinY: 0, viewportMaxY: 200) == .up)
        #expect(DragMultiSelect.autoScrollDirection(pointerY: 190, viewportMinY: 0, viewportMaxY: 200) == .down)
        #expect(DragMultiSelect.autoScrollDirection(pointerY: 100, viewportMinY: 0, viewportMaxY: 200) == nil)
        #expect(DragMultiSelect.autoScrollDirection(pointerY: 0, viewportMinY: 0, viewportMaxY: 0) == nil, "No viewport measured yet")
    }
}
