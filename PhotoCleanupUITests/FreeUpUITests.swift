import XCTest

/// Needs seeded photos and no videos older than three months: run `scripts/seed-simulator.sh <udid>` first.
/// Leaves no pending decision behind.
@MainActor
final class FreeUpUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testVideosFilterShowsNothingToDeleteAndAllBringsPhotosBack() throws {
        let tiles = openFreeUp()
        let kind = app.segmentedControls["freeUp.kind"]
        let delete = app.buttons["freeUp.delete"]

        kind.buttons["Videos"].tap()
        XCTAssertTrue(waitUntil { !tiles.firstMatch.exists }, "Videos still showed photo tiles")
        XCTAssertTrue(app.staticTexts["No videos before this date."].exists, "Empty grid did not say what is missing")
        XCTAssertEqual(delete.label, "Nothing to delete")
        XCTAssertFalse(delete.isEnabled, "Delete stayed on with no tiles")

        kind.buttons["All"].tap()
        XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 10), "All did not bring the photos back")
        XCTAssertTrue(delete.isEnabled)

        leaveExpectingNoPendingDecisions()
    }

    func testKeptTileSurvivesASortChange() throws {
        let tiles = openFreeUp()
        let keptTile = tiles.matching(NSPredicate(format: "value == %@", "Keep")).firstMatch
        let count = app.staticTexts["freeUp.count"]

        tiles.firstMatch.tap()
        XCTAssertTrue(keptTile.waitForExistence(timeout: 10), "Tap did not keep the tile")
        let countWithKeep = count.label
        let oldestFirstFrame = keptTile.frame

        // The seeded photos differ in size, so the oldest one is not also the biggest.
        sort("Biggest first")
        XCTAssertTrue(waitUntil { keptTile.frame != oldestFirstFrame }, "Biggest first did not reorder the grid")
        XCTAssertEqual(count.label, countWithKeep, "Changing the sort lost the keep")

        // Biggest first can put the kept tile under the Delete bar; oldest first puts it back at the top.
        sort("Oldest first")
        XCTAssertEqual(count.label, countWithKeep, "Changing the sort back lost the keep")
        keptTile.tap()
        XCTAssertTrue(waitUntil { !keptTile.exists }, "Second tap did not clear the keep")
        XCTAssertNotEqual(count.label, countWithKeep, "Clearing the keep did not count the tile for deletion")

        leaveExpectingNoPendingDecisions()
    }

    /// Opens Free up with its defaults (three months, all kinds, oldest first) and returns its tiles.
    private func openFreeUp() -> XCUIElementQuery {
        app.launchToHome()
        app.buttons["mode.freeUp"].tap()
        let tiles = app.descendants(matching: .any).matching(identifier: "freeUp.tile")
        XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 10), "Free up showed no photos; seed the simulator")
        return tiles
    }

    private func sort(_ order: String) {
        app.buttons["freeUp.sort"].tap()
        app.buttons[order].tap()
    }

    private func leaveExpectingNoPendingDecisions() {
        app.navigationBars.buttons["BackButton"].tap()
        XCTAssertTrue(app.staticTexts["home.libraryCount"].waitForExistence(timeout: 10), "Back did not return to Home")
        XCTAssertFalse(app.buttons["home.pendingBar"].exists, "Free up left a pending decision")
    }
}
