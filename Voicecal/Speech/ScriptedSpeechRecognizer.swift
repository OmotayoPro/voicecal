#if DEBUG
    import Foundation

    /// A stand-in recognizer for UI tests and demos: it "hears" a fixed series of partial transcripts.
    /// Enabled by launching with the UITEST_SPEECH_SCRIPT environment variable, partials separated by "|".
    @MainActor
    final class ScriptedSpeechRecognizer: SpeechRecognizing {
        static let environmentKey = "UITEST_SPEECH_SCRIPT"

        var onEvent: ((SpeechEvent) -> Void)?
        private let partials: [String]
        private var playback: Task<Void, Never>?

        init(script: String) {
            partials = script.split(separator: "|").map(String.init)
        }

        func requestPermission() async -> SpeechPermission {
            .granted
        }

        func start() throws {
            playback = Task { [weak self, partials] in
                for partial in partials {
                    try? await Task.sleep(for: .milliseconds(150))
                    guard !Task.isCancelled else { return }
                    self?.onEvent?(.transcript(partial, isFinal: false))
                }
            }
        }

        func stop() {
            playback?.cancel()
            playback = nil
        }
    }
#endif
