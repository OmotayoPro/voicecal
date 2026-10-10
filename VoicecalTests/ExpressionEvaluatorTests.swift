import Foundation
import Testing
@testable import Voicecal

struct ExpressionEvaluatorTests {
    @Test(arguments: [
        ("5", "5"),
        ("1 + 2", "3"),
        ("10 − 4", "6"),
        ("6 × 7", "42"),
        ("9 ÷ 2", "4.5"),
        ("2 + 3 × 4", "14"),
        ("2 × 3 + 4", "10"),
        ("20 − 6 ÷ 3", "18"),
        ("10 − 2 − 3", "5"),
        ("100 ÷ 5 ÷ 2", "10"),
        ("0.1 + 0.2", "0.3"),
        ("12. + 3", "15"),
        ("0. + 1", "1"),
        ("50 %", "0.5"),
        ("200 × 10 %", "20"),
        ("50 % %", "0.005"),
        ("-5 + 8", "3"),
        ("3 × -2", "-6"),
        ("− 5 + 8", "3"),
        ("3 × − 2", "-6"),
        ("− − 4", "4"),
        ("999999999 × 999999999", "999999998000000001")
    ])
    func evaluates(expression: String, expected: String) {
        #expect(ExpressionEvaluator.evaluate(tokens(expression)) == .success(decimal(expected)))
    }

    @Test(arguments: [
        "", "+", "5 +", "5 + × 3", "5 5", "% 5", "5 ÷", "×", ".", "-", "1.2.3", "12a"
    ])
    func malformed(expression: String) {
        #expect(ExpressionEvaluator.evaluate(tokens(expression)) == .failure(.malformed))
    }

    @Test(arguments: ["5 ÷ 0", "5 ÷ 0.0", "1 + 4 ÷ 0 %"])
    func divideByZero(expression: String) {
        #expect(ExpressionEvaluator.evaluate(tokens(expression)) == .failure(.divideByZero))
    }

    @Test func overflow() {
        let huge = String(repeating: "9", count: 38)
        var expression = huge
        for _ in 0 ..< 6 {
            expression += " × " + huge
        }
        #expect(ExpressionEvaluator.evaluate(tokens(expression)) == .failure(.overflow))
    }

    @Test func trimsDanglingBinaryOperatorsButKeepsPercent() {
        #expect(ExpressionEvaluator.trimmingTrailingOperators(tokens("5 + 3 ×")).map(\.text) == ["5", "+", "3"])
        #expect(ExpressionEvaluator.trimmingTrailingOperators(tokens("5 + −")).map(\.text) == ["5"])
        #expect(ExpressionEvaluator.trimmingTrailingOperators(tokens("50 %")).map(\.text) == ["50", "%"])
    }

    @Test(arguments: [
        ("45.5", "45.5"), ("3", "3"), ("-6", "-6"), ("0.30", "0.3"),
        ("0.33333333333333333", "0.3333333333"), ("0.66666666666666666", "0.6666666667"),
        ("100000000000000000000", "100000000000000000000")
    ])
    func formatsResults(value: String, expected: String) {
        #expect(ResultFormatter.string(from: decimal(value)) == expected)
    }
}

struct LiveResultTests {
    private func equation(_ expression: String) -> Equation {
        let equation = Equation()
        tokens(expression).forEach(equation.insert)
        return equation
    }

    @Test func nilUntilThereIsSomethingToCalculate() {
        #expect(equation("").liveResult == nil)
        #expect(equation("12").liveResult == nil)
        #expect(equation("12 +").liveResult == nil)
    }

    @Test func updatesAndIgnoresTrailingOperator() {
        #expect(equation("12 + 3").liveResult == 15)
        #expect(equation("12 + 3 ×").liveResult == 15)
        #expect(equation("50 %").liveResult == decimal("0.5"))
    }

    @Test func nilRatherThanAnErrorMidEntry() {
        #expect(equation("5 ÷ 0").liveResult == nil)
        #expect(equation("5 5 +").liveResult == nil)
    }
}
