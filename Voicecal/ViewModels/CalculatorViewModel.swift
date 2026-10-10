import Foundation
import Observation

/// Why the mic could not start. Shown inline; manual input keeps working.
enum MicNotice: Equatable {
    case microphoneDenied
    case speechDenied
    case unavailable

    var message: String {
        switch self {
        case .microphoneDenied: "Voice input needs microphone access."
        case .speechDenied: "Voice input needs speech recognition access."
        case .unavailable: "Voice input isn't available right now."
        }
    }

    /// Whether the user can fix this in the Settings app.
    var canOpenSettings: Bool {
        self != .unavailable
    }
}

@MainActor
@Observable
final class CalculatorViewModel {
    let equation = Equation()

    private(set) var isListening = false
    /// While the mic is about to stop by itself: 1 down to 0. Nil otherwise.
    private(set) var micCountdown: Double?
    private(set) var micNotice: MicNotice?
    /// Set when equals fails for a reason worth telling the user; cleared by the next input.
    private(set) var errorMessage: String?

    private let speech: SpeechRecognizing?
    private let dictation: DictationSession
    /// How long speech must pause before pending tokens are committed.
    private let pauseBeforeCommit: Duration
    private var pauseTask: Task<Void, Never>?
    private let inactivityTimer = InactivityTimer()
    var inactivityPolicy: InactivityPolicy

    init(
        speech: SpeechRecognizing? = nil,
        pauseBeforeCommit: Duration = .milliseconds(800),
        inactivityPolicy: InactivityPolicy = InactivityPolicy()
    ) {
        self.speech = speech
        self.pauseBeforeCommit = pauseBeforeCommit
        self.inactivityPolicy = inactivityPolicy
        dictation = DictationSession(equation: equation)
        dictation.onCommand = { [weak self] command in
            self?.run(command)
        }
        speech?.onEvent = { [weak self] event in
            self?.handle(event)
        }
        inactivityTimer.onChange = { [weak self] deadline in
            self?.handle(deadline)
        }
    }

    /// The secondary line above the equation: an error, or the running result.
    var statusText: String? {
        if let errorMessage {
            return errorMessage
        }
        guard let result = equation.liveResult else { return nil }
        return "= " + Token.number(ResultFormatter.string(from: result)).displayText
    }

    // MARK: - Keypad

    func handle(_ key: KeypadKey) {
        if key == .mic {
            toggleMic()
            return
        }
        prepareForManualEdit()
        micNotice = nil

        if let value = key.operatorValue {
            equation.typeOperator(value)
            return
        }
        switch key {
        case let .digit(value): equation.typeDigit(value)
        case .decimalPoint: equation.typeDecimalPoint()
        case .clear: equation.clear()
        case .backspace: equation.backspace()
        case .equals: evaluate()
        default: break
        }
    }

    func tapToken(id: UUID) {
        prepareForManualEdit()
        equation.toggleEditing(id: id)
    }

    func tapGap(at index: Int) {
        prepareForManualEdit()
        equation.moveCursor(to: index)
    }

    /// Tapping empty display space ends any edit and returns the cursor to the end.
    func tapDisplayBackground() {
        prepareForManualEdit()
        equation.moveCursor(to: equation.tokens.count)
    }

    /// Solves the equation and collapses it to the result, so the user can keep calculating from it.
    func evaluate() {
        switch ExpressionEvaluator.evaluate(equation.tokens) {
        case let .success(value):
            equation.showResult(ResultFormatter.string(from: value))
        case .failure(.divideByZero):
            errorMessage = "Can't divide by zero"
        case .failure(.overflow):
            errorMessage = "Number too large"
        case .failure(.malformed):
            break // Incomplete entry: leave it for the user to finish.
        }
    }

    /// A manual edit never stops the mic. What was heard so far is committed first, so the edit
    /// cannot be overwritten by a later revision and dictation carries on from the new cursor.
    private func prepareForManualEdit() {
        errorMessage = nil
        commitDictation()
        inactivityTimer.noteActivity()
    }

    // MARK: - Mic

    /// Tap-to-toggle: the mic stays on until it is tapped again.
    func toggleMic() {
        if isListening {
            stopListening()
        } else {
            Task {
                await startListening()
            }
        }
    }

    func startListening() async {
        micNotice = nil
        guard !isListening else { return }
        guard let speech else {
            micNotice = .unavailable
            return
        }
        switch await speech.requestPermission() {
        case .granted:
            do {
                try speech.start()
                isListening = true
                inactivityTimer.start(policy: inactivityPolicy)
            } catch {
                micNotice = .unavailable
            }
        case .microphoneDenied: micNotice = .microphoneDenied
        case .speechDenied: micNotice = .speechDenied
        case .unavailable: micNotice = .unavailable
        }
    }

    func stopListening() {
        guard isListening else { return }
        speech?.stop()
        finishListening()
    }

    func dismissMicNotice() {
        micNotice = nil
    }

    // MARK: - Dictation

    private func handle(_ event: SpeechEvent) {
        switch event {
        case let .transcript(text, isFinal):
            guard isListening else { return }
            if dictation.update(transcript: text) {
                errorMessage = nil
                inactivityTimer.noteActivity()
                scheduleCommitAfterPause()
            }
            if isFinal {
                commitDictation()
            }
        case .segmentRestarted:
            pauseTask?.cancel()
            dictation.startNewSegment()
        case .stopped:
            finishListening()
        }
    }

    /// Commits what was heard and returns the mic to idle. Any edit in progress is kept.
    private func finishListening() {
        pauseTask?.cancel()
        dictation.startNewSegment()
        inactivityTimer.stop()
        micCountdown = nil
        isListening = false
    }

    private func handle(_ deadline: ListeningDeadline) {
        switch deadline {
        case .active: micCountdown = nil
        case let .closing(remaining): micCountdown = remaining
        case .expired: stopListening()
        }
    }

    private func commitDictation() {
        pauseTask?.cancel()
        dictation.commit()
    }

    private func scheduleCommitAfterPause() {
        pauseTask?.cancel()
        pauseTask = Task { [weak self, pauseBeforeCommit] in
            try? await Task.sleep(for: pauseBeforeCommit)
            guard !Task.isCancelled else { return }
            self?.commitDictation()
        }
    }

    private func run(_ command: VoiceCommand) {
        switch command {
        case .clear: equation.clear()
        case .deleteLast: equation.deleteTokenBeforeCursor()
        case .equals: evaluate()
        }
    }
}
