import SwiftUI

@main
struct VoicecalApp: App {
    @State private var viewModel = CalculatorViewModel(speech: makeSpeechRecognizer())

    var body: some Scene {
        WindowGroup {
            CalculatorView(viewModel: viewModel)
                .preferredColorScheme(.dark)
        }
    }

    private static func makeSpeechRecognizer() -> SpeechRecognizing {
        #if DEBUG
            if let script = ProcessInfo.processInfo.environment[ScriptedSpeechRecognizer.environmentKey] {
                return ScriptedSpeechRecognizer(script: script)
            }
        #endif
        return SpeechRecognizerService()
    }
}
