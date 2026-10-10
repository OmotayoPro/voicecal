import XCTest

final class CalculatorUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITEST_MODE"] = "1"
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

    func testLongPressDeletesAToken() {
        app.launch()
        tap("1", "2", "Add", "3")
        app.buttons["Token 2 of 3, operator plus"].press(forDuration: 0.9)
        XCTAssertTrue(app.buttons["Token 2 of 2, number 3"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Token 2 of 3, operator plus"].exists)
    }

    func testLargeNumbersAreGrouped() {
        app.launch()
        tap("1", "0", "0", "0", "Multiply", "1", "0", "0", "0")
        XCTAssertEqual(app.staticTexts["status"].label, "= 1,000,000")
        snapshot("grouped")
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

    func testDictationAppearsAsTokensAndMixesWithTyping() {
        app.launchEnvironment["UITEST_SPEECH_SCRIPT"] = "twelve|twelve plus|twelve plus three"
        app.launch()
        tap("Start listening")
        let last = app.buttons["Token 3 of 3, number 3"]
        XCTAssertTrue(last.waitForExistence(timeout: 3))
        XCTAssertEqual(last.value as? String, "pending")
        snapshot("dictating")

        tap("Multiply", "2")
        XCTAssertTrue(app.buttons["Token 5 of 5, number 2"].exists)
        XCTAssertTrue(app.buttons["Stop listening"].exists)
        XCTAssertEqual(app.staticTexts["status"].label, "= 18")
        snapshot("dictated-then-typed")
    }

    func testMicTurnsItselfOffAfterInactivity() {
        app.launchEnvironment["UITEST_SPEECH_SCRIPT"] = "eight"
        app.launchEnvironment["UITEST_INACTIVITY_SECONDS"] = "5"
        app.launch()
        tap("Start listening")
        XCTAssertTrue(app.buttons["Token 1 of 1, number 8"].waitForExistence(timeout: 3))
        sleep(3)
        snapshot("countdown")
        XCTAssertTrue(app.buttons["Start listening"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Token 1 of 1, number 8"].exists)
    }

    func testVoiceSettingsPersistAcrossLaunches() {
        app.launch()
        tap("Voice settings")
        let speak = app.switches["Speak the answer"]
        XCTAssertTrue(speak.waitForExistence(timeout: 3))
        XCTAssertEqual(speak.value as? String, "1")
        snapshot("settings")
        speak.switches.firstMatch.tap()
        XCTAssertEqual(speak.value as? String, "0")
        tap("Done")

        app.terminate()
        app.launchEnvironment["UITEST_KEEP_SETTINGS"] = "1"
        app.launch()
        tap("Voice settings")
        XCTAssertTrue(speak.waitForExistence(timeout: 3))
        XCTAssertEqual(speak.value as? String, "0")
    }

    func testOpeningSettingsTurnsTheMicOff() {
        app.launchEnvironment["UITEST_SPEECH_SCRIPT"] = ""
        app.launch()
        tap("Start listening")
        XCTAssertTrue(app.buttons["Stop listening"].waitForExistence(timeout: 2))
        tap("Voice settings")
        tap("Done")
        XCTAssertTrue(app.buttons["Start listening"].waitForExistence(timeout: 2))
    }

    /// Exercises the real recognizer. Opt in with TEST_RUNNER_REAL_MIC=1 after granting
    /// microphone and speech-recognition access to the app.
    func testRealMicSmoke() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["REAL_MIC"] == "1")
        app.launchEnvironment["UITEST_MODE"] = nil
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
