import XCTest

final class CalculatorUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testTypeAnEquationAndCorrectAToken() {
        app.launch()
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
        app.launch()
        tap("1", "2", "3", "Add", "4", "5", "6", "Multiply", "7", "8", "9", "Subtract", "1", "0")
        let last = app.buttons["Token 7 of 7, number 10"]
        XCTAssertTrue(last.isHittable)
        snapshot("long")
    }

    func testTappingBetweenTokensMovesTheCursorThere() {
        app.launch()
        tap("1", "2", "Add", "3")
        let plus = app.buttons["Token 2 of 3, operator plus"]
        plus.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).tap()
        tap("9")
        XCTAssertTrue(app.buttons["Token 1 of 3, number 129"].exists)
        snapshot("cursor-mid")
    }

    func testLiveResultThenEquals() {
        app.launch()
        tap("1", "2", "Add", "3", "Multiply", "4")
        XCTAssertEqual(app.staticTexts["status"].label, "= 24")
        snapshot("live-result")
        tap("Equals")
        XCTAssertTrue(app.buttons["Token 1 of 1, number 24"].exists)
        XCTAssertFalse(app.staticTexts["status"].exists)
    }

    func testClearReturnsToEmptyState() {
        app.launch()
        tap("5", "Add", "Clear all")
        XCTAssertTrue(app.staticTexts["Empty equation"].exists)
    }

    func testMicStaysOnUntilTappedAgain() {
        app.launchEnvironment["UITEST_SPEECH_SCRIPT"] = ""
        app.launch()
        tap("Start listening")
        XCTAssertTrue(app.buttons["Stop listening"].waitForExistence(timeout: 2))
        snapshot("mic-on")

        tap("5", "Add")
        XCTAssertTrue(app.buttons["Stop listening"].exists)

        tap("Stop listening")
        XCTAssertTrue(app.buttons["Start listening"].waitForExistence(timeout: 2))
    }

    /// Exercises the real recognizer. Opt in with TEST_RUNNER_REAL_MIC=1 after granting
    /// microphone and speech-recognition access to the app.
    func testRealMicSmoke() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["REAL_MIC"] == "1")
        app.launch()
        tap("Start listening")
        sleep(3)
        snapshot("real-mic")
        XCTAssertTrue(app.buttons["Stop listening"].exists)
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
