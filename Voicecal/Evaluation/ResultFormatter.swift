import Foundation

enum ResultFormatter {
    static let maxFractionDigits = 10

    /// Plain digits with a "." separator, e.g. "45.5" or "-0.3333333333". Suitable as a number token's text.
    static func string(from value: Decimal) -> String {
        var rounded = Decimal()
        var input = value
        NSDecimalRound(&rounded, &input, maxFractionDigits, .plain)
        return NSDecimalNumber(decimal: rounded).description(withLocale: Locale(identifier: "en_US_POSIX"))
    }
}
