import Testing
@testable import Voicecal

/// Compact notation for expectations: numbers as-is, operators by symbol, commands as !clear !delete !equals.
private func items(_ notation: String) -> [ParsedItem] {
    notation.split(separator: " ").map { part in
        switch part {
        case "!clear": .command(.clear)
        case "!delete": .command(.deleteLast)
        case "!equals": .command(.equals)
        default:
            if let value = Operator(rawValue: String(part)) {
                .op(value)
            } else {
                .number(String(part))
            }
        }
    }
}

struct SpokenPhraseParserTests {
    @Test(arguments: [
        ("twelve plus fifteen times three point five", "12 + 15 × 3.5"),
        ("12 plus 15", "12 + 15"),
        ("12+15", "12 + 15"),
        ("3.5", "3.5"),
        ("ten add two", "10 + 2"),
        ("ten minus two", "10 − 2"),
        ("ten subtract two", "10 − 2"),
        ("ten take away two", "10 − 2"),
        ("six times seven", "6 × 7"),
        ("six multiplied by seven", "6 × 7"),
        ("six x seven", "6 × 7"),
        ("six ex seven", "6 × 7"),
        ("6 x 7", "6 × 7"),
        ("6x7", "6 × 7"),
        ("6 * 7", "6 × 7"),
        ("nine divided by three", "9 ÷ 3"),
        ("nine over three", "9 ÷ 3"),
        ("9/3", "9 ÷ 3"),
        ("fifty percent", "50 %"),
        ("50%", "50 %"),
        ("two hundred times ten percent", "200 × 10 %"),
        ("one hundred and five plus two thousand three hundred", "105 + 2300"),
        ("Twelve, plus fifteen.", "12 + 15"),
        ("twelve fifteen", "12 15")
    ])
    func parsesEquations(transcript: String, expected: String) {
        #expect(SpokenPhraseParser.parse(transcript) == items(expected))
    }

    @Test(arguments: [
        ("minus five", "-5"),
        ("minus five plus eight", "-5 + 8"),
        ("three times minus two", "3 × -2"),
        ("three times negative two", "3 × -2"),
        ("negative five", "-5"),
        ("-5 + 8", "-5 + 8"),
        ("3 × -2", "3 × -2"),
        ("ten minus minus two", "10 − -2"),
        ("ten minus", "10 −"),
        ("minus", "−"),
        ("fifty percent minus five", "50 % − 5"),
        ("negative", ""),
        ("minus point five", "-0.5")
    ])
    func negativeVersusSubtraction(transcript: String, expected: String) {
        #expect(SpokenPhraseParser.parse(transcript) == items(expected))
    }

    @Test func leadingMinusIsSubtractionWhenTheEquationEndsInANumber() {
        #expect(SpokenPhraseParser.parse("minus five", startsAfterOperand: true) == items("− 5"))
        #expect(SpokenPhraseParser.parse("minus five", startsAfterOperand: false) == items("-5"))
    }

    @Test(arguments: [
        ("clear", "!clear"),
        ("clear all", "!clear"),
        ("delete", "!delete"),
        ("scratch that", "!delete"),
        ("undo", "!delete"),
        ("equals", "!equals"),
        ("calculate", "!equals"),
        ("what's the answer", "!equals"),
        ("What’s the answer?", "!equals"),
        ("what is the answer", "!equals"),
        ("two plus two equals", "2 + 2 !equals"),
        ("2+2=", "2 + 2 !equals"),
        ("five plus scratch that times three", "5 + !delete × 3"),
        ("clear all seven", "!clear 7")
    ])
    func commands(transcript: String, expected: String) {
        #expect(SpokenPhraseParser.parse(transcript) == items(expected))
    }

    @Test(arguments: [
        ("two plus to", "2 + 2"),
        ("to plus two", "2 + 2"),
        ("too times three", "2 × 3"),
        ("for plus for", "4 + 4"),
        ("5 times for", "5 × 4"),
        ("won plus ate", "1 + 8"),
        ("twenty for", "24"),
        ("divided by to", "÷ 2")
    ])
    func mishearsNextToMath(transcript: String, expected: String) {
        #expect(SpokenPhraseParser.parse(transcript) == items(expected))
    }

    @Test(arguments: [
        "I want to go", "this is for you", "too", "for", "hello there", "", "   ", "um so like",
        "I won the game"
    ])
    func ordinarySpeechProducesNothing(transcript: String) {
        #expect(SpokenPhraseParser.parse(transcript).isEmpty)
    }

    @Test func unknownWordsAreSkippedBetweenMath() {
        #expect(SpokenPhraseParser.parse("um twelve uh plus like three") == items("12 + 3"))
    }
}
