@testable import Voicecal

@MainActor
final class FakeResultSpeaker: ResultSpeaking {
    private(set) var spoken: [String] = []
    private(set) var stopCount = 0
    private var onFinish: (() -> Void)?

    func speak(_ phrase: String, settings _: VoiceSettings, onFinish: @escaping () -> Void) {
        spoken.append(phrase)
        self.onFinish = onFinish
    }

    func stop() {
        stopCount += 1
        onFinish = nil
    }

    /// The utterance ends by itself.
    func finish() {
        let callback = onFinish
        onFinish = nil
        callback?()
    }
}
