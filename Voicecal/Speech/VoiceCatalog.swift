import AVFoundation

/// A synthesizer voice the user can choose.
struct VoiceOption: Identifiable, Equatable {
    enum Quality: Int, CaseIterable {
        case premium
        case enhanced
        case standard

        var title: String {
            switch self {
            case .premium: "Premium"
            case .enhanced: "Enhanced"
            case .standard: "Standard"
            }
        }
    }

    let id: String
    let name: String
    let region: String
    let quality: Quality

    var label: String {
        "\(name) (\(region))"
    }
}

enum VoiceCatalog {
    static var deviceLanguageCode: String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }

    /// Installed voices for a language, best quality first.
    static func systemVoices(languageCode: String = deviceLanguageCode) -> [VoiceOption] {
        let installed = AVSpeechSynthesisVoice.speechVoices()
        let matching = installed.filter { $0.language.hasPrefix(languageCode) }
        // The app only understands English for now, so English voices are the fallback.
        return (matching.isEmpty ? installed.filter { $0.language.hasPrefix("en") } : matching).map { voice in
            VoiceOption(
                id: voice.identifier,
                name: voice.name,
                region: voice.language,
                quality: quality(of: voice)
            )
        }
    }

    /// Voices grouped by quality, each group sorted by name. Empty groups are left out.
    static func grouped(_ voices: [VoiceOption]) -> [(quality: VoiceOption.Quality, voices: [VoiceOption])] {
        VoiceOption.Quality.allCases.compactMap { quality in
            let members = voices.filter { $0.quality == quality }.sorted { $0.label < $1.label }
            return members.isEmpty ? nil : (quality, members)
        }
    }

    private static func quality(of voice: AVSpeechSynthesisVoice) -> VoiceOption.Quality {
        switch voice.quality {
        case .premium: .premium
        case .enhanced: .enhanced
        default: .standard
        }
    }
}
