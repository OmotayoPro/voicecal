import Testing
@testable import Voicecal

struct SpokenNumberParserTests {
    @Test(arguments: [
        ("zero", "0"),
        ("seven", "7"),
        ("twelve", "12"),
        ("twenty", "20"),
        ("twenty five", "25"),
        ("twenty-five", "25"),
        ("ninety nine", "99"),
        ("one hundred", "100"),
        ("a hundred", "100"),
        ("one hundred and five", "105"),
        ("one hundred five", "105"),
        ("three hundred forty two", "342"),
        ("nine hundred and ninety nine", "999"),
        ("one thousand", "1000"),
        ("a thousand", "1000"),
        ("two thousand three hundred", "2300"),
        ("two thousand and five", "2005"),
        ("twelve thousand three hundred and forty five", "12345"),
        ("five hundred thousand", "500000"),
        ("one million", "1000000"),
        ("three million two hundred thousand and one", "3200001"),
        ("nine hundred ninety nine million nine hundred ninety nine thousand nine hundred ninety nine", "999999999"),
        ("three point five", "3.5"),
        ("point five", "0.5"),
        ("zero point zero five", "0.05"),
        ("twelve point two five", "12.25"),
        ("one point twenty five", "1.25"),
        ("one hundred point one", "100.1"),
        ("one two three", "123"),
        ("zero five", "05"),
        ("nine nine point nine", "99.9"),
        ("three dot five", "3.5"),
        ("dot five", "0.5"),
        ("oh", "0"),
        ("oh point five", "0.5"),
        ("one oh five", "105"),
        ("two point oh five", "2.05"),
        ("ate", "8"),
        ("hate", "8"),
        ("sis", "6"),
        ("sex", "6"),
        ("tree", "3"),
        ("tri", "3"),
        ("twenty tree", "23"),
        ("sex hundred and ate", "608"),
        ("one five zero zero zero zero zero", "1500000"),
        ("1 5 0 0 0 0 0", "1500000"),
        ("15 0 0 0 0 0", "1500000"),
        ("150 000", "150000"),
        ("one 5 oh oh", "1500"),
        ("1 five", "15"),
        ("double five", "55"),
        ("one double zero", "100"),
        ("triple seven", "777"),
        ("nine double 0 five", "9005"),
        ("1 5 point 2 5", "15.25"),
        ("one five dot two", "15.2"),
        ("0 0 7", "007"),
        ("zero zero", "00"),
        ("12", "12"),
        ("3.5", "3.5"),
        (".5", "0.5"),
        ("1,000", "1000"),
        ("1,234.56", "1234.56"),
        ("2 million", "2000000"),
        ("5 hundred", "500"),
        ("3 point 5", "3.5"),
        ("3 point five", "3.5")
    ])
    func parses(phrase: String, expected: String) {
        #expect(SpokenNumberParser.number(from: phrase) == expected)
    }

    @Test(arguments: [
        "", "hundred", "and", "point", "dot", "plus", "banana", "twenty thirty", "five twenty",
        "one hundred and", "thousand", "twelve five", "a", "double", "triple plus", "1 5 3.5"
    ])
    func rejectsWhatIsNotExactlyOneNumber(phrase: String) {
        #expect(SpokenNumberParser.number(from: phrase) == nil)
    }

    @Test func stopsAtTheEndOfTheNumber() {
        let lexemes = TranscriptLexer.lex("twenty five plus three")
        let result = SpokenNumberParser.parse(lexemes, from: 0)
        #expect(result?.text == "25")
        #expect(result?.count == 2)
    }
}

struct TranscriptLexerTests {
    @Test func splitsWordsLiteralsAndSymbols() {
        #expect(TranscriptLexer.lex("12+3.5 Times x") == [
            .literal("12"), .symbol("+"), .literal("3.5"), .word("times"), .word("x")
        ])
    }

    @Test func normalisesSymbolsAndDropsPunctuation() {
        #expect(TranscriptLexer.lex("5 * 3 / 2 - 1, what’s 50%?") == [
            .literal("5"), .symbol("×"), .literal("3"), .symbol("÷"), .literal("2"), .symbol("−"),
            .literal("1"), .word("what's"), .literal("50"), .symbol("%")
        ])
    }

    @Test func sentencePeriodIsNotADecimalPoint() {
        #expect(TranscriptLexer.lex("12. Plus 3.") == [.literal("12"), .word("plus"), .literal("3")])
    }
}
