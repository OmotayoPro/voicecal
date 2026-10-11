import Foundation

/// Turns a result into words for the synthesizer: 45.5 -> "forty-five point five".
enum SpokenResultFormatter {
    /// The same precision the result is displayed with.
    static let maxFractionDigits = ResultFormatter.maxFractionDigits
    /// Beyond this, words become unlistenable, so the digits are handed to the synthesizer as they are.
    private static let largestSpelledOut = Decimal(sign: .plus, exponent: 15, significand: 1)

    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        formatter.locale = Locale(identifier: "en_US")
        formatter.maximumFractionDigits = maxFractionDigits
        return formatter
    }()

    static func phrase(for value: Decimal) -> String {
        var rounded = Decimal()
        var input = value
        NSDecimalRound(&rounded, &input, maxFractionDigits, .plain)

        let magnitude = abs(rounded)
        let words = magnitude < largestSpelledOut
            ? formatter.string(from: NSDecimalNumber(decimal: magnitude))
            : nil
        let spoken = words ?? ResultFormatter.string(from: magnitude)
        return rounded < 0 ? "minus " + spoken : spoken
    }
}
