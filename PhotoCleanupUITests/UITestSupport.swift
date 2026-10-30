import XCTest

extension XCUIApplication {
    /// Launches with fresh app state, taps through the photo permission prompt if it shows, and waits for Home.
    func launchToHome() {
        launchArguments = ["-uiTesting"]
        launch()
        let allow = buttons["permission.action"]
        if allow.waitForExistence(timeout: 5) {
            allow.tap()
            let fullAccess = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.buttons["Allow Full Access"]
            if fullAccess.waitForExistence(timeout: 10) {
                fullAccess.tap()
            }
        }
        XCTAssertTrue(staticTexts["home.libraryCount"].waitForExistence(timeout: 30), "Home never showed library totals")
    }
}

@MainActor
func waitUntil(timeout: TimeInterval = 15, _ condition: @escaping () -> Bool) -> Bool {
    let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
    return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
}
