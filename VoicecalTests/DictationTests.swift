import Foundation
import Testing
@testable import Voicecal

/// Dictation driven end to end through the view model by a fake recognizer feeding scripted partials.
@MainActor
struct DictationTests {
    private let speech = FakeSpeechRecognizer()
    private let viewModel: CalculatorViewModel

    init() async {
        // A long pause, so tests decide exactly when a commit happens.
        viewModel = CalculatorViewModel(speech: speech, pauseBeforeCommit: .seconds(60))
        await viewModel.startListening()
    }

    private var equation: Equation {
        viewModel.equation
    }

    private var texts: [String] {
        equation.tokens.map(\.text)
    }

    private var pendingTexts: [String] {
        equation.tokens.filter { equation.pendingTokenIDs.contains($0.id) }.map(\.text)
    }

    private func type(_ keys: KeypadKey...) {
        keys.forEach(viewModel.handle)
    }

    // MARK: Streaming and commit

    @Test func revisedPartialsReplaceRatherThanDuplicate() {
        speech.hear("to")
        #expect(texts.isEmpty)
        speech.hear("two")
        #expect(texts == ["2"])
        speech.hear("twelve")
        #expect(texts == ["12"])
        speech.hear("twelve plus")
        speech.hear("twelve plus fifteen")
        #expect(texts == ["12", "+", "15"])
        #expect(pendingTexts == ["12", "+", "15"])
        #expect(equation.cursorIndex == 3)
    }

    @Test func finalResultCommitsPendingTokens() {
        speech.hear("twelve plus fifteen")
        speech.hear("twelve plus fifteen", isFinal: true)
        #expect(texts == ["12", "+", "15"])
        #expect(pendingTexts.isEmpty)
    }

    @Test func pauseInSpeechCommits() async throws {
        let quick = CalculatorViewModel(speech: speech, pauseBeforeCommit: .milliseconds(20))
        await quick.startListening()
        speech.hear("seven")
        #expect(quick.equation.pendingTokenIDs.count == 1)
        try await Task.sleep(for: .milliseconds(300))
        #expect(quick.equation.pendingTokenIDs.isEmpty)
        #expect(quick.equation.tokens.map(\.text) == ["7"])
    }

    @Test func wordsAfterACommitOnlyAddWhatIsNew() {
        speech.hear("twelve plus", isFinal: false)
        type(.digit(7)) // commits "12 +", then types
        speech.hear("twelve plus")
        #expect(texts == ["12", "+", "7"])
        speech.hear("twelve plus times three")
        #expect(texts == ["12", "+", "7", "×", "3"])
        #expect(pendingTexts == ["×", "3"])
    }

    @Test func recognizerReformattingCommittedWordsDoesNotDuplicateThem() {
        speech.hear("twelve plus")
        type(.digit(7))
        speech.hear("12 + times 3")
        #expect(texts == ["12", "+", "7", "×", "3"])
    }

    @Test func transcriptShrinkingAfterCommitIsHarmless() {
        speech.hear("twelve plus fifteen", isFinal: true)
        speech.hear("twelve")
        #expect(texts == ["12", "+", "15"])
        speech.hear("twelve plus fifteen times two")
        #expect(texts.suffix(2) == ["×", "2"])
    }

    @Test func unknownSpeechAddsNothing() {
        speech.hear("hello there how are you")
        #expect(texts.isEmpty)
    }

    // MARK: Manual edits during dictation

    @Test func typingMidSentenceKeepsTheMicOnAndSurvives() {
        speech.hear("twelve plus")
        type(.digit(7), .digit(0))
        #expect(viewModel.isListening)
        #expect(speech.stopCount == 0)
        #expect(pendingTexts.isEmpty)
        speech.hear("twelve plus minus five")
        #expect(texts == ["12", "+", "70", "−", "5"])
    }

    @Test func backspaceMidSentenceIsNotUndoneByLaterSpeech() {
        speech.hear("twelve plus fifteen")
        type(.backspace, .backspace)
        #expect(texts == ["12", "+"])
        speech.hear("twelve plus fifteen three")
        #expect(texts == ["12", "+", "3"])
    }

    @Test func tappingATokenThenSpeakingANumberReplacesIt() {
        type(.digit(1), .digit(2), .add, .digit(3))
        let target = equation.tokens[0].id
        viewModel.tapToken(id: target)
        speech.hear("fifteen")
        #expect(texts == ["15", "+", "3"])
        #expect(equation.editingTokenID == nil)
        #expect(equation.cursorIndex == 1)
        speech.hear("fifty")
        #expect(texts == ["50", "+", "3"])
    }

    @Test func speakingWithTheCursorInTheMiddleInsertsThere() {
        type(.digit(1), .add, .digit(3))
        viewModel.tapGap(at: 1)
        speech.hear("times two")
        #expect(texts == ["1", "×", "2", "+", "3"])
        #expect(equation.cursorIndex == 3)
    }

    @Test func deletingATokenMidSentenceKeepsTheMicOn() {
        speech.hear("five plus six")
        viewModel.deleteToken(id: equation.tokens[1].id)
        #expect(viewModel.isListening)
        #expect(texts == ["5", "6"])
        #expect(pendingTexts.isEmpty)
    }

    @Test func movingTheCursorCommitsWhatWasHeard() {
        speech.hear("eight times")
        viewModel.tapGap(at: 0)
        #expect(pendingTexts.isEmpty)
        speech.hear("eight times nine")
        #expect(texts == ["9", "8", "×"])
    }

    // MARK: Minus and results

    @Test func minusAfterANumberIsSubtraction() {
        type(.digit(1), .digit(2))
        speech.hear("minus five")
        #expect(texts == ["12", "−", "5"])
    }

    @Test func minusAtTheStartIsANegativeNumber() {
        speech.hear("minus five")
        #expect(texts == ["-5"])
    }

    @Test func operatorAfterAResultContinuesFromIt() {
        type(.digit(4), .add, .digit(4), .equals)
        speech.hear("minus three")
        #expect(texts == ["8", "−", "3"])
    }

    @Test func numberAfterAResultStartsANewEquation() {
        type(.digit(4), .add, .digit(4), .equals)
        speech.hear("five")
        speech.hear("five plus one")
        #expect(texts == ["5", "+", "1"])
    }

    // MARK: Commands

    @Test func equalsCommandSolvesOnCommit() {
        speech.hear("five plus three equals")
        #expect(texts == ["5", "+", "3"]) // not run while it could still be revised
        speech.hear("five plus three equals", isFinal: true)
        #expect(texts == ["8"])
        #expect(pendingTexts.isEmpty)
    }

    @Test func clearCommand() {
        type(.digit(1), .digit(2), .add)
        speech.hear("clear all", isFinal: true)
        #expect(texts.isEmpty)
    }

    @Test func scratchThatRemovesTheLastToken() {
        speech.hear("five plus three scratch that", isFinal: true)
        #expect(texts == ["5", "+"])
    }

    @Test func everyMentionOfDeleteRemovesAnotherEntry() {
        type(.digit(1), .add, .digit(2), .multiply, .digit(3))
        // The transcript is cumulative, so each line below adds to what was already heard.
        speech.hear("delete", isFinal: true)
        #expect(texts == ["1", "+", "2", "×"])
        speech.hear("delete delete delete", isFinal: true)
        #expect(texts == ["1", "+"])
        speech.hear("delete delete delete delete delete delete", isFinal: true)
        #expect(texts.isEmpty)
    }

    @Test func deleteAfterAPauseStillWorks() {
        type(.digit(1), .add, .digit(2))
        speech.hear("delete")
        speech.send(.segmentRestarted)
        #expect(texts == ["1", "+"])
        speech.hear("delete")
        speech.send(.segmentRestarted)
        #expect(texts == ["1"])
    }

    @Test func deleteRemovesAWholeNumberNotOneDigit() {
        speech.hear("one hundred and five plus twenty delete", isFinal: true)
        #expect(texts == ["105", "+"])
    }

    @Test func clearRemovesEverythingLikeTheACKey() {
        type(.digit(9), .multiply, .digit(9))
        speech.hear("tree plus sex clear", isFinal: true)
        #expect(texts.isEmpty)
        #expect(viewModel.isListening)
    }

    @Test func commandsRunInSpokenOrder() {
        speech.hear("nine clear two plus two equals times three", isFinal: true)
        #expect(texts == ["4", "×", "3"])
    }

    // MARK: Lifecycle

    @Test func newRecognitionTaskStartsCountingFromEmpty() {
        speech.hear("twelve plus")
        speech.send(.segmentRestarted)
        #expect(pendingTexts.isEmpty)
        speech.hear("three")
        #expect(texts == ["12", "+", "3"])
    }

    @Test func stoppingTheMicCommitsPendingTokens() {
        speech.hear("six times seven")
        viewModel.handle(.mic)
        #expect(!viewModel.isListening)
        #expect(texts == ["6", "×", "7"])
        #expect(pendingTexts.isEmpty)
    }

    @Test func speechAfterTheMicIsOffIsIgnored() {
        viewModel.handle(.mic)
        speech.hear("nine")
        #expect(texts.isEmpty)
    }

    @Test func restartingTheMicDoesNotReplayTheOldTranscript() async {
        speech.hear("six", isFinal: true)
        viewModel.handle(.mic)
        await viewModel.startListening()
        speech.hear("plus one")
        #expect(texts == ["6", "+", "1"])
    }
}
