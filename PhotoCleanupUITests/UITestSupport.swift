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

/// Reads a size the app shows, such as "23.8 MB"; nil when the label shows none.
func size(in label: String) -> Double? {
    guard let match = label.firstMatch(of: /([0-9.]+) (bytes|KB|MB|GB)/), let value = Double(match.1) else { return nil }
    let unit: Double = switch match.2 {
    case "KB": 1e3
    case "MB": 1e6
    case "GB": 1e9
    default: 1
    }
    return value * unit
}

/// Like `size(in:)`, but fails the test when the label shows no size. `XCTUnwrap` records the failure
/// even under `try?`, so polling code calls `size(in:)` instead.
func bytes(in label: String) throws -> Double {
    try XCTUnwrap(size(in: label), "No size in \(label)")
}
