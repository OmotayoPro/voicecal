import Foundation

enum Operator: String, CaseIterable {
    case add = "+"
    case subtract = "−"
    case multiply = "×"
    case divide = "÷"
    case percent = "%"
}

enum Token: Identifiable, Equatable {
    /// `text` stays a String so in-progress states like "12." and "0.0" are valid.
    case number(id: UUID, text: String)
    case op(id: UUID, Operator) // swiftlint:disable:this identifier_name

    static func number(_ text: String) -> Token {
        .number(id: UUID(), text: text)
    }

    static func op(_ value: Operator) -> Token {
        .op(id: UUID(), value)
    }

    var id: UUID {
        switch self {
        case let .number(id, _), let .op(id, _): id
        }
    }

    /// What the token shows in the equation row.
    var text: String {
        switch self {
        case let .number(_, text): text
        case let .op(_, value): value.rawValue
        }
    }

    /// `text` as shown on screen: digits grouped in threes and a typographic minus, e.g. "−1,234.5".
    var displayText: String {
        guard case let .number(_, text) = self else { return text }
        let isNegative = text.hasPrefix("-")
        let parts = text.dropFirst(isNegative ? 1 : 0).split(
            separator: ".", maxSplits: 1, omittingEmptySubsequences: false
        )
        var grouped = ""
        for (offset, digit) in (parts.first ?? "").reversed().enumerated() {
            if offset > 0, offset.isMultiple(of: 3) {
                grouped.append(",")
            }
            grouped.append(digit)
        }
        let fraction = parts.count > 1 ? "." + parts[1] : ""
        return (isNegative ? "−" : "") + String(grouped.reversed()) + fraction
    }

    var isNumber: Bool {
        if case .number = self {
            true
        } else {
            false
        }
    }

    /// The same value under a different identity, used to keep a token's id stable when it is replaced.
    func withID(_ id: UUID) -> Token {
        switch self {
        case let .number(_, text): .number(id: id, text: text)
        case let .op(_, value): .op(id: id, value)
        }
    }
}
