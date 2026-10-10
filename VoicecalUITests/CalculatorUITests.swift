import XCTest

final class CalculatorUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testTypeAnEquationAndCorrectAToken() {
        tap("1", "2", "Add", "3")
        let first = app.buttons["Token 1 of 3, number 12"]
        XCTAssertTrue(first.exists)
        snapshot("typed")

        first.tap()
        snapshot("editing")
        XCTAssertTrue(first.isSelected)

        tap("7")
        XCTAssertTrue(app.buttons["Token 1 of 3, number 7"].exists)
        XCTAssertTrue(app.buttons["Token 3 of 3, number 3"].exists)
    }

    func testLongEquationKeepsLatestTokenVisible() {
        tap("1", "2", "3", "Add", "4", "5", "6", "Multiply", "7", "8", "9", "Subtract", "1", "0")
        let last = app.buttons["Token 7 of 7, number 10"]
        XCTAssertTrue(last.isHittable)
        snapshot("long")
    }

    func testTappingBetweenTokensMovesTheCursorThere() {
        tap("1", "2", "Add", "3")
        let plus = app.buttons["Token 2 of 3, operator plus"]
        plus.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).tap()
        tap("9")
        XCTAssertTrue(app.buttons["Token 1 of 3, number 129"].exists)
        snapshot("cursor-mid")
    }

    func testClearReturnsToEmptyState() {
        tap("5", "Add", "Clear all")
        XCTAssertTrue(app.staticTexts["Empty equation"].exists)
    }

    private func tap(_ labels: String...) {
        for label in labels {
            app.buttons[label].tap()
        }
    }

    /// Saves a screenshot when SNAPSHOT_DIR is set (pass it as TEST_RUNNER_SNAPSHOT_DIR to xcodebuild).
    private func snapshot(_ name: String) {
        guard let directory = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] else { return }
        let url = URL(fileURLWithPath: directory).appendingPathComponent("\(name).png")
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: url)
    }
}
