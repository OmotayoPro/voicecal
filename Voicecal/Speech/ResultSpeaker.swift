import AVFoundation

/// Reads results aloud. Behind a protocol so the view model can be tested silently.
@MainActor
protocol ResultSpeaking: AnyObject {
    /// Speaks `phrase`, replacing anything already being spoken. `onFinish` runs when it ends by itself.
    func speak(_ phrase: String, settings: VoiceSettings, onFinish: @escaping () -> Void)
    /// Stops immediately. The pending `onFinish` is dropped.
    func stop()
}

@MainActor
final class ResultSpeaker: NSObject, ResultSpeaking {
    private let synthesizer = AVSpeechSynthesizer()
    private var onFinish: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ phrase: String, settings: VoiceSettings, onFinish: @escaping () -> Void) {
        stop()
        self.onFinish = onFinish

        // Playback, so the answer is heard through the speaker even with the ringer off.
        // The recognizer sets its own category again when listening resumes.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        try? session.setActive(true)

        let utterance = AVSpeechUtterance(string: phrase)
        utterance.voice = Self.voice(for: settings.voiceIdentifier)
        utterance.rate = settings.rate
        utterance.pitchMultiplier = settings.pitch
        synthesizer.speak(utterance)
    }

    func stop() {
        onFinish = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    /// The chosen voice, or the default for the device language if it is no longer installed.
    nonisolated static func voice(for identifier: String?) -> AVSpeechSynthesisVoice? {
        identifier.flatMap(AVSpeechSynthesisVoice.init(identifier:))
            ?? AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
    }

    private func finished() {
        guard let onFinish else { return }
        self.onFinish = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        onFinish()
    }
}

extension ResultSpeaker: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_: AVSpeechSynthesizer, didFinish _: AVSpeechUtterance) {
        Task { @MainActor in
            finished()
        }
    }
}
