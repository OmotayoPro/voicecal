import Foundation

/// Turns a transcript into numbers, operators and commands. Pure and deterministic;
/// unknown words are skipped.
enum SpokenPhraseParser {
    /// - Parameter startsAfterOperand: true when the equation already ends in a number where
    ///   this text will be inserted, so a leading "minus" means subtraction rather than a negative.
    static func parse(_ transcript: String, startsAfterOperand: Bool = false) -> [ParsedItem] {
        parse(TranscriptLexer.lex(transcript), startsAfterOperand: startsAfterOperand)
    }

    /// - Parameter start: where to begin. Earlier lexemes are not parsed, but still give
    ///   mishear correction its context.
    static func parse(_ rawLexemes: [Lexeme], from start: Int = 0, startsAfterOperand: Bool = false) -> [ParsedItem] {
        let lexemes = correctingMishears(rawLexemes)
        var items: [ParsedItem] = []
        var index = max(start, 0)

        while index < lexemes.count {
            let afterOperand = endsInOperand(items, startsAfterOperand)
            if let (text, used) = negativeNumber(lexemes, index, afterOperand: afterOperand) {
                items.append(.number(text))
                index += used
            } else if let (item, used) = phrase(lexemes, index) {
                items.append(item)
                index += used
            } else if case let .symbol(symbol) = lexemes[index], let item = SpokenVocabulary.symbols[symbol] {
                items.append(item)
                index += 1
            } else if let (text, used) = SpokenNumberParser.parse(lexemes, from: index) {
                items.append(.number(text))
                index += used
            } else {
                index += 1
            }
        }
        return items
    }

    // MARK: - Parts

    private static func correctingMishears(_ lexemes: [Lexeme]) -> [Lexeme] {
        lexemes.enumerated().map { index, lexeme in
            guard case let .word(text) = lexeme, let correction = SpokenVocabulary.mishears[text] else { return lexeme }
            let neighbours = [index - 1, index + 1].filter(lexemes.indices.contains).map { lexemes[$0] }
            return neighbours.contains(where: isMathContext) ? .word(correction) : lexeme
        }
    }

    private static func isMathContext(_ lexeme: Lexeme) -> Bool {
        switch lexeme {
        case .literal, .symbol: true
        case let .word(text): SpokenVocabulary.isMathWord(text)
        }
    }

    /// "minus five" / "negative five" / "-5" where a value is expected, not an operator.
    private static func negativeNumber(_ lexemes: [Lexeme], _ index: Int, afterOperand: Bool) -> (String, Int)? {
        let isNegativeWord = lexemes[index] == .word(SpokenVocabulary.negative)
        let isMinus = lexemes[index] == .word("minus") || lexemes[index] == .symbol("−")
        guard isNegativeWord || (isMinus && !afterOperand),
              let (text, used) = SpokenNumberParser.parse(lexemes, from: index + 1)
        else { return nil }
        return ("-" + text, used + 1)
    }

    private static func phrase(_ lexemes: [Lexeme], _ index: Int) -> (ParsedItem, Int)? {
        for length in stride(from: SpokenVocabulary.longestPhrase, through: 1, by: -1) {
            guard index + length <= lexemes.count else { continue }
            let words = lexemes[index ..< index + length].compactMap { lexeme -> String? in
                if case let .word(text) = lexeme {
                    text
                } else {
                    nil
                }
            }
            if words.count == length, let item = SpokenVocabulary.phrases[words] {
                return (item, length)
            }
        }
        return nil
    }

    private static func endsInOperand(_ items: [ParsedItem], _ startsAfterOperand: Bool) -> Bool {
        switch items.last {
        case nil: startsAfterOperand
        case .number, .op(.percent): true
        case .op, .command: false
        }
    }
}
