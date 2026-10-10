import Testing
@testable import Voicecal

struct CalculatorViewModelTests {
    private func texts(_ viewModel: CalculatorViewModel) -> [String] {
        viewModel.equation.tokens.map(\.text)
    }

    private func makeViewModel(typing keys: KeypadKey...) -> CalculatorViewModel {
        let viewModel = CalculatorViewModel()
        keys.forEach(viewModel.handle)
        return viewModel
    }

    @Test func keysBuildAnEquation() {
        let viewModel = makeViewModel(
            typing: .digit(1), .digit(2), .add, .digit(3), .decimalPoint, .digit(5), .multiply, .digit(4)
        )
        #expect(texts(viewModel) == ["12", "+", "3.5", "×", "4"])
    }

    @Test(arguments: [
        (KeypadKey.add, "+"), (.subtract, "−"), (.multiply, "×"), (.divide, "÷"), (.percent, "%")
    ])
    func operatorKeysMapToTokens(key: KeypadKey, symbol: String) {
        let viewModel = makeViewModel(typing: .digit(5), key)
        #expect(texts(viewModel) == ["5", symbol])
    }

    @Test func backspaceAndClear() {
        let viewModel = makeViewModel(typing: .digit(1), .digit(2), .add, .backspace, .backspace)
        #expect(texts(viewModel) == ["1"])
        viewModel.handle(.clear)
        #expect(viewModel.equation.tokens.isEmpty)
    }

    @Test func tapTokenThenTypeCorrectsIt() {
        let viewModel = makeViewModel(typing: .digit(1), .digit(2), .add, .digit(3))
        viewModel.tapToken(id: viewModel.equation.tokens[0].id)
        viewModel.handle(.digit(7))
        #expect(texts(viewModel) == ["7", "+", "3"])
        #expect(viewModel.equation.editingTokenID == nil)
    }

    @Test func tapGapThenTypeInsertsThere() {
        let viewModel = makeViewModel(typing: .digit(1), .add, .digit(3))
        viewModel.tapGap(at: 0)
        viewModel.handle(.digit(9))
        viewModel.handle(.multiply)
        #expect(texts(viewModel) == ["9", "×", "1", "+", "3"])
    }

    @Test func tapDisplayBackgroundEndsEditingAndReturnsCursorToEnd() {
        let viewModel = makeViewModel(typing: .digit(1), .add, .digit(3))
        viewModel.tapToken(id: viewModel.equation.tokens[0].id)
        viewModel.tapDisplayBackground()
        #expect(viewModel.equation.editingTokenID == nil)
        #expect(viewModel.equation.cursorIndex == 3)
    }

    @Test func equalsAndMicDoNotChangeTheEquationYet() {
        let viewModel = makeViewModel(typing: .digit(1), .equals, .mic)
        #expect(texts(viewModel) == ["1"])
    }
}
