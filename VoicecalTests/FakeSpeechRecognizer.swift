@testable import Voicecal

/// Stands in for the microphone: tests script what it "hears".
@MainActor
final class FakeSpeechRecognizer: SpeechRecognizing {
    var onEvent: ((SpeechEvent) -> Void)?
    var permission = SpeechPermission.granted
    var startError: Error?
    private(set) var isRunning = false
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var lastOptions: SpeechOptions?

    func requestPermission() async -> SpeechPermission {
        permission
    }

    func start(options: SpeechOptions) throws {
        if let startError {
            throw startError
        }
        lastOptions = options
        isRunning = true
        startCount += 1
    }

    func stop() {
        isRunning = false
        stopCount += 1
    }

    func hear(_ transcript: String, isFinal: Bool = false) {
        onEvent?(.transcript(transcript, isFinal: isFinal))
    }

    func send(_ event: SpeechEvent) {
        onEvent?(event)
    }
}
