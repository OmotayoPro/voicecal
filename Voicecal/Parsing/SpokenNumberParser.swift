import Foundation

/// Turns spoken or written numbers into plain digit strings: "twenty five point five" -> "25.5".
enum SpokenNumberParser {
    /// Parses the longest number beginning at `start`. Returns its text and how many lexemes it used.
    static func parse(_ lexemes: [Lexeme], from start: Int) -> (text: String, count: Int)? {
        var index = start
        var integer: String?

        if case let .literal(text)? = lexeme(lexemes, index) {
            if text.contains(".") {
                return (text, 1)
            }
            let (value, used) = scaledLiteral(text, lexemes, index)
            integer = value
            index += used
        } else if let (text, used) = digitRun(lexemes, index) ?? cardinal(lexemes, index) {
            integer = text
            index += used
        }

        if let (digits, used) = fraction(lexemes, index) {
            index += used
            return ((integer ?? "0") + "." + digits, index - start)
        }
        guard let integer else { return nil }
        return (integer, index - start)
    }

    /// Parses a phrase that is expected to be exactly one number.
    static func number(from phrase: String) -> String? {
        let lexemes = TranscriptLexer.lex(phrase)
        guard let (text, count) = parse(lexemes, from: 0), count == lexemes.count else { return nil }
        return text
    }

    // MARK: - Parts

    private static func lexeme(_ lexemes: [Lexeme], _ index: Int) -> Lexeme? {
        lexemes.indices.contains(index) ? lexemes[index] : nil
    }

    private static func word(_ lexemes: [Lexeme], _ index: Int) -> String? {
        if case let .word(text)? = lexeme(lexemes, index) {
            text
        } else {
            nil
        }
    }

    /// "2 million", "5 hundred": a digit literal followed by scale words.
    private static func scaledLiteral(_ text: String, _ lexemes: [Lexeme], _ index: Int) -> (String, Int) {
        guard var value = Int(text) else { return (text, 1) }
        var used = 1
        while let next = word(lexemes, index + used), let scale = scaleValue(next) {
            let (product, overflow) = value.multipliedReportingOverflow(by: scale)
            guard !overflow else { break }
            value = product
            used += 1
        }
        return (String(value), used)
    }

    /// "one two three" -> "123". Needs at least two single digits in a row.
    private static func digitRun(_ lexemes: [Lexeme], _ index: Int) -> (String, Int)? {
        var digits = ""
        while let next = word(lexemes, index + digits.count), let value = SpokenVocabulary.units[next] {
            digits += String(value)
        }
        guard digits.count > 1 else { return nil }
        let trimmed = String(digits.drop { $0 == "0" })
        return (trimmed.isEmpty ? "0" : trimmed, digits.count)
    }

    /// "two thousand three hundred and five" -> "2305".
    private static func cardinal(_ lexemes: [Lexeme], _ index: Int) -> (String, Int)? {
        if word(lexemes, index).flatMap({ SpokenVocabulary.units[$0] }) == 0 {
            return ("0", 1)
        }
        var builder = CardinalBuilder()
        var used = 0
        while let next = word(lexemes, index + used) {
            let following = word(lexemes, index + used + 1)
            let accepted: Bool = if let unit = SpokenVocabulary.units[next] {
                builder.add(unit: unit)
            } else if let value = SpokenVocabulary.teens[next] ?? SpokenVocabulary.tens[next] {
                builder.add(tensOrTeen: value)
            } else if next == SpokenVocabulary.hundred {
                builder.multiplyByHundred()
            } else if let scale = SpokenVocabulary.scales[next] {
                builder.apply(scale: scale)
            } else if next == "and" {
                used > 0 && builder.isAtRoundHundred && startsSmallNumber(following)
            } else if next == "a", used == 0, isScale(following) {
                builder.add(unit: 1)
            } else {
                false
            }
            guard accepted else { break }
            used += 1
        }
        return used == 0 ? nil : (String(builder.value), used)
    }

    /// Accumulates a spoken whole number, refusing words that cannot extend it.
    private struct CardinalBuilder {
        private var total = 0
        private var current = 0
        private var lastScale = Int.max

        var value: Int {
            total + current
        }

        var isAtRoundHundred: Bool {
            current % 100 == 0
        }

        mutating func add(unit: Int) -> Bool {
            let lowTwo = current % 100
            guard unit > 0, lowTwo == 0 || (lowTwo >= 20 && lowTwo % 10 == 0) else { return false }
            current += unit
            return true
        }

        mutating func add(tensOrTeen value: Int) -> Bool {
            guard isAtRoundHundred else { return false }
            current += value
            return true
        }

        mutating func multiplyByHundred() -> Bool {
            guard (1 ... 9).contains(current) else { return false }
            current *= 100
            return true
        }

        mutating func apply(scale: Int) -> Bool {
            guard current > 0, scale < lastScale else { return false }
            total += current * scale
            current = 0
            lastScale = scale
            return true
        }
    }

    /// The digits after "point": "point two five" -> "25".
    private static func fraction(_ lexemes: [Lexeme], _ index: Int) -> (String, Int)? {
        guard let point = word(lexemes, index), SpokenVocabulary.decimalPoints.contains(point) else { return nil }
        var digits = ""
        var used = 1
        while let next = lexeme(lexemes, index + used) {
            if case let .literal(text) = next, !text.contains(".") {
                digits += text
            } else if case let .word(text) = next, let unit = SpokenVocabulary.units[text] {
                digits += String(unit)
            } else if case let .word(text) = next, let teen = SpokenVocabulary.teens[text] {
                digits += String(teen)
            } else if case let .word(text) = next, let ten = SpokenVocabulary.tens[text] {
                let following = word(lexemes, index + used + 1).flatMap { SpokenVocabulary.units[$0] }
                if let unit = following, unit > 0 {
                    digits += String(ten + unit)
                    used += 1
                } else {
                    digits += String(ten)
                }
            } else {
                break
            }
            used += 1
        }
        return digits.isEmpty ? nil : (digits, used)
    }

    private static func startsSmallNumber(_ word: String?) -> Bool {
        guard let word else { return false }
        if let unit = SpokenVocabulary.units[word] {
            return unit > 0
        }
        return SpokenVocabulary.teens[word] != nil || SpokenVocabulary.tens[word] != nil
    }

    private static func isScale(_ word: String?) -> Bool {
        word.flatMap(scaleValue) != nil
    }

    private static func scaleValue(_ word: String) -> Int? {
        word == SpokenVocabulary.hundred ? 100 : SpokenVocabulary.scales[word]
    }
}
