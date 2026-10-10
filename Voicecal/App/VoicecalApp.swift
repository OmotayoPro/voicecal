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
            if let viewModel = makeUITestViewModel() {
                return viewModel
            }
        #endif
        return CalculatorViewModel(speech: SpeechRecognizerService(), speaker: ResultSpeaker())
    }

    #if DEBUG
        /// UI tests launch with UITEST_MODE: settings start clean (unless UITEST_KEEP_SETTINGS), nothing
        /// is spoken aloud, and UITEST_SPEECH_SCRIPT swaps the microphone for scripted transcripts.
        @MainActor
        private static func makeUITestViewModel() -> CalculatorViewModel? {
            let environment = ProcessInfo.processInfo.environment
            guard environment["UITEST_MODE"] != nil else { return nil }
            if environment["UITEST_KEEP_SETTINGS"] == nil, let domain = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: domain)
            }
            let speech: SpeechRecognizing = environment[ScriptedSpeechRecognizer.environmentKey]
                .map(ScriptedSpeechRecognizer.init) ?? SpeechRecognizerService()
            let policy = environment["UITEST_INACTIVITY_SECONDS"].flatMap(Double.init).map {
                InactivityPolicy(timeout: .seconds($0))
            }
            // A long pause keeps dictated tokens pending long enough for a test to observe them.
            return CalculatorViewModel(speech: speech, pauseBeforeCommit: .seconds(3), inactivityPolicy: policy)
        }
    #endif
}
