import Foundation

/// Every word the voice path understands, in one place so it is easy to extend
/// (and, later, to swap per locale).
enum SpokenVocabulary {
    private static let unitNames: [String: Int] = [
        "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4,
        "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9
    ]

    /// Other ways a single digit is said or, more often, heard. These always count as the digit:
    /// in a calculator nobody means "ate" or "tree", so there is no ordinary speech to protect.
    private static let heardAsUnits: [String: Int] = [
        "oh": 0, "o": 0,
        "wan": 1,
        "tu": 2,
        "tree": 3, "tri": 3, "free": 3,
        "fife": 5,
        "sis": 6, "sex": 6, "sicks": 6,
        "ate": 8, "hate": 8, "ait": 8,
        "nein": 9
    ]

    /// Every word that stands for a single digit.
    static let units = unitNames.merging(heardAsUnits) { name, _ in name }
    static let teens: [String: Int] = [
        "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14,
        "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19
    ]
    static let tens: [String: Int] = [
        "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50,
        "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90
    ]
    static let scales: [String: Int] = ["thousand": 1000, "million": 1_000_000]
    /// "double five" is 55.
    static let repeats: [String: Int] = ["double": 2, "triple": 3]
    static let hundred = "hundred"
    static let decimalPoints: Set<String> = ["point", "dot"]
    static let negative = "negative"

    /// Words the recognizer commonly hears instead of a number, but which are also common words
    /// in their own right. Applied only next to a number or operator.
    static let mishears: [String: String] = [
        "to": "two", "too": "two", "for": "four", "fore": "four", "won": "one"
    ]

    /// Longest phrases first within each starting word is handled by the parser.
    static let phrases: [[String]: ParsedItem] = [
        ["plus"]: .op(.add),
        ["add"]: .op(.add),
        ["minus"]: .op(.subtract),
        ["subtract"]: .op(.subtract),
        ["take", "away"]: .op(.subtract),
        ["times"]: .op(.multiply),
        ["multiplied", "by"]: .op(.multiply),
        ["multiplied"]: .op(.multiply),
        ["multiply", "by"]: .op(.multiply),
        ["multiply"]: .op(.multiply),
        ["multiples"]: .op(.multiply),
        ["multiple"]: .op(.multiply),
        ["x"]: .op(.multiply),
        ["ex"]: .op(.multiply),
        ["divided", "by"]: .op(.divide),
        ["divided"]: .op(.divide),
        ["divide", "by"]: .op(.divide),
        ["divide"]: .op(.divide),
        ["over"]: .op(.divide),
        ["percent"]: .op(.percent),
        ["clear"]: .command(.clear),
        ["clear", "all"]: .command(.clear),
        ["delete"]: .command(.deleteLast),
        ["scratch", "that"]: .command(.deleteLast),
        ["undo"]: .command(.deleteLast),
        ["equals"]: .command(.equals),
        ["equal"]: .command(.equals),
        ["calculate"]: .command(.equals),
        ["what's", "the", "answer"]: .command(.equals),
        ["whats", "the", "answer"]: .command(.equals),
        ["what", "is", "the", "answer"]: .command(.equals)
    ]

    static let symbols: [Character: ParsedItem] = [
        "+": .op(.add), "−": .op(.subtract), "×": .op(.multiply),
        "÷": .op(.divide), "%": .op(.percent), "=": .command(.equals)
    ]

    static let longestPhrase = phrases.keys.map(\.count).max() ?? 1

    static func isNumberWord(_ word: String) -> Bool {
        units[word] != nil || teens[word] != nil || tens[word] != nil || scales[word] != nil
            || word == hundred || decimalPoints.contains(word) || repeats[word] != nil
    }

    /// Every word that appears in an operator phrase ("divided", "by", "times"...).
    private static let operatorWords: Set<String> = Set(
        phrases.filter {
            if case .op = $0.value {
                true
            } else {
                false
            }
        }.keys.joined()
    )

    /// Words that suggest the speaker is doing math, used to decide when a mishear applies.
    static func isMathWord(_ word: String) -> Bool {
        isNumberWord(word) || word == negative || operatorWords.contains(word)
    }

    /// Hints for the recognizer.
    static var contextualStrings: [String] {
        // Only the proper names of digits: hinting "ate" or "tree" would invite those mishearings.
        Array(unitNames.keys) + Array(teens.keys) + Array(tens.keys) + Array(scales.keys)
            + [hundred, negative] + Array(decimalPoints) + phrases.keys.map { $0.joined(separator: " ") }
    }
}
