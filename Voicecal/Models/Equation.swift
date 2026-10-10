import Foundation
import Observation

/// The single source of truth for what the user has entered. Keypad and voice
/// both mutate it through the same methods, at the same cursor.
@Observable
final class Equation {
    private(set) var tokens: [Token] = []
    /// Insertion point; new tokens are inserted before this index.
    private(set) var cursorIndex = 0
    /// Token currently being corrected, if any.
    private(set) var editingTokenID: UUID?

    /// The value so far, ignoring a trailing operator. Nil until there is something to calculate.
    var liveResult: Decimal? {
        let candidates = ExpressionEvaluator.trimmingTrailingOperators(tokens)
        guard candidates.contains(where: { !$0.isNumber }) else { return nil }
        return try? ExpressionEvaluator.evaluate(candidates).get()
    }

    // MARK: - Whole-token mutations (voice and keypad)

    /// Inserts at the cursor. If a token of the same kind is being edited, replaces it instead.
    func insert(_ token: Token) {
        if let id = editingTokenID, let index = index(of: id), tokens[index].isNumber == token.isNumber {
            replace(id: id, with: token)
            return
        }
        editingTokenID = nil
        tokens.insert(token, at: cursorIndex)
        cursorIndex += 1
    }

    /// Swaps a token's value in place, keeping its id. Replacing the token being
    /// edited ends the edit and moves the cursor to just after it.
    func replace(id: UUID, with token: Token) {
        guard let index = index(of: id) else { return }
        tokens[index] = token.withID(id)
        if editingTokenID == id {
            editingTokenID = nil
            cursorIndex = index + 1
        }
    }

    func delete(id: UUID) {
        guard let index = index(of: id) else { return }
        tokens.remove(at: index)
        if index < cursorIndex {
            cursorIndex -= 1
        }
        if editingTokenID == id {
            editingTokenID = nil
        }
    }

    /// Deletes the token being edited, otherwise the last character before the cursor.
    func backspace() {
        if let id = editingTokenID {
            delete(id: id)
            return
        }
        guard cursorIndex > 0 else { return }
        let index = cursorIndex - 1
        if case let .number(id, text) = tokens[index] {
            let shortened = String(text.dropLast())
            if !shortened.isEmpty, shortened != "-" {
                tokens[index] = .number(id: id, text: shortened)
                return
            }
        }
        tokens.remove(at: index)
        cursorIndex -= 1
    }

    func clear() {
        tokens.removeAll()
        cursorIndex = 0
        editingTokenID = nil
    }

    // MARK: - Keypad typing

    /// Typing merges into the number before the cursor, so 1 then 2 gives "12".
    func typeDigit(_ digit: Int) {
        guard (0 ... 9).contains(digit) else { return }
        let character = String(digit)
        if replaceEditingNumber(with: character) {
            return
        }
        if let (id, text) = numberBeforeCursor {
            tokens[cursorIndex - 1] = .number(id: id, text: text == "0" ? character : text + character)
        } else {
            insert(.number(character))
        }
    }

    func typeDecimalPoint() {
        if replaceEditingNumber(with: "0.") {
            return
        }
        if let (id, text) = numberBeforeCursor {
            guard !text.contains(".") else { return }
            tokens[cursorIndex - 1] = .number(id: id, text: text + ".")
        } else {
            insert(.number("0."))
        }
    }

    /// Typing a binary operator straight after another one swaps it, so "5 + ×" becomes "5 ×".
    func typeOperator(_ value: Operator) {
        if let id = editingTokenID, let index = index(of: id), !tokens[index].isNumber {
            replace(id: id, with: .op(value))
            return
        }
        editingTokenID = nil
        if value != .percent, let (id, previous) = operatorBeforeCursor, previous != .percent {
            tokens[cursorIndex - 1] = .op(id: id, value)
        } else {
            insert(.op(value))
        }
    }

    // MARK: - Cursor and editing

    func moveCursor(to index: Int) {
        cursorIndex = min(max(index, 0), tokens.count)
        editingTokenID = nil
    }

    /// Starts editing a token; tapping the token already being edited cancels.
    func toggleEditing(id: UUID) {
        guard index(of: id) != nil else { return }
        editingTokenID = editingTokenID == id ? nil : id
    }

    func cancelEditing() {
        editingTokenID = nil
    }

    // MARK: - Helpers

    private func index(of id: UUID) -> Int? {
        tokens.firstIndex { $0.id == id }
    }

    private var numberBeforeCursor: (id: UUID, text: String)? {
        guard cursorIndex > 0, case let .number(id, text) = tokens[cursorIndex - 1] else { return nil }
        return (id, text)
    }

    private var operatorBeforeCursor: (id: UUID, value: Operator)? {
        guard cursorIndex > 0, case let .op(id, value) = tokens[cursorIndex - 1] else { return nil }
        return (id, value)
    }

    /// Returns true if a number token was being edited and has been replaced.
    /// Editing an operator is cancelled, so the typed character lands at the cursor.
    private func replaceEditingNumber(with text: String) -> Bool {
        guard let id = editingTokenID else { return false }
        if let index = index(of: id), tokens[index].isNumber {
            replace(id: id, with: .number(text))
            return true
        }
        editingTokenID = nil
        return false
    }
}
