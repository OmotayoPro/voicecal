import Foundation
import Testing
@testable import Voicecal

/// Figures read out one digit at a time, in one breath or with pauses between digits.
@MainActor
struct DigitByDigitDictationTests {
    private let speech = FakeSpeechRecognizer()
    private let viewModel: CalculatorViewModel

    init() async {
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

    /// One digit at a time, with a pause long enough to commit after each.
    private func sayWithPauses(_ words: String...) {
        for word in words {
            speech.hear(word)
            speech.send(.segmentRestarted)
        }
    }

    @Test func digitsSpokenOneAtATimeBuildOneNumber() {
        sayWithPauses("one", "five", "zero", "zero", "zero", "zero", "zero")
        #expect(texts == ["1500000"])
        #expect(pendingTexts.isEmpty)
    }

    @Test func digitsSpokenInOneBreathBuildOneNumber() {
        speech.hear("one five zero zero zero zero zero", isFinal: true)
        #expect(texts == ["1500000"])
    }

    @Test func digitsTheRecognizerWritesAsFiguresBuildOneNumber() {
        speech.hear("1 5 0 0 0 0 0", isFinal: true)
        #expect(texts == ["1500000"])
    }

    @Test func digitRunsOnBothSidesOfAnOperator() {
        sayWithPauses("one", "five", "plus", "two", "five")
        #expect(texts == ["15", "+", "25"])
    }

    @Test func digitsAfterAPauseCarryOnATypedNumber() {
        type(.digit(1), .digit(5))
        sayWithPauses("zero", "zero")
        #expect(texts == ["1500"])
    }

    @Test func digitsAfterAPauseCarryOnADecimal() {
        sayWithPauses("three point one", "four", "one")
        #expect(texts == ["3.141"])
    }

    @Test func revisedSpeechTakesBackDigitsItAdded() {
        sayWithPauses("one five")
        speech.hear("zero")
        #expect(texts == ["150"])
        speech.hear("zero zero")
        #expect(texts == ["1500"])
        speech.hear("plus")
        #expect(texts == ["15", "+"])
        speech.hear("plus four")
        #expect(texts == ["15", "+", "4"])
    }

    @Test func aNumberAfterAResultStillStartsFresh() {
        type(.digit(4), .add, .digit(4), .equals)
        sayWithPauses("two", "five")
        #expect(texts == ["25"])
    }

    @Test func aNegativeOrDecimalNumberDoesNotJoinTheOneBefore() {
        sayWithPauses("five")
        speech.hear("point three", isFinal: true)
        #expect(texts == ["5", "0.3"])
    }

    @Test func zerosSpokenAloneOrAfterADecimalPointBehave() {
        speech.hear("zero zero", isFinal: true)
        #expect(texts == ["0"])
        speech.hear("zero zero plus oh oh point five", isFinal: true)
        #expect(texts == ["0", "+", "0.5"])
    }

    @Test func leadingZerosCollapse() {
        sayWithPauses("zero", "zero", "seven")
        #expect(texts == ["7"])
    }

    @Test func digitsDoNotJoinANumberBeingCorrected() {
        type(.digit(1), .digit(2), .add, .digit(3))
        viewModel.tapToken(id: equation.tokens[2].id)
        speech.hear("nine", isFinal: true)
        #expect(texts == ["12", "+", "9"])
    }
}
