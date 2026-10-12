import Foundation
import Observation

enum InactivityTimeout: Int, CaseIterable, Identifiable {
    case fiveSeconds = 5
    case tenSeconds = 10
    case fifteenSeconds = 15
    case thirtySeconds = 30
    case off = 0

    var id: Int {
        rawValue
    }

    var duration: Duration? {
        self == .off ? nil : .seconds(rawValue)
    }

    var label: String {
        self == .off ? "Off" : "\(rawValue) seconds"
    }
}

/// User preferences for the spoken result and for listening. Saved to `UserDefaults` as they change.
@Observable
final class VoiceSettings {
    /// A comfortable band inside AVSpeechUtterance's 0...1 rate scale.
    static let rateRange: ClosedRange<Float> = 0.35 ... 0.6
    static let pitchRange: ClosedRange<Float> = 0.5 ... 2
    static let defaultRate: Float = 0.5
    static let defaultPitch: Float = 1

    /// `AVSpeechSynthesisVoice` identifier. Nil means the system default voice.
    var voiceIdentifier: String? {
        didSet { defaults.set(voiceIdentifier, forKey: Key.voiceIdentifier) }
    }

    var rate: Float {
        didSet { defaults.set(rate, forKey: Key.rate) }
    }

    var pitch: Float {
        didSet { defaults.set(pitch, forKey: Key.pitch) }
    }

    /// Whether equals reads the answer aloud.
    var speaksResult: Bool {
        didSet { defaults.set(speaksResult, forKey: Key.speaksResult) }
    }

    var inactivityTimeout: InactivityTimeout {
        didSet { defaults.set(inactivityTimeout.rawValue, forKey: Key.inactivityTimeout) }
    }

    /// The English variant to recognize, e.g. "en-GB". Nil follows the device's languages.
    var recognitionLocaleIdentifier: String? {
        didSet { defaults.set(recognitionLocaleIdentifier, forKey: Key.recognitionLocale) }
    }

    /// Whether Apple's servers may do the recognition instead of the phone.
    var allowsServerRecognition: Bool {
        didSet { defaults.set(allowsServerRecognition, forKey: Key.allowsServerRecognition) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        voiceIdentifier = defaults.string(forKey: Key.voiceIdentifier)
        rate = (defaults.object(forKey: Key.rate) as? Float).map(Self.rateRange.clamp) ?? Self.defaultRate
        pitch = (defaults.object(forKey: Key.pitch) as? Float).map(Self.pitchRange.clamp) ?? Self.defaultPitch
        speaksResult = defaults.object(forKey: Key.speaksResult) as? Bool ?? true
        inactivityTimeout = (defaults.object(forKey: Key.inactivityTimeout) as? Int)
            .flatMap(InactivityTimeout.init) ?? .tenSeconds
        recognitionLocaleIdentifier = defaults.string(forKey: Key.recognitionLocale)
        allowsServerRecognition = defaults.bool(forKey: Key.allowsServerRecognition)
    }

    private enum Key {
        static let voiceIdentifier = "voice.identifier"
        static let rate = "voice.rate"
        static let pitch = "voice.pitch"
        static let speaksResult = "voice.speaksResult"
        static let inactivityTimeout = "listening.inactivityTimeout"
        static let recognitionLocale = "listening.recognitionLocale"
        static let allowsServerRecognition = "listening.allowsServerRecognition"
    }
}

private extension ClosedRange {
    func clamp(_ value: Bound) -> Bound {
        Swift.min(Swift.max(value, lowerBound), upperBound)
    }
}
