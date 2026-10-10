import Foundation
import Testing
@testable import Voicecal

struct EquationTests {
    private func makeEquation(_ tokens: Token...) -> Equation {
        let equation = Equation()
        tokens.forEach(equation.insert)
        return equation
    }

    private func texts(_ equation: Equation) -> [String] {
        equation.tokens.map(\.text)
    }

    // MARK: Insert

    @Test func insertAppendsAndAdvancesCursor() {
        let equation = makeEquation(.number("12"), .op(.add), .number("3"))
        #expect(texts(equation) == ["12", "+", "3"])
        #expect(equation.cursorIndex == 3)
    }

    @Test func insertHappensAtCursor() {
        let equation = makeEquation(.number("1"), .number("3"))
        equation.moveCursor(to: 1)
        equation.insert(.op(.add))
        #expect(texts(equation) == ["1", "+", "3"])
        #expect(equation.cursorIndex == 2)
    }

    @Test func insertReplacesEditedTokenOfSameKind() {
        let equation = makeEquation(.number("12"), .op(.add), .number("3"))
        let target = equation.tokens[0]
        equation.toggleEditing(id: target.id)
        equation.insert(.number("15"))
        #expect(texts(equation) == ["15", "+", "3"])
        #expect(equation.tokens[0].id == target.id)
        #expect(equation.editingTokenID == nil)
        #expect(equation.cursorIndex == 1)
    }

    @Test func insertOfDifferentKindCancelsEditingAndInsertsAtCursor() {
        let equation = makeEquation(.number("12"), .op(.add))
        equation.toggleEditing(id: equation.tokens[1].id)
        equation.insert(.number("7"))
        #expect(texts(equation) == ["12", "+", "7"])
        #expect(equation.editingTokenID == nil)
    }

    // MARK: Replace and delete

    @Test func replaceKeepsPositionAndID() {
        let equation = makeEquation(.number("1"), .op(.add), .number("2"))
        let target = equation.tokens[1]
        equation.replace(id: target.id, with: .op(.multiply))
        #expect(texts(equation) == ["1", "×", "2"])
        #expect(equation.tokens[1].id == target.id)
        #expect(equation.cursorIndex == 3)
    }

    @Test func replaceUnknownIDDoesNothing() {
        let equation = makeEquation(.number("1"))
        equation.replace(id: UUID(), with: .number("9"))
        #expect(texts(equation) == ["1"])
    }

    @Test func deleteBeforeCursorShiftsCursorBack() {
        let equation = makeEquation(.number("1"), .op(.add), .number("2"))
        equation.delete(id: equation.tokens[0].id)
        #expect(texts(equation) == ["+", "2"])
        #expect(equation.cursorIndex == 2)
    }

    @Test func deleteAfterCursorLeavesCursor() {
        let equation = makeEquation(.number("1"), .op(.add), .number("2"))
        equation.moveCursor(to: 1)
        equation.delete(id: equation.tokens[2].id)
        #expect(texts(equation) == ["1", "+"])
        #expect(equation.cursorIndex == 1)
    }

    @Test func deleteEditedTokenEndsEditing() {
        let equation = makeEquation(.number("1"), .op(.add))
        let target = equation.tokens[0]
        equation.toggleEditing(id: target.id)
        equation.delete(id: target.id)
        #expect(equation.editingTokenID == nil)
    }

    // MARK: Backspace

    @Test func backspaceTrimsLastDigitThenRemovesToken() {
        let equation = makeEquation(.number("12"))
        equation.backspace()
        #expect(texts(equation) == ["1"])
        equation.backspace()
        #expect(equation.tokens.isEmpty)
        #expect(equation.cursorIndex == 0)
    }

    @Test func backspaceRemovesOperatorWhole() {
        let equation = makeEquation(.number("1"), .op(.add))
        equation.backspace()
        #expect(texts(equation) == ["1"])
        #expect(equation.cursorIndex == 1)
    }

    @Test func backspaceRemovesNegativeNumberInsteadOfLeavingBareSign() {
        let equation = makeEquation(.number("-5"))
        equation.backspace()
        #expect(equation.tokens.isEmpty)
    }

    @Test func backspaceActsOnTokenBeforeCursor() {
        let equation = makeEquation(.number("12"), .op(.add), .number("34"))
        equation.moveCursor(to: 1)
        equation.backspace()
        #expect(texts(equation) == ["1", "+", "34"])
    }

    @Test func backspaceAtStartDoesNothing() {
        let equation = makeEquation(.number("1"))
        equation.moveCursor(to: 0)
        equation.backspace()
        #expect(texts(equation) == ["1"])
    }

    @Test func backspaceDeletesTokenBeingEdited() {
        let equation = makeEquation(.number("12"), .op(.add), .number("3"))
        equation.toggleEditing(id: equation.tokens[0].id)
        equation.backspace()
        #expect(texts(equation) == ["+", "3"])
        #expect(equation.editingTokenID == nil)
    }

    // MARK: Typing

    @Test func typedDigitsMergeIntoOneNumber() {
        let equation = Equation()
        equation.typeDigit(1)
        equation.typeDigit(2)
        #expect(texts(equation) == ["12"])
        #expect(equation.cursorIndex == 1)
    }

    @Test func typedDigitReplacesLoneZero() {
        let equation = Equation()
        equation.typeDigit(0)
        equation.typeDigit(0)
        equation.typeDigit(5)
        #expect(texts(equation) == ["5"])
    }

    @Test func typedDigitAfterOperatorStartsNewNumber() {
        let equation = makeEquation(.number("1"), .op(.add))
        equation.typeDigit(2)
        #expect(texts(equation) == ["1", "+", "2"])
    }

    @Test func typedDigitAppendsToVoiceNumberBeforeCursor() {
        let equation = makeEquation(.number("25"))
        equation.typeDigit(0)
        #expect(texts(equation) == ["250"])
    }

    @Test func outOfRangeDigitIsIgnored() {
        let equation = Equation()
        equation.typeDigit(10)
        equation.typeDigit(-1)
        #expect(equation.tokens.isEmpty)
    }

    @Test func decimalPointStates() {
        let equation = Equation()
        equation.typeDecimalPoint()
        #expect(texts(equation) == ["0."])
        equation.typeDigit(0)
        equation.typeDigit(5)
        #expect(texts(equation) == ["0.05"])
        equation.typeDecimalPoint()
        #expect(texts(equation) == ["0.05"])
    }

    @Test func decimalPointAppendsToExistingNumber() {
        let equation = makeEquation(.number("12"))
        equation.typeDecimalPoint()
        #expect(texts(equation) == ["12."])
    }

    @Test func typingWhileEditingNumberReplacesItThenKeepsTyping() {
        let equation = makeEquation(.number("12"), .op(.add), .number("3"))
        equation.toggleEditing(id: equation.tokens[0].id)
        equation.typeDigit(4)
        equation.typeDigit(5)
        #expect(texts(equation) == ["45", "+", "3"])
        #expect(equation.editingTokenID == nil)
        #expect(equation.cursorIndex == 1)
    }

    @Test func typingOperatorWhileEditingOperatorSwapsIt() {
        let equation = makeEquation(.number("1"), .op(.add), .number("2"))
        let target = equation.tokens[1]
        equation.toggleEditing(id: target.id)
        equation.typeOperator(.divide)
        #expect(texts(equation) == ["1", "÷", "2"])
        #expect(equation.tokens[1].id == target.id)
        #expect(equation.cursorIndex == 2)
    }

    @Test func typingDigitWhileEditingOperatorCancelsEditAndTypesAtCursor() {
        let equation = makeEquation(.number("1"), .op(.add), .number("2"))
        equation.toggleEditing(id: equation.tokens[1].id)
        equation.typeDigit(3)
        #expect(texts(equation) == ["1", "+", "23"])
        #expect(equation.editingTokenID == nil)
    }

    @Test func consecutiveBinaryOperatorsSwap() {
        let equation = makeEquation(.number("5"))
        equation.typeOperator(.add)
        equation.typeOperator(.multiply)
        #expect(texts(equation) == ["5", "×"])
    }

    @Test func percentThenOperatorKeepsBoth() {
        let equation = makeEquation(.number("50"))
        equation.typeOperator(.percent)
        equation.typeOperator(.add)
        #expect(texts(equation) == ["50", "%", "+"])
    }

    // MARK: Cursor and editing

    @Test func moveCursorClampsToBounds() {
        let equation = makeEquation(.number("1"), .op(.add))
        equation.moveCursor(to: 99)
        #expect(equation.cursorIndex == 2)
        equation.moveCursor(to: -4)
        #expect(equation.cursorIndex == 0)
    }

    @Test func moveCursorCancelsEditing() {
        let equation = makeEquation(.number("1"))
        equation.toggleEditing(id: equation.tokens[0].id)
        equation.moveCursor(to: 0)
        #expect(equation.editingTokenID == nil)
    }

    @Test func toggleEditingTwiceCancels() {
        let equation = makeEquation(.number("1"))
        let id = equation.tokens[0].id
        equation.toggleEditing(id: id)
        #expect(equation.editingTokenID == id)
        equation.toggleEditing(id: id)
        #expect(equation.editingTokenID == nil)
    }

    @Test func toggleEditingUnknownIDIsIgnored() {
        let equation = makeEquation(.number("1"))
        equation.toggleEditing(id: UUID())
        #expect(equation.editingTokenID == nil)
    }

    @Test func clearResetsEverything() {
        let equation = makeEquation(.number("1"), .op(.add))
        equation.toggleEditing(id: equation.tokens[0].id)
        equation.clear()
        #expect(equation.tokens.isEmpty)
        #expect(equation.cursorIndex == 0)
        #expect(equation.editingTokenID == nil)
    }
}
