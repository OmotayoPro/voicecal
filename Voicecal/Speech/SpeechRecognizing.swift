import Foundation

enum SpeechPermission: Equatable {
    case granted
    case microphoneDenied
    case speechDenied
    /// No recognizer for this language, or it is offline with no on-device model.
    case unavailable
}

enum SpeechEvent: Equatable {
    /// The cumulative transcript of the current recognition task. Partial results get revised.
    case transcript(String, isFinal: Bool)
    /// A new recognition task has begun (they are time-limited); the next transcript starts from empty.
    case segmentRestarted
    /// Recognition ended on its own and will not resume.
    case stopped
}

enum SpeechError: Error {
    case unavailable
}

/// Speech-to-text behind a protocol so everything above it can be tested without a microphone.
@MainActor
protocol SpeechRecognizing: AnyObject {
    var onEvent: ((SpeechEvent) -> Void)? { get set }
    /// Asks for microphone access, then speech recognition access.
    func requestPermission() async -> SpeechPermission
    func start() throws
    func stop()
}
