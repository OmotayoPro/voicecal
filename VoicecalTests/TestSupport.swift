import Foundation
@testable import Voicecal

/// Builds tokens from a spaced string such as "12 + 3 × 4".
func tokens(_ expression: String) -> [Token] {
    expression.split(separator: " ").map { part in
        if let value = Operator(rawValue: String(part)) {
            Token.op(value)
        } else {
            Token.number(String(part))
        }
    }
}

func decimal(_ text: String) -> Decimal {
    Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) ?? .nan
}
