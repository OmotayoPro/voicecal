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
    /// A committed number that pending speech is currently extending, as it was before, so a
    /// revised transcript can take those digits back.
    private var extendedNumber: (id: UUID, text: String)?

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
        extendedNumber = nil
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
        var remaining = newTokens[...]
        if let first = remaining.first, let extended = extending(with: first) {
            // Digits spoken after a pause carry on the number already there.
            extendedNumber = (extended.id, tokens[extended.index].text)
            tokens[extended.index] = .number(id: extended.id, text: extended.text)
            remaining = remaining.dropFirst()
        }
        for token in remaining {
            insert(Self.withoutLeadingZeros(token))
            // `insert` may have replaced an edited token in place, which keeps that token's id.
            ids.insert(tokens[cursorIndex - 1].id)
        }
        pendingTokenIDs = ids
    }

    /// Makes the in-flight dictation tokens permanent.
    func commitPending() {
        pendingTokenIDs.removeAll()
        extendedNumber = nil
    }

    /// Inserts a spoken token for good. A number spoken straight after another number, with no
    /// operator between, carries that number on ("15" then "0" is 150) instead of sitting beside it,
    /// which is how a figure read out digit by digit arrives when the speaker pauses.
    func insertSpoken(_ token: Token) {
        if let extended = extending(with: token) {
            tokens[extended.index] = .number(id: extended.id, text: extended.text)
        } else {
            insert(Self.withoutLeadingZeros(token))
        }
    }

    private struct NumberExtension {
        let index: Int
        let id: UUID
        let text: String
    }

    /// The number before the cursor with `token`'s digits added, if `token` can extend it.
    private func extending(with token: Token) -> NumberExtension? {
        guard editingTokenID == nil, !isShowingResult,
              case let .number(_, spoken) = token, spoken.allSatisfy(\.isASCIIDigit),
              let (id, text) = numberBeforeCursor, !pendingTokenIDs.contains(id)
        else { return nil }
        return NumberExtension(index: cursorIndex - 1, id: id, text: Self.withoutLeadingZeros(text + spoken))
    }

    /// "007" is 7 and "00.5" is 0.5. Digits after the decimal point are left alone.
    private static func withoutLeadingZeros(_ text: String) -> String {
        let sign = text.hasPrefix("-") ? "-" : ""
        let unsigned = text.dropFirst(sign.count)
        let whole = unsigned.prefix { $0 != "." }
        let rest = unsigned.dropFirst(whole.count)
        let trimmed = whole.drop { $0 == "0" }
        return sign + (trimmed.isEmpty && !whole.isEmpty ? "0" : String(trimmed)) + rest
    }

    private static func withoutLeadingZeros(_ token: Token) -> Token {
        guard case let .number(id, text) = token else { return token }
        return .number(id: id, text: withoutLeadingZeros(text))
    }

    private func removePending() {
        if let original = extendedNumber, let index = index(of: original.id) {
            tokens[index] = .number(id: original.id, text: original.text)
        }
        extendedNumber = nil
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
