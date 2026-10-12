import Foundation
import Testing
@testable import Voicecal

func makeScratchDefaults() -> UserDefaults {
    let name = "voicecal.tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: name) ?? .standard
    defaults.removePersistentDomain(forName: name)
    return defaults
}

struct SpokenResultFormatterTests {
    @Test(arguments: [
        ("0", "zero"),
        ("8", "eight"),
        ("45.5", "forty-five point five"),
        ("-6", "minus six"),
        ("-0.25", "minus zero point two five"),
        ("1000000", "one million"),
        ("105", "one hundred five"),
        ("0.3333333333", "zero point three three three"),
        ("0.6666666666", "zero point six six seven"),
        ("2.99999", "three"),
        ("-0.00001", "zero"),
        ("123456789", "one hundred twenty-three million four hundred fifty-six thousand seven hundred eighty-nine"),
        ("12345678901234567890", "12345678901234567890")
    ])
    func phrases(value: String, expected: String) {
        #expect(SpokenResultFormatter.phrase(for: decimal(value)) == expected)
    }
}

struct VoiceSettingsTests {
    @Test func defaults() {
        let settings = VoiceSettings(defaults: makeScratchDefaults())
        #expect(settings.voiceIdentifier == nil)
        #expect(settings.rate == VoiceSettings.defaultRate)
        #expect(settings.pitch == VoiceSettings.defaultPitch)
        #expect(settings.speaksResult)
        #expect(settings.inactivityTimeout == .tenSeconds)
    }

    @Test func changesPersist() {
        let defaults = makeScratchDefaults()
        let settings = VoiceSettings(defaults: defaults)
        settings.voiceIdentifier = "com.example.voice"
        settings.rate = 0.4
        settings.pitch = 1.5
        settings.speaksResult = false
        settings.inactivityTimeout = .off

        let reloaded = VoiceSettings(defaults: defaults)
        #expect(reloaded.voiceIdentifier == "com.example.voice")
        #expect(reloaded.rate == 0.4)
        #expect(reloaded.pitch == 1.5)
        #expect(!reloaded.speaksResult)
        #expect(reloaded.inactivityTimeout == .off)
    }

    @Test func storedValuesOutOfRangeAreClampedOrReset() {
        let defaults = makeScratchDefaults()
        defaults.set(Float(5), forKey: "voice.rate")
        defaults.set(Float(0.1), forKey: "voice.pitch")
        defaults.set(7, forKey: "listening.inactivityTimeout")
        let settings = VoiceSettings(defaults: defaults)
        #expect(settings.rate == VoiceSettings.rateRange.upperBound)
        #expect(settings.pitch == VoiceSettings.pitchRange.lowerBound)
        #expect(settings.inactivityTimeout == .tenSeconds)
    }

    @Test func timeoutDurations() {
        #expect(InactivityTimeout.fiveSeconds.duration == .seconds(5))
        #expect(InactivityTimeout.thirtySeconds.duration == .seconds(30))
        #expect(InactivityTimeout.off.duration == nil)
        #expect(InactivityTimeout.allCases.map(\.label) == [
            "5 seconds", "10 seconds", "15 seconds", "30 seconds", "Off"
        ])
    }

    @Test func missingVoiceFallsBackToADefault() {
        let fallback = ResultSpeaker.voice(for: "com.example.not-installed")
        #expect(fallback?.identifier != "com.example.not-installed")
    }
}

@MainActor
struct ResultSpeakingTests {
    private let speech = FakeSpeechRecognizer()
    private let speaker = FakeResultSpeaker()
    private let settings = VoiceSettings(defaults: makeScratchDefaults())

    private func makeViewModel() -> CalculatorViewModel {
        CalculatorViewModel(speech: speech, speaker: speaker, settings: settings, pauseBeforeCommit: .seconds(60))
    }

    private func type(_ viewModel: CalculatorViewModel, _ keys: KeypadKey...) {
        keys.forEach(viewModel.handle)
    }

    @Test func equalsKeySolvesAndSpeaks() {
        let viewModel = makeViewModel()
        type(viewModel, .digit(4), .add, .digit(4), .equals)
        #expect(viewModel.equation.tokens.map(\.text) == ["8"])
        #expect(speaker.spoken == ["eight"])
        #expect(viewModel.isSpeaking)
        speaker.finish()
        #expect(!viewModel.isSpeaking)
    }

    @Test func spokenEqualsSolvesAndSpeaks() async {
        let viewModel = makeViewModel()
        await viewModel.startListening()
        speech.hear("nine divided by two equals", isFinal: true)
        #expect(viewModel.equation.tokens.map(\.text) == ["4.5"])
        #expect(speaker.spoken == ["four point five"])
    }

    @Test func nothingIsSpokenWhenTurnedOff() {
        settings.speaksResult = false
        let viewModel = makeViewModel()
        type(viewModel, .digit(4), .add, .digit(4), .equals)
        #expect(viewModel.equation.tokens.map(\.text) == ["8"])
        #expect(speaker.spoken.isEmpty)
        #expect(!viewModel.isSpeaking)
    }

    @Test func incompleteEquationSaysNothing() {
        let viewModel = makeViewModel()
        type(viewModel, .digit(4), .add, .equals)
        #expect(speaker.spoken.isEmpty)
    }

    @Test func divideByZeroIsSpoken() {
        let viewModel = makeViewModel()
        type(viewModel, .digit(4), .divide, .digit(0), .equals)
        #expect(speaker.spoken == ["Can't divide by zero"])
    }

    @Test func recognitionPausesWhileSpeakingThenResumes() async {
        let viewModel = makeViewModel()
        await viewModel.startListening()
        type(viewModel, .digit(2), .multiply, .digit(3), .equals)
        #expect(viewModel.isListening) // the mic key stays on
        #expect(!speech.isRunning)

        speech.hear("six") // the app's own voice must not become input
        #expect(viewModel.equation.tokens.map(\.text) == ["6"])

        speaker.finish()
        #expect(speech.isRunning)
        #expect(speech.startCount == 2)
        speech.hear("plus one")
        #expect(viewModel.equation.tokens.map(\.text) == ["6", "+", "1"])
    }

    @Test func micThatWasOffStaysOffAfterSpeaking() {
        let viewModel = makeViewModel()
        type(viewModel, .digit(2), .multiply, .digit(3), .equals)
        speaker.finish()
        #expect(!viewModel.isListening)
        #expect(speech.startCount == 0)
    }

    @Test func typingInterruptsTheAnswerAndResumesListening() async {
        let viewModel = makeViewModel()
        await viewModel.startListening()
        type(viewModel, .digit(2), .multiply, .digit(3), .equals)
        type(viewModel, .add)
        #expect(speaker.stopCount == 1)
        #expect(!viewModel.isSpeaking)
        #expect(speech.isRunning)
        #expect(viewModel.equation.tokens.map(\.text) == ["6", "+"])
    }

    @Test func turningTheMicOffWhileSpeakingKeepsItOff() async {
        let viewModel = makeViewModel()
        await viewModel.startListening()
        type(viewModel, .digit(2), .multiply, .digit(3), .equals)
        viewModel.handle(.mic)
        #expect(!viewModel.isListening)
        speaker.finish()
        #expect(!speech.isRunning)
        #expect(speech.startCount == 1)
    }

    @Test func wordsSpokenAfterEqualsInTheSameBreathStillLand() async {
        let viewModel = makeViewModel()
        await viewModel.startListening()
        speech.hear("two plus two equals times three", isFinal: true)
        #expect(viewModel.equation.tokens.map(\.text) == ["4", "×", "3"])
        #expect(speaker.spoken == ["four"])
    }
}

struct VoiceCatalogTests {
    private let voices = [
        VoiceOption(id: "b", name: "Samantha", region: "en-US", quality: .standard),
        VoiceOption(id: "a", name: "Daniel", region: "en-GB", quality: .standard),
        VoiceOption(id: "c", name: "Ava", region: "en-US", quality: .premium)
    ]

    @Test func groupsByQualityBestFirstAndSortsByName() {
        let groups = VoiceCatalog.grouped(voices)
        #expect(groups.map(\.quality) == [.premium, .standard])
        #expect(groups[1].voices.map(\.name) == ["Daniel", "Samantha"])
    }

    @Test func labelIncludesRegion() {
        #expect(voices[0].label == "Samantha (en-US)")
    }

    @Test func unknownLanguageFallsBackToEnglishVoices() {
        let fallback = VoiceCatalog.systemVoices(languageCode: "zz")
        #expect(fallback.allSatisfy { $0.region.hasPrefix("en") })
    }
}

@MainActor
struct VoiceSettingsWiringTests {
    @Test func previewSpeaksEvenWhenAnswersAreNotSpoken() {
        let speaker = FakeResultSpeaker()
        let settings = VoiceSettings(defaults: makeScratchDefaults())
        settings.speaksResult = false
        let viewModel = CalculatorViewModel(speaker: speaker, settings: settings)
        viewModel.previewVoice()
        #expect(speaker.spoken.count == 1)
        viewModel.stopPreview()
        #expect(speaker.stopCount == 1)
    }

    @Test func chosenTimeoutDrivesTheAutoStop() async throws {
        let speech = FakeSpeechRecognizer()
        let settings = VoiceSettings(defaults: makeScratchDefaults())
        settings.inactivityTimeout = .off
        let viewModel = CalculatorViewModel(speech: speech, settings: settings)
        await viewModel.startListening()
        try await Task.sleep(for: .milliseconds(300))
        #expect(viewModel.isListening)
        #expect(viewModel.micCountdown == nil)
    }
}

struct SpeechLocalesTests {
    private let supported: Set<String> = ["en-US", "en-GB", "en-AU", "en-IN", "fr-FR"]

    @Test func usesTheChosenAccentWhenSupported() {
        #expect(SpeechLocales.resolve(preferred: "en-GB", deviceLanguages: ["en-US"], supported: supported) == "en-GB")
    }

    @Test func automaticFollowsTheFirstSupportedEnglishDeviceLanguage() {
        let languages = ["fr-FR", "en-AU", "en-GB"]
        #expect(SpeechLocales.resolve(preferred: nil, deviceLanguages: languages, supported: supported) == "en-AU")
        #expect(SpeechLocales.resolve(preferred: nil, deviceLanguages: ["en_IN"], supported: supported) == "en-IN")
    }

    @Test func unsupportedChoicesFallBackToUSEnglish() {
        #expect(SpeechLocales.resolve(preferred: "en-NG", deviceLanguages: ["en-NG"], supported: supported) == "en-US")
        #expect(SpeechLocales.resolve(preferred: nil, deviceLanguages: ["yo-NG"], supported: supported) == "en-US")
        #expect(SpeechLocales.resolve(preferred: nil, deviceLanguages: [], supported: []) == "en-US")
    }

    @Test func offersOnlyEnglishVariantsSortedByName() {
        let options = SpeechLocales.englishOptions(supported: supported, displayLocale: Locale(identifier: "en_US"))
        #expect(options.map(\.id) == ["en-AU", "en-IN", "en-GB", "en-US"])
        #expect(options.first?.name == "English (Australia)")
    }
}

@MainActor
struct RecognitionSettingsTests {
    @Test func defaultsKeepRecognitionOnTheDevice() async {
        let speech = FakeSpeechRecognizer()
        let viewModel = CalculatorViewModel(speech: speech, settings: VoiceSettings(defaults: makeScratchDefaults()))
        await viewModel.startListening()
        #expect(speech.lastOptions == SpeechOptions(localeIdentifier: nil, allowsServerRecognition: false))
    }

    @Test func chosenAccentAndServerChoiceReachTheRecognizer() async {
        let speech = FakeSpeechRecognizer()
        let defaults = makeScratchDefaults()
        let settings = VoiceSettings(defaults: defaults)
        settings.recognitionLocaleIdentifier = "en-GB"
        settings.allowsServerRecognition = true
        let viewModel = CalculatorViewModel(speech: speech, settings: settings)
        await viewModel.startListening()
        #expect(speech.lastOptions == SpeechOptions(localeIdentifier: "en-GB", allowsServerRecognition: true))

        let reloaded = VoiceSettings(defaults: defaults)
        #expect(reloaded.recognitionLocaleIdentifier == "en-GB")
        #expect(reloaded.allowsServerRecognition)
    }
}
