import XCTest

/// Needs media from `scripts/seed-simulator.sh <udid>`: each seeded month has two photos on the same day.
/// Leaves no photo in any album and no pending decision.
@MainActor
final class AroundUITests: XCTestCase {
    private static let albumTitle = "UI Test"

    private let app = XCUIApplication()
    private var tiles: XCUIElementQuery { app.descendants(matching: .any).matching(identifier: "around.tile") }
    private var selectedTiles: XCUIElementQuery { tiles.matching(NSPredicate(format: "value == %@", "Selected")) }
    private var remaining: XCUIElement { app.staticTexts.matching(identifier: "deck.remaining").firstMatch }

    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testAddTwoPhotosFromTheGridToAnAlbumThenTakeThemOut() throws {
        app.launchToHome()
        let month = try openMonthWithAnOpenSameDayPair()
        let count = try XCTUnwrap(Int(remaining.label.prefix { $0.isNumber }), "No count in \(remaining.label)")

        selectBothAndOpenThePicker()
        let row = searchPicker()
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
        XCTAssertTrue(waitUntil { row.exists && row.value as? String == "In album" }, "Row did not show both photos in the album")
        closePicker()
        XCTAssertEqual(selectedTiles.count, 2, "An album add changed the selection")

        app.navigationBars.buttons["BackButton"].tap()
        XCTAssertTrue(waitUntil { self.remaining.exists && self.remaining.label == "\(count - 2) left" }, "The deck did not lose both cards: \(remaining.label)")
        XCTAssertFalse(app.buttons["deck.done"].isEnabled, "The album add left a pending decision")

        // Protected photos show in no deck, so switch the album off to reach them again; launch switches it back on.
        app.navigationBars.buttons["BackButton"].tap()
        app.navigationBars.buttons["BackButton"].tap()
        app.buttons["Settings"].tap()
        let albumSwitch = app.switches.matching(NSPredicate(format: "label BEGINSWITH %@", Self.albumTitle)).firstMatch
        XCTAssertTrue(albumSwitch.waitForExistence(timeout: 10), "Settings did not list the album")
        albumSwitch.switches.firstMatch.tap()
        XCTAssertTrue(waitUntil { albumSwitch.value as? String == "0" }, "The album switch did not turn off")
        app.navigationBars.buttons["BackButton"].tap()
        app.buttons["mode.swipe"].tap()
        let sameMonth = app.buttons.matching(identifier: "months.row").matching(NSPredicate(format: "label BEGINSWITH %@", month)).firstMatch
        XCTAssertTrue(sameMonth.waitForExistence(timeout: 10))
        sameMonth.tap()
        XCTAssertTrue(waitUntil { self.remaining.exists && self.remaining.label == "\(count) left" }, "Switching the album off did not bring the cards back")

        selectBothAndOpenThePicker()
        let sameRow = searchPicker()
        XCTAssertTrue(waitUntil { sameRow.exists && sameRow.value as? String == "In album" }, "Picker did not show both photos in the album")
        sameRow.tap()
        XCTAssertTrue(waitUntil { sameRow.value as? String == "Not in album" }, "Row did not show both photos taken out")
        closePicker()
        app.navigationBars.buttons["BackButton"].tap()
        XCTAssertTrue(waitUntil { self.remaining.exists && self.remaining.label == "\(count) left" }, "Taking both out did not keep the cards in the deck")
        XCTAssertFalse(app.buttons["deck.done"].isEnabled, "The test left a pending decision")
    }

    func testPinchingTheCardClosedOpensTheGrid() throws {
        app.launchToHome()
        app.buttons["mode.swipe"].tap()
        let rows = app.buttons.matching(identifier: "months.row").matching(NSPredicate(format: "isEnabled == true"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10), "Swipe review showed no months; seed the simulator")
        rows.firstMatch.tap()
        let card = app.descendants(matching: .any).matching(identifier: "deck.card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "The month deck showed no card")
        let count = remaining.label

        card.pinch(withScale: 0.4, velocity: -1)

        XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 10), "Pinching the card closed did not open the grid")
        XCTAssertEqual(selectedTiles.count, 1, "The card's tile did not start selected")
        app.navigationBars.buttons["BackButton"].tap()
        XCTAssertTrue(waitUntil { self.remaining.exists && self.remaining.label == count }, "The pinch decided the card")
        XCTAssertFalse(app.buttons["deck.done"].isEnabled, "The pinch left a pending decision")
    }

    /// Opens the first month deck whose top card shares its day with another open photo; returns the month's title.
    private func openMonthWithAnOpenSameDayPair() throws -> String {
        app.buttons["mode.swipe"].tap()
        let rows = app.buttons.matching(identifier: "months.row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10), "Swipe review showed no months; seed the simulator")
        for index in 0..<rows.count where rows.element(boundBy: index).isEnabled {
            let row = rows.element(boundBy: index)
            let month = String(row.label.prefix { $0 != "," })
            row.tap()
            XCTAssertTrue(app.buttons["deck.around"].waitForExistence(timeout: 10), "The month deck showed no Around this time button")
            app.buttons["deck.around"].tap()
            XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 10), "The grid showed no tiles")
            if partner().exists {
                app.navigationBars.buttons["BackButton"].tap()
                return month
            }
            app.navigationBars.buttons["BackButton"].tap()
            app.navigationBars.buttons["BackButton"].tap()
            XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10), "Back did not return to the months")
        }
        return try XCTUnwrap(nil, "No month deck has two open photos on its top card's day; run scripts/seed-simulator.sh <udid> again")
    }

    /// In the grid: the first unselected tile of the selected tile's day with no decision and no protection.
    private func partner() -> XCUIElement {
        let card = selectedTiles.firstMatch
        XCTAssertEqual(selectedTiles.count, 1, "The card's tile did not start selected")
        // The label reads "Photo, <day>, …".
        let day = card.label.split(separator: ", ").dropFirst().first.map(String.init) ?? card.label
        return tiles.matching(NSPredicate(
            format: "value == %@ AND label CONTAINS %@ AND NOT (label CONTAINS 'Keep' OR label CONTAINS 'Delete' OR label CONTAINS 'Protected')",
            "Not selected", day
        )).firstMatch
    }

    /// From the deck: opens the grid, selects the other open photo of the card's day and opens the album picker for both.
    private func selectBothAndOpenThePicker() {
        app.buttons["deck.around"].tap()
        XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 10), "The grid showed no tiles")
        let other = partner()
        XCTAssertTrue(other.exists, "The grid showed no other open photo of the card's day")
        other.tap()
        XCTAssertTrue(waitUntil { self.selectedTiles.count == 2 }, "A tap did not select the other photo")
        let album = app.buttons["around.album"]
        XCTAssertEqual(album.label, "Add 2 to album")
        album.tap()
        XCTAssertTrue(app.descendants(matching: .any)["albums.sheet"].waitForExistence(timeout: 10), "Album picker did not open")
        XCTAssertTrue(app.navigationBars["Add 2 to album"].exists, "The picker title did not count both photos")
    }

    /// Searches the open picker for the test album; returns its row, which may not exist yet.
    private func searchPicker() -> XCUIElement {
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
    }
}
