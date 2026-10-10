import SwiftUI

@main
struct VoicecalApp: App {
    @State private var viewModel = makeViewModel()

    var body: some Scene {
        WindowGroup {
            CalculatorView(viewModel: viewModel)
                .preferredColorScheme(.dark)
        }
    }

    @MainActor
    private static func makeViewModel() -> CalculatorViewModel {
        #if DEBUG
            // UI tests swap in a scripted recognizer and can shorten the inactivity timeout.
            let environment = ProcessInfo.processInfo.environment
            if let script = environment[ScriptedSpeechRecognizer.environmentKey] {
                var policy = InactivityPolicy()
                if let seconds = environment["UITEST_INACTIVITY_SECONDS"].flatMap(Double.init) {
                    policy.timeout = .seconds(seconds)
                }
                // A long pause keeps dictated tokens pending long enough for a test to observe them.
                return CalculatorViewModel(
                    speech: ScriptedSpeechRecognizer(script: script),
                    pauseBeforeCommit: .seconds(3),
                    inactivityPolicy: policy
                )
            }
        #endif
        return CalculatorViewModel(speech: SpeechRecognizerService(), speaker: ResultSpeaker())
    }
}
