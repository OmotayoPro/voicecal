import Foundation
import Observation

@Observable
final class CalculatorViewModel {
    let equation = Equation()

    func handle(_ key: KeypadKey) {
        switch key {
        case let .digit(value): equation.typeDigit(value)
        case .decimalPoint: equation.typeDecimalPoint()
        case .add: equation.typeOperator(.add)
        case .subtract: equation.typeOperator(.subtract)
        case .multiply: equation.typeOperator(.multiply)
        case .divide: equation.typeOperator(.divide)
        case .percent: equation.typeOperator(.percent)
        case .clear: equation.clear()
        case .backspace: equation.backspace()
        case .equals, .mic: break // Build steps 4 and 6.
        }
    }

    func tapToken(id: UUID) {
        equation.toggleEditing(id: id)
    }

    func tapGap(at index: Int) {
        equation.moveCursor(to: index)
    }

    /// Tapping empty display space ends any edit and returns the cursor to the end.
    func tapDisplayBackground() {
        equation.moveCursor(to: equation.tokens.count)
    }
}
