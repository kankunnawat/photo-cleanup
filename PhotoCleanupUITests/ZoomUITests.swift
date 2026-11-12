import XCTest

/// Pinch and double-tap zoom in the viewer. Needs media from `scripts/seed-simulator.sh <udid>`. Deletes nothing.
///
/// XCUITest pinches only about the element's centre, and its pinch near scale 1 crashes the runner,
/// so the tests pinch by 2 and by 0.3 only.
@MainActor
final class ZoomUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testPinchZoomsAndPinchingBackReturnsToFitThenASwipePages() throws {
        let fit = try openViewer()
        let position = positionLabel.label

        pager.pinch(withScale: 2, velocity: 1)
        XCTAssertTrue(waitUntil { self.isZoomed(from: fit) }, "Pinch did not zoom: \(String(describing: photoFrame)) vs \(fit)")
        XCTAssertEqual(positionLabel.label, position, "Pinch paged")

        pager.pinch(withScale: 0.3, velocity: -1)
        XCTAssertTrue(waitUntil { self.isFit(fit) }, "Pinching back did not return to fit: \(String(describing: photoFrame)) vs \(fit)")
        pager.swipeLeft()
        XCTAssertTrue(waitUntil { self.positionLabel.label != position }, "A swipe after pinching back to fit did not page")
    }

    func testDoubleTapZoomsOnTheTapAndADragPansWithoutPaging() throws {
        let fit = try openViewer()
        let position = positionLabel.label
        let tap = CGPoint(x: centre.x - 40, y: centre.y + 40)

        point(tap).doubleTap()
        XCTAssertTrue(waitUntil { self.isZoomed(from: fit) }, "Double-tap did not zoom")
        settle()
        let zoomed = try XCTUnwrap(photoFrame)
        let zoom = zoomed.width / fit.width
        // The tapped point of the photo moves to the middle of the page.
        XCTAssertEqual(zoomed.minX + (tap.x - fit.minX) * zoom, centre.x, accuracy: 2, "Tapped point not centred horizontally: \(zoomed)")
        XCTAssertEqual(zoomed.minY + (tap.y - fit.minY) * zoom, centre.y, accuracy: 2, "Tapped point not centred vertically: \(zoomed)")

        point(centre).press(forDuration: 0.05, thenDragTo: point(CGPoint(x: centre.x + 60, y: centre.y + 30)), withVelocity: .slow, thenHoldForDuration: 0.2)
        settle()
        let panned = try XCTUnwrap(photoFrame)
        // A scroll view drops a few points of slop at the start of a pan.
        XCTAssertTrue((40...65).contains(panned.minX - zoomed.minX), "Drag did not pan right: \(zoomed) -> \(panned)")
        XCTAssertTrue((15...35).contains(panned.minY - zoomed.minY), "Drag did not pan down: \(zoomed) -> \(panned)")
        XCTAssertEqual(panned.width, zoomed.width, accuracy: 1, "Drag changed the zoom")
        XCTAssertEqual(positionLabel.label, position, "Drag while zoomed paged")
    }

    func testSwipesWhileZoomedReachTheEdgeThenPageAndPagingBackShowsFit() throws {
        let fit = try openViewer()
        let position = positionLabel.label
        point(centre).doubleTap()
        XCTAssertTrue(waitUntil { self.isZoomed(from: fit) }, "Double-tap did not zoom")
        settle()

        pager.swipeLeft()
        settle()
        XCTAssertEqual(positionLabel.label, position, "The first swipe while zoomed paged instead of panning")
        let atEdge = try XCTUnwrap(photoFrame)
        XCTAssertEqual(atEdge.maxX, pager.frame.maxX, accuracy: 1, "The first swipe did not reach the photo's right edge: \(atEdge)")

        var swipes = 0
        while swipes < 3, positionLabel.label == position {
            pager.swipeLeft()
            swipes += 1
            settle()
        }
        XCTAssertNotEqual(positionLabel.label, position, "Swipes at the zoomed edge never paged")

        pager.swipeRight()
        XCTAssertTrue(waitUntil { self.positionLabel.label == position }, "Did not page back")
        XCTAssertTrue(waitUntil { self.isFit(fit) }, "The photo was still zoomed after paging away and back: \(String(describing: photoFrame)) vs \(fit)")
    }

    func testCloseWorksWhileZoomed() throws {
        let fit = try openViewer()
        point(centre).doubleTap()
        XCTAssertTrue(waitUntil { self.isZoomed(from: fit) }, "Double-tap did not zoom")

        app.buttons["preview.close"].tap()
        XCTAssertTrue(waitUntil { !self.app.buttons["preview.close"].exists }, "Close did not close the viewer while zoomed")
    }

    // MARK: - Helpers

    private var pager: XCUIElement { app.descendants(matching: .any)["preview.pager"] }

    private var centre: CGPoint { CGPoint(x: pager.frame.midX, y: pager.frame.midY) }

    private var positionLabel: XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^[0-9,]+ of [0-9,]+$")).firstMatch
    }

    /// The frame of the photo on screen. Neighbouring pages stay loaded, so this is the one under the page's centre.
    private var photoFrame: CGRect? {
        let centre = centre
        return app.images.matching(identifier: "preview.photo").allElementsBoundByIndex
            .map(\.frame)
            .first { $0.contains(centre) }
    }

    private func isZoomed(from fit: CGRect) -> Bool {
        guard let frame = photoFrame else { return false }
        return frame.width > fit.width * 1.5 && frame.height > fit.height * 1.5
    }

    /// Back at the fit frame; at 1.02x the photo would be 8 pt wider.
    private func isFit(_ fit: CGRect) -> Bool {
        guard let frame = photoFrame else { return false }
        return abs(frame.minX - fit.minX) <= 1 && abs(frame.minY - fit.minY) <= 1
            && abs(frame.width - fit.width) <= 1 && abs(frame.height - fit.height) <= 1
    }

    /// A screen point, as a coordinate the test can tap or drag from.
    private func point(_ screen: CGPoint) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: screen.x, dy: screen.y))
    }

    /// Lets zoom and paging animations finish.
    private func settle() {
        _ = XCTWaiter().wait(for: [XCTestExpectation(description: "settle")], timeout: 0.8)
    }

    /// Opens the viewer on the biggest Free up photo and returns its frame at fit.
    private func openViewer() throws -> CGRect {
        app.launchToHome()
        app.buttons["mode.freeUp"].tap()
        let tile = app.descendants(matching: .any).matching(identifier: "freeUp.tile").firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 10), "Free up showed no photos; seed the simulator")
        XCTAssertTrue(app.staticTexts["up to"].waitForExistence(timeout: 30), "Sizes were still being measured")
        app.buttons["freeUp.sort"].tap()
        app.buttons["Biggest first"].tap()
        settle()
        tile.press(forDuration: 1)
        XCTAssertTrue(app.buttons["preview.close"].waitForExistence(timeout: 10), "Touch and hold did not open the viewer")
        XCTAssertTrue(waitUntil { self.photoFrame != nil }, "The photo never showed")
        settle()
        let fit = try XCTUnwrap(photoFrame)
        XCTAssertEqual(fit.width, pager.frame.width, accuracy: 1, "A portrait seed photo should fill the page's width at fit: \(fit)")
        return fit
    }
}
