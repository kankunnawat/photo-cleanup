import XCTest

/// Needs seeded media: run `scripts/seed-simulator.sh <udid>` first.
@MainActor
final class SwipeAndApplyUITests: XCTestCase {
    private let app = XCUIApplication()
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testSwipeOneEachWayThenApplyDeletesOneAndKeepsOne() throws {
        app.launchToHome()

        let libraryCount = app.staticTexts["home.libraryCount"]
        let keepCount = app.staticTexts["home.keepCount"]
        let libraryBefore = try number(libraryCount)
        let keepBefore = try number(keepCount)
        XCTAssertGreaterThanOrEqual(libraryBefore, 2, "Seed the simulator with scripts/seed-simulator.sh")

        app.buttons["mode.swipe"].tap()
        app.buttons["deck.shuffle"].tap()

        let card = app.descendants(matching: .any).matching(identifier: "deck.card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.swipeLeft()
        let done = app.buttons["deck.done"]
        XCTAssertTrue(waitUntil { done.isEnabled }, "Left swipe did not queue a delete")
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.swipeRight()

        done.tap()
        XCTAssertTrue(app.descendants(matching: .any)["apply.keepSection"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["apply.keepSection"].label.contains("Keep (1)"))
        XCTAssertTrue(app.descendants(matching: .any)["apply.deleteSection"].label.contains("Delete (1)"))

        app.buttons["apply.run"].tap()
        let confirmDelete = springboard.alerts.buttons["Delete"]
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 15), "System delete confirmation did not appear")
        confirmDelete.tap()

        let result = app.descendants(matching: .any)["apply.result"]
        XCTAssertTrue(result.waitForExistence(timeout: 15))
        XCTAssertTrue(result.label.hasPrefix("Deleted 1 item,"), "Unexpected result: \(result.label)")

        app.buttons["apply.home"].tap()
        XCTAssertTrue(waitUntil { (try? self.number(libraryCount)) == libraryBefore - 1 }, "Library did not shrink by one")
        XCTAssertTrue(waitUntil { (try? self.number(keepCount)) == keepBefore + 1 }, "Keep album did not gain the kept photo")
    }

    func testSwitchADeleteToKeepFromThePreview() throws {
        app.launchToHome()

        let libraryCount = app.staticTexts["home.libraryCount"]
        let libraryBefore = try number(libraryCount)

        queueOneDeleteAndOpenApply()

        let keepSection = app.descendants(matching: .any)["apply.keepSection"]
        let deleteSection = app.descendants(matching: .any)["apply.deleteSection"]
        XCTAssertTrue(deleteSection.waitForExistence(timeout: 10))
        let tile = app.descendants(matching: .any).matching(identifier: "apply.tile").firstMatch
        tile.press(forDuration: 1)

        let status = app.staticTexts["preview.status"]
        XCTAssertTrue(status.waitForExistence(timeout: 10), "Touch and hold did not open the preview")
        XCTAssertEqual(status.label, "Will be deleted")
        let action = app.buttons["preview.action"]
        XCTAssertEqual(action.label, "Keep")
        action.tap()
        XCTAssertTrue(waitUntil { status.label == "Will be kept" }, "Status did not update in place: \(status.label)")

        app.buttons["preview.close"].tap()
        XCTAssertTrue(waitUntil { tile.value as? String == "Keep" }, "Tile did not match the preview")
        XCTAssertTrue(keepSection.label.contains("Keep (1)"), "Unexpected section: \(keepSection.label)")
        XCTAssertTrue(deleteSection.label.contains("Delete (0)"), "Unexpected section: \(deleteSection.label)")

        app.buttons["apply.home"].tap()
        expectPending("1 to keep, 0 to delete")
        XCTAssertTrue(waitUntil { (try? self.number(libraryCount)) == libraryBefore }, "Library changed")
    }

    func testTapSwitchesADeleteAndTakeBackAllClearsTheSection() throws {
        app.launchToHome()

        let libraryCount = app.staticTexts["home.libraryCount"]
        let libraryBefore = try number(libraryCount)

        queueOneDeleteAndOpenApply()

        let keepSection = app.descendants(matching: .any)["apply.keepSection"]
        let deleteSection = app.descendants(matching: .any)["apply.deleteSection"]
        XCTAssertTrue(deleteSection.waitForExistence(timeout: 10))
        let tile = app.descendants(matching: .any).matching(identifier: "apply.tile").firstMatch
        XCTAssertEqual(tile.value as? String, "Delete")

        tile.tap()
        XCTAssertTrue(waitUntil { tile.value as? String == "Keep" }, "Tap did not switch the delete to keep")
        XCTAssertTrue(keepSection.label.contains("Keep (1)"), "Unexpected section: \(keepSection.label)")
        XCTAssertTrue(deleteSection.label.contains("Delete (0)"), "Unexpected section: \(deleteSection.label)")

        reopenApply(expectingPending: "1 to keep, 0 to delete")
        XCTAssertTrue(waitUntil { tile.value as? String == "Keep" }, "Reopened Apply lost the keep")
        tile.tap()
        XCTAssertTrue(waitUntil { tile.value as? String == "Delete" }, "Second tap did not switch back to delete")
        XCTAssertTrue(keepSection.label.contains("Keep (0)"), "Unexpected section: \(keepSection.label)")
        XCTAssertTrue(deleteSection.label.contains("Delete (1)"), "Unexpected section: \(deleteSection.label)")

        reopenApply(expectingPending: "0 to keep, 1 to delete")
        let all = app.buttons["apply.delete.all"]
        XCTAssertTrue(waitUntil { tile.value as? String == "Delete" }, "Reopened Apply lost the delete")
        XCTAssertEqual(all.label, "Take back all")
        all.tap()
        XCTAssertTrue(waitUntil { tile.value as? String == "Taken back" }, "Take back all did not clear the tile")
        XCTAssertTrue(deleteSection.label.contains("Delete (0)"), "Unexpected section: \(deleteSection.label)")
        XCTAssertEqual(all.label, "Restore all")

        all.tap()
        XCTAssertTrue(waitUntil { tile.value as? String == "Delete" }, "Restore all did not restore the tile")
        XCTAssertTrue(deleteSection.label.contains("Delete (1)"), "Unexpected section: \(deleteSection.label)")

        reopenApply(expectingPending: "0 to keep, 1 to delete")
        XCTAssertTrue(waitUntil { all.exists && all.label == "Take back all" }, "Reopened Apply lost the restored delete")
        all.tap()
        XCTAssertTrue(waitUntil { tile.value as? String == "Taken back" }, "Take back all did not clear the tile")

        app.buttons["apply.home"].tap()
        XCTAssertTrue(waitUntil { (try? self.number(libraryCount)) == libraryBefore }, "Library changed")
        XCTAssertFalse(app.buttons["home.pendingBar"].exists, "Take back all left pending decisions")
    }

    /// Reads the pending bar on Home, which counts pending decisions rather than Apply's tiles.
    private func expectPending(_ summary: String) {
        let pendingBar = app.buttons["home.pendingBar"]
        XCTAssertTrue(waitUntil { pendingBar.exists && pendingBar.label.contains(summary) }, "Pending bar did not show \(summary)")
    }

    /// Leaves Apply, checks pending decisions, and opens Apply again, which rebuilds its tiles from them.
    private func reopenApply(expectingPending summary: String) {
        app.buttons["apply.home"].tap()
        expectPending(summary)
        app.buttons["home.pendingBar"].tap()
    }

    private func queueOneDeleteAndOpenApply() {
        app.buttons["mode.swipe"].tap()
        app.buttons["deck.shuffle"].tap()
        let card = app.descendants(matching: .any).matching(identifier: "deck.card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.swipeLeft()
        let done = app.buttons["deck.done"]
        XCTAssertTrue(waitUntil { done.isEnabled }, "Left swipe did not queue a delete")
        done.tap()
    }

    private func number(_ element: XCUIElement) throws -> Int {
        try XCTUnwrap(try? Int(element.label, format: .number), "Not a number: \(element.label)")
    }
}
