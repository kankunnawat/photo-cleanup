import XCTest

/// Needs seeded media whose newest month holds at least two open items, newest a photo and a bigger video:
/// run `scripts/seed-simulator.sh <udid>` first. Leaves no pending decision behind.
@MainActor
final class SwipeReviewUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testBiggestFirstPutsTheBiggestCardOnTop() throws {
        let deck = try openNewestMonth()
        let newestFirstTop = deck.top.label
        let count = deck.remaining.label

        sort("Biggest first")

        XCTAssertTrue(waitUntil { deck.top.label != newestFirstTop }, "Biggest first did not change the top card")
        XCTAssertEqual(deck.remaining.label, count, "Sorting changed the number of cards")
        let topBytes = try bytes(in: deck.top.label)
        for card in app.descendants(matching: .any).matching(identifier: "deck.card.behind").allElementsBoundByIndex {
            XCTAssertGreaterThanOrEqual(topBytes, try bytes(in: card.label), "A card behind the top one is bigger: \(card.label)")
        }

        leaveExpectingNoPendingDecisions()
    }

    func testUndoAfterASortBringsTheCardBack() throws {
        let deck = try openNewestMonth()
        let swiped = deck.top.label
        let count = deck.remaining.label

        deck.top.swipeLeft()
        XCTAssertTrue(waitUntil { deck.remaining.label != count }, "Left swipe did not decide the card")
        sort("Biggest first")
        app.buttons["deck.undo"].tap()
        XCTAssertTrue(waitUntil { deck.remaining.label == count }, "Undo after a sort did not bring the card back")
        XCTAssertTrue(waitUntil { deck.top.label == swiped }, "The undone card is not on top: \(deck.top.label)")
        XCTAssertFalse(app.buttons["deck.done"].isEnabled, "Undo left a pending decision")

        leaveExpectingNoPendingDecisions()
    }

    func testVideosFilterChangesTheMonthCountsButNotHomes() throws {
        app.launchToHome()
        let swipeTile = app.buttons["mode.swipe"]
        let homeSummary = swipeTile.label
        swipeTile.tap()
        let rows = app.buttons.matching(identifier: "months.row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10), "Swipe review showed no months; seed the simulator")
        let allLabels = rows.allElementsBoundByIndex.map(\.label)
        let kind = app.segmentedControls["months.kind"]

        kind.buttons["Videos"].tap()
        XCTAssertTrue(waitUntil { rows.allElementsBoundByIndex.map(\.label) != allLabels }, "Videos did not change the month counts")

        app.navigationBars.buttons["BackButton"].tap()
        XCTAssertTrue(waitUntil { swipeTile.exists && swipeTile.label == homeSummary }, "Home's count followed the filter: \(swipeTile.label)")
        XCTAssertFalse(app.buttons["home.pendingBar"].exists, "The filter left a pending decision")

        swipeTile.tap()
        XCTAssertTrue(kind.buttons["Videos"].waitForExistence(timeout: 10))
        XCTAssertTrue(kind.buttons["Videos"].isSelected, "Swipe review forgot the filter")
        kind.buttons["All"].tap()
        XCTAssertTrue(waitUntil { rows.allElementsBoundByIndex.map(\.label) == allLabels }, "All did not bring the counts back")
    }

    /// Opens the newest month once sizes are measured, so a size sort sees every size and each card shows one.
    private func openNewestMonth() throws -> (top: XCUIElement, remaining: XCUIElement) {
        app.launchToHome()
        XCTAssertTrue(app.staticTexts["up to, on device"].waitForExistence(timeout: 30), "Sizes were still being measured")
        app.buttons["mode.swipe"].tap()
        let row = app.buttons.matching(identifier: "months.row").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Swipe review showed no months; seed the simulator")
        XCTAssertTrue(row.isEnabled, "The newest month has nothing left to review")
        row.tap()

        let top = app.descendants(matching: .any).matching(identifier: "deck.card").firstMatch
        let remaining = app.staticTexts.matching(identifier: "deck.remaining").firstMatch
        XCTAssertTrue(top.waitForExistence(timeout: 10), "The month deck showed no card")
        XCTAssertTrue(waitUntil { (try? self.bytes(in: top.label)) != nil }, "The top card showed no size: \(top.label)")
        let left = try XCTUnwrap(remaining.label.firstMatch(of: /(\d+) left/).flatMap { Int($0.1) }, "Unexpected count: \(remaining.label)")
        XCTAssertGreaterThanOrEqual(left, 2, "The newest month needs two open items")
        return (top, remaining)
    }

    private func sort(_ order: String) {
        app.buttons["deck.sort"].tap()
        app.buttons[order].tap()
    }

    /// Reads the size a card shows, such as "23.8 MB".
    private func bytes(in label: String) throws -> Double {
        let match = try XCTUnwrap(label.firstMatch(of: /([0-9.]+) (bytes|KB|MB|GB)/), "No size in \(label)")
        let unit: Double = switch match.2 {
        case "KB": 1e3
        case "MB": 1e6
        case "GB": 1e9
        default: 1
        }
        return try XCTUnwrap(Double(match.1)) * unit
    }

    private func leaveExpectingNoPendingDecisions() {
        app.navigationBars.buttons["BackButton"].tap()
        app.navigationBars.buttons["BackButton"].tap()
        XCTAssertTrue(app.staticTexts["home.libraryCount"].waitForExistence(timeout: 10), "Back did not return to Home")
        XCTAssertFalse(app.buttons["home.pendingBar"].exists, "The deck left a pending decision")
    }
}
