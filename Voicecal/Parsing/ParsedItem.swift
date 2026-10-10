import Foundation

enum VoiceCommand: Equatable {
    case clear
    case deleteLast
    case equals
}

enum ParsedItem: Equatable {
    /// Plain digits with an optional leading "-" and "." separator, ready to become a number token.
    case number(String)
    case op(Operator) // swiftlint:disable:this identifier_name
    case command(VoiceCommand)
}
