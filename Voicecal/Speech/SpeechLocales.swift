import Foundation
import Speech

/// How recognition should run. Chosen by the user in settings.
struct SpeechOptions: Equatable {
    /// The English variant to listen for, e.g. "en-GB". Nil picks one from the device's languages.
    var localeIdentifier: String?
    /// Lets Apple's servers do the recognition. Usually more accurate than on-device recognition,
    /// but the audio leaves the phone.
    var allowsServerRecognition = false
}

/// An English variant the recognizer supports.
struct SpeechLocaleOption: Identifiable, Equatable {
    let id: String
    let name: String
}

enum SpeechLocales {
    static let fallback = "en-US"

    /// The recognizer locale to use: the user's choice if it is supported, otherwise the first
    /// English variant among the device's languages that is, otherwise US English.
    static func resolve(preferred: String?, deviceLanguages: [String], supported: Set<String>) -> String {
        if let preferred, supported.contains(preferred) {
            return preferred
        }
        let english = deviceLanguages
            .map { $0.replacingOccurrences(of: "_", with: "-") }
            .first { $0.hasPrefix("en-") && supported.contains($0) }
        return english ?? fallback
    }

    static var supportedIdentifiers: Set<String> {
        Set(SFSpeechRecognizer.supportedLocales().map { $0.identifier(.bcp47) })
    }

    /// The English variants on offer, named in the user's language and sorted by name.
    static func englishOptions(
        supported: Set<String> = supportedIdentifiers,
        displayLocale: Locale = .current
    ) -> [SpeechLocaleOption] {
        supported
            .filter { $0.hasPrefix("en-") }
            .map { SpeechLocaleOption(id: $0, name: displayLocale.localizedString(forIdentifier: $0) ?? $0) }
            .sorted { $0.name < $1.name }
    }
}
