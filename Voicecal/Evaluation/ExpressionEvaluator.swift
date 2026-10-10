import Foundation

enum EvaluationError: Error, Equatable {
    case divideByZero
    case malformed
    case overflow
}

/// Recursive-descent evaluator over tokens. `× ÷` bind tighter than `+ −`,
/// `%` divides the number before it by 100, and a leading `−` negates.
enum ExpressionEvaluator {
    static func evaluate(_ tokens: [Token]) -> Result<Decimal, EvaluationError> {
        var parser = Parser(tokens: tokens)
        do {
            let value = try parser.parseExpression()
            guard parser.isAtEnd else { return .failure(.malformed) }
            return .success(value)
        } catch let error as EvaluationError {
            return .failure(error)
        } catch {
            return .failure(.malformed)
        }
    }

    /// The tokens without any binary operators dangling at the end, for evaluating mid-entry.
    static func trimmingTrailingOperators(_ tokens: [Token]) -> [Token] {
        var trimmed = tokens
        while case let .op(_, value) = trimmed.last, value != .percent {
            trimmed.removeLast()
        }
        return trimmed
    }

    static func decimal(from text: String) -> Decimal? {
        var digits = text
        if digits.hasPrefix("-") {
            digits.removeFirst()
        }
        let parts = digits.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2,
              parts.allSatisfy({ $0.allSatisfy(\.isASCIIDigit) }),
              digits.contains(where: \.isASCIIDigit)
        else { return nil }
        return Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))
    }
}

private struct Parser {
    let tokens: [Token]
    private var position = 0

    init(tokens: [Token]) {
        self.tokens = tokens
    }

    var isAtEnd: Bool {
        position == tokens.count
    }

    mutating func parseExpression() throws -> Decimal {
        var value = try parseTerm()
        while let next = peekOperator(), next == .add || next == .subtract {
            position += 1
            let rhs = try parseTerm()
            value = try calculate(next == .add ? NSDecimalAdd : NSDecimalSubtract, value, rhs)
        }
        return value
    }

    private mutating func parseTerm() throws -> Decimal {
        var value = try parseUnary()
        while let next = peekOperator(), next == .multiply || next == .divide {
            position += 1
            let rhs = try parseUnary()
            value = try calculate(next == .multiply ? NSDecimalMultiply : NSDecimalDivide, value, rhs)
        }
        return value
    }

    private mutating func parseUnary() throws -> Decimal {
        if peekOperator() == .subtract {
            position += 1
            return try -parseUnary()
        }
        return try parsePostfix()
    }

    private mutating func parsePostfix() throws -> Decimal {
        guard position < tokens.count, case let .number(_, text) = tokens[position],
              var value = ExpressionEvaluator.decimal(from: text)
        else { throw EvaluationError.malformed }
        position += 1
        while peekOperator() == .percent {
            position += 1
            value = try calculate(NSDecimalDivide, value, 100)
        }
        return value
    }

    private func peekOperator() -> Operator? {
        guard position < tokens.count, case let .op(_, value) = tokens[position] else { return nil }
        return value
    }

    private typealias DecimalOperation = (
        UnsafeMutablePointer<Decimal>, UnsafePointer<Decimal>, UnsafePointer<Decimal>, NSDecimalNumber.RoundingMode
    ) -> NSDecimalNumber.CalculationError

    private func calculate(_ operation: DecimalOperation, _ lhs: Decimal, _ rhs: Decimal) throws -> Decimal {
        var result = Decimal()
        var lhs = lhs
        var rhs = rhs
        switch operation(&result, &lhs, &rhs, .plain) {
        case .noError, .lossOfPrecision: return result
        case .divideByZero: throw EvaluationError.divideByZero
        case .overflow, .underflow: throw EvaluationError.overflow
        @unknown default: throw EvaluationError.malformed
        }
    }
}
