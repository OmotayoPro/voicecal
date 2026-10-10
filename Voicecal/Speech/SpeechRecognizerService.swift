import AVFoundation
import Speech

@MainActor
final class SpeechRecognizerService: SpeechRecognizing {
    var onEvent: ((SpeechEvent) -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    /// Identifies the current task so callbacks from an earlier one are ignored.
    private var generation = 0
    private var isRunning = false
    private var taskStartedAt = ContinuousClock.now
    private var rapidFailures = 0

    func requestPermission() async -> SpeechPermission {
        guard await AVAudioApplication.requestRecordPermission() else { return .microphoneDenied }
        guard await Self.requestSpeechAuthorization() == .authorized else { return .speechDenied }
        guard let recognizer, recognizer.isAvailable else { return .unavailable }
        return .granted
    }

    func start() throws {
        guard let recognizer, recognizer.isAvailable else { throw SpeechError.unavailable }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let format = engine.inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw SpeechError.unavailable }

        isRunning = true
        rapidFailures = 0
        beginTask(with: recognizer)
        engine.prepare()
        do {
            try engine.start()
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        generation += 1
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Recognition tasks

    private func beginTask(with recognizer: SFSpeechRecognizer) {
        generation += 1
        let current = generation
        taskStartedAt = .now

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.contextualStrings = SpokenVocabulary.contextualStrings
        self.request = request

        engine.inputNode.removeTap(onBus: 0)
        Self.installTap(on: engine.inputNode, feeding: request)
        task = Self.makeTask(recognizer, request) { [weak self] text, isFinal, failed in
            self?.handleResult(generation: current, text: text, isFinal: isFinal, failed: failed)
        }
    }

    private func handleResult(generation: Int, text: String?, isFinal: Bool, failed: Bool) {
        guard isRunning, generation == self.generation else { return }
        if let text {
            onEvent?(.transcript(text, isFinal: isFinal))
        }
        guard isFinal || failed else { return }

        // Tasks end after about a minute, or on silence. Start another without the user noticing,
        // unless they are failing immediately, which means recognition is not actually working.
        let endedQuickly = ContinuousClock.now - taskStartedAt < .seconds(1)
        rapidFailures = failed && endedQuickly ? rapidFailures + 1 : 0
        guard rapidFailures < 3, let recognizer, recognizer.isAvailable else {
            stop()
            onEvent?(.stopped)
            return
        }
        request?.endAudio()
        task?.cancel()
        onEvent?(.segmentRestarted)
        beginTask(with: recognizer)
    }

    // MARK: - Callbacks from other threads

    // These closures run off the main thread, so they are built in nonisolated functions
    // and hop back to the main actor explicitly.

    private nonisolated static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private nonisolated static func installTap(
        on node: AVAudioInputNode,
        feeding request: SFSpeechAudioBufferRecognitionRequest
    ) {
        node.installTap(onBus: 0, bufferSize: 1024, format: node.outputFormat(forBus: 0)) { buffer, _ in
            request.append(buffer)
        }
    }

    private nonisolated static func makeTask(
        _ recognizer: SFSpeechRecognizer,
        _ request: SFSpeechAudioBufferRecognitionRequest,
        onResult: @escaping @MainActor (_ text: String?, _ isFinal: Bool, _ failed: Bool) -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor in
                onResult(text, isFinal, failed)
            }
        }
    }
}
