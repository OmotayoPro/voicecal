import Foundation
import Observation
import OSLog

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
    private(set) var micNotice: MicNotice?
    /// Set when equals fails for a reason worth telling the user; cleared by the next input.
    private(set) var errorMessage: String?

    /// True right after equals, while the equation is just the result.
    private var isShowingResult = false
    private let speech: SpeechRecognizing?
    private let log = Logger(subsystem: "com.omotayotaiwo.voicecal", category: "speech")

    init(speech: SpeechRecognizing? = nil) {
        self.speech = speech
        speech?.onEvent = { [weak self] event in
            self?.handle(event)
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
        errorMessage = nil
        micNotice = nil
        let startsFresh = isShowingResult
        isShowingResult = false

        if let value = key.operatorValue {
            equation.typeOperator(value)
            return
        }
        switch key {
        case let .digit(value):
            if startsFresh {
                equation.clear()
            }
            equation.typeDigit(value)
        case .decimalPoint:
            if startsFresh {
                equation.clear()
            }
            equation.typeDecimalPoint()
        case .clear: equation.clear()
        case .backspace: equation.backspace()
        case .equals: evaluate()
        default: break
        }
    }

    func tapToken(id: UUID) {
        isShowingResult = false
        equation.toggleEditing(id: id)
    }

    func tapGap(at index: Int) {
        isShowingResult = false
        equation.moveCursor(to: index)
    }

    /// Tapping empty display space ends any edit and returns the cursor to the end.
    func tapDisplayBackground() {
        equation.moveCursor(to: equation.tokens.count)
    }

    /// Solves the equation and collapses it to the result, so the user can keep calculating from it.
    func evaluate() {
        switch ExpressionEvaluator.evaluate(equation.tokens) {
        case let .success(value):
            equation.clear()
            equation.insert(.number(ResultFormatter.string(from: value)))
            isShowingResult = true
        case .failure(.divideByZero):
            errorMessage = "Can't divide by zero"
        case .failure(.overflow):
            errorMessage = "Number too large"
        case .failure(.malformed):
            break // Incomplete entry: leave it for the user to finish.
        }
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
        isListening = false
    }

    func dismissMicNotice() {
        micNotice = nil
    }

    private func handle(_ event: SpeechEvent) {
        switch event {
        case let .transcript(text, isFinal):
            // Dictation into the equation arrives in build step 7.
            log.debug("transcript\(isFinal ? " (final)" : ""): \(text, privacy: .public)")
        case .segmentRestarted:
            break
        case .stopped:
            isListening = false
        }
    }
}
