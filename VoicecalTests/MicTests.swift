import Testing
@testable import Voicecal

@MainActor
struct MicTests {
    private let speech = FakeSpeechRecognizer()

    private func makeViewModel() -> CalculatorViewModel {
        CalculatorViewModel(speech: speech)
    }

    @Test func startsListeningWhenPermissionIsGranted() async {
        let viewModel = makeViewModel()
        await viewModel.startListening()
        #expect(viewModel.isListening)
        #expect(speech.isRunning)
        #expect(viewModel.micNotice == nil)
    }

    @Test func staysOnUntilToggledOff() async {
        let viewModel = makeViewModel()
        await viewModel.startListening()
        viewModel.handle(.digit(1))
        viewModel.handle(.add)
        #expect(viewModel.isListening)
        viewModel.handle(.mic)
        #expect(!viewModel.isListening)
        #expect(speech.stopCount == 1)
    }

    @Test(arguments: [
        (SpeechPermission.microphoneDenied, MicNotice.microphoneDenied),
        (.speechDenied, .speechDenied),
        (.unavailable, .unavailable)
    ])
    func deniedPermissionShowsNoticeAndKeepsKeypadWorking(permission: SpeechPermission, notice: MicNotice) async {
        speech.permission = permission
        let viewModel = makeViewModel()
        await viewModel.startListening()
        #expect(!viewModel.isListening)
        #expect(speech.startCount == 0)
        #expect(viewModel.micNotice == notice)

        viewModel.handle(.digit(7))
        #expect(viewModel.equation.tokens.map(\.text) == ["7"])
        #expect(viewModel.micNotice == nil)
    }

    @Test func failureToStartShowsUnavailable() async {
        speech.startError = SpeechError.unavailable
        let viewModel = makeViewModel()
        await viewModel.startListening()
        #expect(!viewModel.isListening)
        #expect(viewModel.micNotice == .unavailable)
    }

    @Test func noRecognizerAtAllShowsUnavailable() async {
        let viewModel = CalculatorViewModel()
        await viewModel.startListening()
        #expect(viewModel.micNotice == .unavailable)
    }

    @Test func recognizerStoppingOnItsOwnTurnsTheMicOff() async {
        let viewModel = makeViewModel()
        await viewModel.startListening()
        speech.send(.stopped)
        #expect(!viewModel.isListening)
    }

    @Test func onlySettingsFixableNoticesOfferSettings() {
        #expect(MicNotice.microphoneDenied.canOpenSettings)
        #expect(MicNotice.speechDenied.canOpenSettings)
        #expect(!MicNotice.unavailable.canOpenSettings)
    }
}
