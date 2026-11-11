import XCTest

/// Needs media from `scripts/seed-simulator.sh <udid>`: each seeded month has two photos on the same day,
/// and June 2020 has a busy day several screens tall. Leaves no photo in any album and no pending decision.
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

    func testTheGridOpensScrolledToTheCardOnABusyDay() throws {
        app.launchToHome()
        // Biggest first needs the sizes.
        XCTAssertTrue(app.staticTexts["up to, on device"].waitForExistence(timeout: 30), "Sizes were still being measured")
        try openTheBusyMonth()

        // Newest first puts the last tile on top; biggest first, the busy day's middle.
        for order in ["Newest first", "Biggest first"] {
            app.buttons["deck.sort"].tap()
            app.buttons[order].tap()
            app.buttons["deck.around"].tap()
            XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 10), "The grid showed no tiles")
            let card = selectedTiles.firstMatch
            XCTAssertTrue(waitUntil(timeout: 5) { card.exists && card.isHittable }, "\(order): the grid did not open scrolled to the card's photo")
            app.navigationBars.buttons["BackButton"].tap()
        }
        XCTAssertFalse(app.buttons["deck.done"].isEnabled, "The grid left a pending decision")
    }

    func testDragAcrossTilesSelectsThem() throws {
        app.launchToHome()
        try openTheBusyMonth()
        app.buttons["deck.around"].tap()
        XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 10), "The grid showed no tiles")
        let card = selectedTiles.firstMatch
        XCTAssertTrue(waitUntil(timeout: 5) { card.exists && card.isHittable }, "The grid did not open on the card's photo")
        let cardTop = card.frame.minY

        // The card is the busy day's last photo, at the end of the grid.
        app.swipeDown()
        XCTAssertTrue(waitUntil(timeout: 5) { !card.isHittable || card.frame.minY > cardTop + 100 }, "With Select off, a swipe did not scroll the grid")
        XCTAssertEqual(pickedCount(), 1, "With Select off, a swipe changed the selection")

        app.buttons["around.dragSelect"].tap()
        XCTAssertEqual(app.buttons["around.dragSelect"].label, "Done", "Select did not turn into Done")
        let range = try tilesAcrossTwoRows()
        let start = range[0]
        let addedCount = range.filter { $0.value as? String == "Not selected" }.count
        let selectedInRange = range.count - addedCount

        start.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: range[range.count - 1].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))

        XCTAssertFalse(app.descendants(matching: .any)["preview"].exists, "A short press-drag opened the preview")
        XCTAssertTrue(waitUntil(timeout: 5) { self.pickedCount() == 1 + addedCount }, "The drag did not select the \(range.count) tiles it crossed: \(pickedCount())")
        XCTAssertTrue(range.allSatisfy { $0.value as? String == "Selected" }, "A crossed tile stayed unselected")
        let status = app.staticTexts["around.selectionCount"]
        XCTAssertEqual(status.label, "\(1 + addedCount) items selected · drag to adjust", "The count text did not follow the drag")

        start.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: range[range.count - 1].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))

        XCTAssertTrue(waitUntil(timeout: 5) { self.pickedCount() == 1 - selectedInRange }, "A drag from a selected tile did not clear the range: \(pickedCount())")
        XCTAssertTrue(range.allSatisfy { $0.value as? String == "Not selected" }, "A crossed tile stayed selected")

        app.buttons["around.dragSelect"].tap()
        app.navigationBars.buttons["BackButton"].tap()
        XCTAssertFalse(app.buttons["deck.done"].isEnabled, "Selecting in the grid left a pending decision")
    }

    func testDragNearTheBottomEdgeScrollsAndKeepsSelecting() throws {
        app.launchToHome()
        try openTheBusyMonth()
        app.buttons["deck.around"].tap()
        XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 10), "The grid showed no tiles")
        // The grid opens at its end, on the busy day's last photo; leave room below to scroll into.
        app.swipeDown()
        app.swipeDown()
        app.buttons["around.dragSelect"].tap()
        let status = app.staticTexts["around.selectionCount"]
        XCTAssertTrue(status.waitForExistence(timeout: 5), "Select did not show the selection count")
        let screenful = tiles.allElementsBoundByIndex.filter(\.isHittable).count
        let start = try XCTUnwrap(tilesAwayFromTheEdges().first { $0.value as? String == "Not selected" }, "No unselected tile on screen")
        // The bottom bar's background starts 8 pt above the count text; the edge zone is the 56 pt above it.
        let edge = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: start.frame.midX, dy: status.frame.minY - 8 - 28))

        start.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: edge, withVelocity: .default, thenHoldForDuration: 2)

        XCTAssertGreaterThan(pickedCount(), screenful, "Holding at the bottom edge did not select past one screen")
        // The drag began on an unselected tile on screen, so a screen of only selected tiles has scrolled past it.
        XCTAssertTrue(tilesAwayFromTheEdges().allSatisfy { $0.value as? String == "Selected" }, "Holding at the bottom edge did not scroll the grid")

        app.buttons["around.dragSelect"].tap()
        app.navigationBars.buttons["BackButton"].tap()
        XCTAssertFalse(app.buttons["deck.done"].isEnabled, "Selecting in the grid left a pending decision")
    }

    /// From Home: opens the deck for June 2020, the month with the busy day.
    private func openTheBusyMonth() throws {
        app.buttons["mode.swipe"].tap()
        let busyDay = try XCTUnwrap(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2020, month: 6, day: 15)))
        let rows = app.buttons.matching(identifier: "months.row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10), "Swipe review showed no months; seed the simulator")
        let row = rows.matching(NSPredicate(format: "label BEGINSWITH %@", busyDay.formatted(.dateTime.month(.wide).year()))).firstMatch
        XCTAssertTrue(scrollUntilHittable(row), "Swipe review showed no busy month; run scripts/seed-simulator.sh <udid> 0")
        row.tap()
    }

    /// Every selected item in the grid, read from the album button, which counts tiles scrolled out of view too.
    private func pickedCount() -> Int {
        Int(app.buttons["around.album"].label.split(separator: " ")[1]) ?? -1
    }

    /// With Select on: tiles clear of the pinned day header and both edge zones, in grid order.
    private func tilesAwayFromTheEdges() -> [XCUIElement] {
        let top = app.navigationBars.firstMatch.frame.maxY + 60
        let bottom = app.staticTexts["around.selectionCount"].frame.minY - 8 - 60
        return tiles.allElementsBoundByIndex
            .filter { $0.isHittable && $0.frame.midY > top && $0.frame.midY < bottom }
            .sorted { ($0.frame.minY, $0.frame.minX) < ($1.frame.minY, $1.frame.minX) }
    }

    /// On screen, in grid order: an unselected tile, the tile two rows below it and every tile between.
    private func tilesAcrossTwoRows() throws -> [XCUIElement] {
        let onScreen = tilesAwayFromTheEdges()
        let columns = 4
        let first = try XCTUnwrap(
            onScreen.indices.first { onScreen[$0].value as? String == "Not selected" && $0 + 2 * columns < onScreen.count },
            "No unselected tile has two rows below it on screen"
        )
        return Array(onScreen[first...(first + 2 * columns)])
    }

    /// Scrolls the list down until `element` can be tapped; false when it never can.
    private func scrollUntilHittable(_ element: XCUIElement) -> Bool {
        for _ in 0..<10 {
            if element.exists, element.isHittable { return true }
            app.swipeUp()
        }
        return element.exists && element.isHittable
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
