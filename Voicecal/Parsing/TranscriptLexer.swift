import Foundation

enum Lexeme: Equatable {
    case word(String)
    /// Digits the recognizer already wrote out, e.g. "12" or "3.5" (grouping commas removed).
    case literal(String)
    /// One of + − × ÷ % =
    case symbol(Character)
}

/// Splits a transcript into words, digit literals and math symbols. Everything else is dropped.
enum TranscriptLexer {
    private static let symbols: [Character: Character] = [
        "+": "+", "×": "×", "*": "×", "÷": "÷", "/": "÷", "%": "%", "=": "="
    ]
    private static let dashes: Set<Character> = ["-", "−", "–", "—"]
    private static let apostrophes: Set<Character> = ["'", "’"]

    static func lex(_ transcript: String) -> [Lexeme] {
        var scanner = Scanner(characters: Array(transcript.lowercased()))
        var lexemes: [Lexeme] = []
        while let current = scanner.peek() {
            if current.isASCIIDigit || (current == "." && scanner.isDigit(at: 1)) {
                lexemes.append(.literal(scanner.readNumber()))
            } else if current.isLetter {
                lexemes.append(.word(scanner.readWord()))
            } else {
                // A dash between letters is a hyphen ("twenty-five"), not a minus.
                if dashes.contains(current), !scanner.isBetweenLetters {
                    lexemes.append(.symbol("−"))
                } else if let symbol = symbols[current] {
                    lexemes.append(.symbol(symbol))
                }
                scanner.advance()
            }
        }
        return lexemes
    }

    private struct Scanner {
        let characters: [Character]
        private var index = 0

        init(characters: [Character]) {
            self.characters = characters
        }

        func peek(_ offset: Int = 0) -> Character? {
            characters.indices.contains(index + offset) ? characters[index + offset] : nil
        }

        func isDigit(at offset: Int) -> Bool {
            peek(offset)?.isASCIIDigit ?? false
        }

        var isBetweenLetters: Bool {
            (peek(-1)?.isLetter ?? false) && (peek(1)?.isLetter ?? false)
        }

        mutating func advance() {
            index += 1
        }

        /// Digits with grouping commas removed and an optional fraction; ".5" becomes "0.5".
        mutating func readNumber() -> String {
            var text = ""
            while let next = peek(), next.isASCIIDigit || (next == "," && isDigit(at: 1)) {
                if next != "," {
                    text.append(next)
                }
                advance()
            }
            if peek() == ".", isDigit(at: 1) {
                text += text.isEmpty ? "0." : "."
                advance()
                while let next = peek(), next.isASCIIDigit {
                    text.append(next)
                    advance()
                }
            }
            return text
        }

        mutating func readWord() -> String {
            var text = ""
            while let next = peek(), next.isLetter || apostrophes.contains(next) {
                text.append(apostrophes.contains(next) ? "'" : next)
                advance()
            }
            return text
        }
    }
}

extension Character {
    var isASCIIDigit: Bool {
        isASCII && isNumber
    }
}
