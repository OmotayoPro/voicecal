import Foundation
import Observation

@Observable
final class CalculatorViewModel {
    let equation = Equation()

    /// Set when equals fails for a reason worth telling the user; cleared by the next input.
    private(set) var errorMessage: String?
    /// True right after equals, while the equation is just the result.
    private var isShowingResult = false

    /// The secondary line above the equation: an error, or the running result.
    var statusText: String? {
        if let errorMessage {
            return errorMessage
        }
        guard let result = equation.liveResult else { return nil }
        return "= " + Token.number(ResultFormatter.string(from: result)).displayText
    }

    func handle(_ key: KeypadKey) {
        errorMessage = nil
        let startsFresh = isShowingResult
        isShowingResult = false

        if let value = key.operatorValue {
            equation.typeOperator(value)
            return
        }
        switch key {
        case let .digit(value):
            if startsFresh {
                equation.clear()
            }
            equation.typeDigit(value)
        case .decimalPoint:
            if startsFresh {
                equation.clear()
            }
            equation.typeDecimalPoint()
        case .clear: equation.clear()
        case .backspace: equation.backspace()
        case .equals: evaluate()
        default: break // The mic arrives in build step 6.
        }
    }

    func tapToken(id: UUID) {
        isShowingResult = false
        equation.toggleEditing(id: id)
    }

    func tapGap(at index: Int) {
        isShowingResult = false
        equation.moveCursor(to: index)
    }

    /// Tapping empty display space ends any edit and returns the cursor to the end.
    func tapDisplayBackground() {
        equation.moveCursor(to: equation.tokens.count)
    }

    /// Solves the equation and collapses it to the result, so the user can keep calculating from it.
    func evaluate() {
        switch ExpressionEvaluator.evaluate(equation.tokens) {
        case let .success(value):
            equation.clear()
            equation.insert(.number(ResultFormatter.string(from: value)))
            isShowingResult = true
        case .failure(.divideByZero):
            errorMessage = "Can't divide by zero"
        case .failure(.overflow):
            errorMessage = "Number too large"
        case .failure(.malformed):
            break // Incomplete entry: leave it for the user to finish.
        }
    }
}
