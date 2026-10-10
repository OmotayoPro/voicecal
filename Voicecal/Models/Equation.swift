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
    /// Tokens from speech that the recognizer may still revise. They sit just before the cursor.
    private(set) var pendingTokenIDs: Set<UUID> = []
    /// True right after equals, while the equation is only the result. The next number
    /// starts a new equation; an operator continues from the result.
    private(set) var isShowingResult = false

    /// The value so far, ignoring a trailing operator. Nil until there is something to calculate.
    var liveResult: Decimal? {
        let candidates = ExpressionEvaluator.trimmingTrailingOperators(tokens)
        guard candidates.contains(where: { !$0.isNumber }) else { return nil }
        return try? ExpressionEvaluator.evaluate(candidates).get()
    }

    // MARK: - Whole-token mutations (voice and keypad)

    /// Inserts at the cursor. If a token of the same kind is being edited, replaces it instead.
    func insert(_ token: Token) {
        if token.isNumber {
            startFreshIfShowingResult()
        }
        isShowingResult = false
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
        isShowingResult = false
        tokens[index] = token.withID(id)
        if editingTokenID == id {
            editingTokenID = nil
            cursorIndex = index + 1
        }
    }

    func delete(id: UUID) {
        guard let index = index(of: id) else { return }
        isShowingResult = false
        tokens.remove(at: index)
        pendingTokenIDs.remove(id)
        if index < cursorIndex {
            cursorIndex -= 1
        }
        if editingTokenID == id {
            editingTokenID = nil
        }
    }

    /// Deletes the token being edited, otherwise the last character before the cursor.
    func backspace() {
        isShowingResult = false
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
        delete(id: tokens[index].id)
    }

    /// Removes the whole token before the cursor (the voice "delete" command).
    func deleteTokenBeforeCursor() {
        guard cursorIndex > 0 else { return }
        delete(id: tokens[cursorIndex - 1].id)
    }

    func clear() {
        tokens.removeAll()
        cursorIndex = 0
        editingTokenID = nil
        pendingTokenIDs.removeAll()
        isShowingResult = false
    }

    /// Collapses the equation to a single result token.
    func showResult(_ text: String) {
        clear()
        insert(.number(text))
        isShowingResult = true
    }

    // MARK: - Dictation

    /// True when the tokens ahead of the in-flight dictation end in a value, so a spoken
    /// "minus" there means subtraction.
    var endsInOperandBeforePending: Bool {
        guard !isShowingResult || !pendingTokenIDs.isEmpty else { return true }
        let committed = tokens[..<cursorIndex].last { !pendingTokenIDs.contains($0.id) }
        guard let committed else { return false }
        if case let .op(_, value) = committed {
            return value == .percent
        }
        return true
    }

    /// Replaces the in-flight dictation tokens wholesale with a new reading of the same speech.
    func setPending(_ newTokens: [Token]) {
        removePending()
        var ids: Set<UUID> = []
        for token in newTokens {
            insert(token)
            // `insert` may have replaced an edited token in place, which keeps that token's id.
            ids.insert(tokens[cursorIndex - 1].id)
        }
        pendingTokenIDs = ids
    }

    /// Makes the in-flight dictation tokens permanent.
    func commitPending() {
        pendingTokenIDs.removeAll()
    }

    private func removePending() {
        guard !pendingTokenIDs.isEmpty else { return }
        let removedBeforeCursor = tokens[..<cursorIndex].filter { pendingTokenIDs.contains($0.id) }.count
        tokens.removeAll { pendingTokenIDs.contains($0.id) }
        cursorIndex -= removedBeforeCursor
        pendingTokenIDs.removeAll()
    }

    // MARK: - Keypad typing

    /// Typing merges into the number before the cursor, so 1 then 2 gives "12".
    func typeDigit(_ digit: Int) {
        guard (0 ... 9).contains(digit) else { return }
        startFreshIfShowingResult()
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
        startFreshIfShowingResult()
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
        isShowingResult = false
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
        isShowingResult = false
    }

    /// Starts editing a token; tapping the token already being edited cancels.
    func toggleEditing(id: UUID) {
        guard index(of: id) != nil else { return }
        editingTokenID = editingTokenID == id ? nil : id
        isShowingResult = false
    }

    func cancelEditing() {
        editingTokenID = nil
    }

    // MARK: - Helpers

    private func index(of id: UUID) -> Int? {
        tokens.firstIndex { $0.id == id }
    }

    private func startFreshIfShowingResult() {
        if isShowingResult {
            clear()
        }
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
