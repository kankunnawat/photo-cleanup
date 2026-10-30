import XCTest

/// Needs seeded media: run `scripts/seed-simulator.sh <udid>` first. Leaves no photo in any album.
@MainActor
final class AlbumUITests: XCTestCase {
    private static let albumTitle = "UI Test"

    private let app = XCUIApplication()

    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testAddToAnAlbumFromTheViewerThenTakeItOut() throws {
        app.launchToHome()
        app.buttons["mode.freeUp"].tap()
        let tile = app.descendants(matching: .any).matching(identifier: "freeUp.tile").firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 10), "Free up showed no photos; seed the simulator")
        tile.press(forDuration: 1)

        let albumButton = app.buttons["preview.album"]
        XCTAssertTrue(albumButton.waitForExistence(timeout: 10), "Touch and hold did not open the viewer")
        let status = app.staticTexts["preview.status"]
        let actions = app.buttons.matching(identifier: "preview.action")
        XCTAssertTrue(status.waitForExistence(timeout: 5), "Viewer showed no status")
        XCTAssertNotEqual(status.label, "Protected")
        XCTAssertGreaterThan(actions.count, 0, "Viewer offered no action before the album add")

        let row = openPicker()
        if row.waitForExistence(timeout: 2) {
            XCTAssertEqual(row.value as? String, "Not in album")
            row.tap()
        } else {
            app.buttons["albums.new"].tap()
            let name = app.alerts.textFields.firstMatch
            XCTAssertTrue(name.waitForExistence(timeout: 5), "New album did not ask for a name")
            name.typeText(Self.albumTitle)
            app.alerts.buttons["Create"].tap()
        }
        XCTAssertTrue(waitUntil { row.exists && row.value as? String == "In album" }, "Row did not show the photo in the album")
        closePicker()
        XCTAssertTrue(waitUntil { status.label == "Protected" }, "Viewer did not show the photo as protected")
        XCTAssertEqual(actions.count, 0, "Viewer still offered an action for a protected photo")

        let sameRow = openPicker()
        XCTAssertTrue(waitUntil { sameRow.exists && sameRow.value as? String == "In album" }, "Picker did not show the photo in the album")
        sameRow.tap()
        XCTAssertTrue(waitUntil { sameRow.value as? String == "Not in album" }, "Row did not show the photo taken out")
        closePicker()
        XCTAssertTrue(waitUntil { status.label != "Protected" && actions.count > 0 }, "Viewer actions did not come back after the photo left the album")
    }

    /// Opens the picker from the viewer and searches for the test album; returns its row, which may not exist yet.
    private func openPicker() -> XCUIElement {
        app.buttons["preview.album"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["albums.sheet"].waitForExistence(timeout: 10), "Album picker did not open")
        let search = app.textFields["albums.search"]
        search.tap()
        search.typeText(Self.albumTitle)
        return app.buttons.matching(identifier: "albums.row")
            .matching(NSPredicate(format: "label BEGINSWITH %@", Self.albumTitle))
            .firstMatch
    }

    private func closePicker() {
        let done = app.buttons["albums.done"]
        XCTAssertTrue(waitUntil { done.isEnabled }, "Done stayed off after the write")
        done.tap()
        XCTAssertTrue(waitUntil { !self.app.descendants(matching: .any)["albums.sheet"].exists }, "Done did not close the picker")
        XCTAssertTrue(app.buttons["preview.close"].exists, "Closing the picker also closed the viewer")
    }

    func testDeckAlbumButtonOpensAndClosesThePicker() throws {
        app.launchToHome()
        app.buttons["mode.swipe"].tap()
        app.buttons["deck.shuffle"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "deck.card").firstMatch.waitForExistence(timeout: 10))

        app.buttons["deck.album"].tap()
        let sheet = app.descendants(matching: .any)["albums.sheet"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 10), "Deck Album button did not open the picker")
        app.buttons["albums.done"].tap()
        XCTAssertTrue(waitUntil { !sheet.exists }, "Done did not close the picker")
        XCTAssertTrue(app.buttons["deck.album"].isEnabled)
    }
}
