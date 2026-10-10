import Foundation

/// Turns a stream of revisable transcripts into equation tokens.
///
/// The recognizer keeps rewriting its transcript ("to" becomes "two" becomes "twelve"), so nothing
/// is appended from a partial result. Instead the words not yet committed are re-parsed on every
/// update and shown as pending tokens, replaced wholesale each time. A commit makes them permanent
/// and marks those words as consumed, so they are never parsed again.
@MainActor
final class DictationSession {
    /// Called for spoken commands ("clear", "delete", "equals") when they are committed.
    var onCommand: ((VoiceCommand) -> Void)?

    private let equation: Equation
    /// The latest transcript of the current recognition task, split into words and symbols.
    private var heard: [Lexeme] = []
    /// How many of `heard` are already committed. Counted in words rather than characters,
    /// so the recognizer reformatting spaces or punctuation does not shift it.
    private var consumedCount = 0

    init(equation: Equation) {
        self.equation = equation
    }

    var hasUncommittedSpeech: Bool {
        consumedCount < heard.count
    }

    /// Feeds a new partial result. Returns true if what was heard actually changed.
    @discardableResult
    func update(transcript: String) -> Bool {
        let lexemes = TranscriptLexer.lex(transcript)
        guard lexemes != heard else { return false }
        heard = lexemes
        consumedCount = min(consumedCount, heard.count)
        equation.setPending(uncommittedItems.compactMap(\.token))
        return true
    }

    /// Makes pending tokens permanent and runs any spoken commands. Called when the recognizer
    /// finalizes, after a short pause in speech, and before every manual edit.
    func commit() {
        let items = uncommittedItems
        consumedCount = heard.count
        if items.contains(where: { $0.token == nil }) {
            // Commands act on the equation in spoken order, so replay everything in sequence.
            equation.setPending([])
            for item in items {
                if let token = item.token {
                    equation.insert(token)
                } else if case let .command(command) = item {
                    onCommand?(command)
                }
            }
        }
        equation.commitPending()
    }

    /// The recognizer has started a new task, whose transcript begins from empty.
    func startNewSegment() {
        commit()
        heard = []
        consumedCount = 0
    }

    private var uncommittedItems: [ParsedItem] {
        SpokenPhraseParser.parse(
            heard,
            from: consumedCount,
            startsAfterOperand: equation.endsInOperandBeforePending
        )
    }
}

private extension ParsedItem {
    var token: Token? {
        switch self {
        case let .number(text): .number(text)
        case let .op(value): .op(value)
        case .command: nil
        }
    }
}
