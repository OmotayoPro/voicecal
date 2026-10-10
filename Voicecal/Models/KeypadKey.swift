import Foundation

enum KeypadKey: Hashable {
    case digit(Int)
    case decimalPoint
    case add
    case subtract
    case multiply
    case divide
    case percent
    case equals
    case clear
    case backspace
    case mic

    /// Rows top to bottom, as laid out in the design.
    static let layout: [[KeypadKey]] = [
        [.backspace, .clear, .percent, .divide],
        [.digit(7), .digit(8), .digit(9), .multiply],
        [.digit(4), .digit(5), .digit(6), .subtract],
        [.digit(1), .digit(2), .digit(3), .add],
        [.mic, .digit(0), .decimalPoint, .equals]
    ]
}
