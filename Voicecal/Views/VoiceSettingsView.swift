import SwiftUI

struct VoiceSettingsView: View {
    @Bindable var settings: VoiceSettings
    var voices: [VoiceOption] = VoiceCatalog.systemVoices()
    let onPreview: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Speak the answer", isOn: $settings.speaksResult)
                    voicePicker
                    slider(
                        "Speed", value: $settings.rate, range: VoiceSettings.rateRange,
                        low: "tortoise", high: "hare"
                    )
                    slider(
                        "Pitch", value: $settings.pitch, range: VoiceSettings.pitchRange,
                        low: "arrow.down", high: "arrow.up"
                    )
                    Button("Preview voice", systemImage: "play.fill", action: onPreview)
                } header: {
                    Text("Spoken answer")
                } footer: {
                    Text("When this is on, equals reads the answer aloud.")
                }

                Section {
                    Picker("Turn the mic off after", selection: $settings.inactivityTimeout) {
                        ForEach(InactivityTimeout.allCases) { timeout in
                            Text(timeout.label).tag(timeout)
                        }
                    }
                } header: {
                    Text("Listening")
                } footer: {
                    Text(
                        "The mic turns itself off when nothing is said or typed for this long. "
                            + "It always turns off after 3 minutes."
                    )
                }
            }
            .navigationTitle("Voice settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear(perform: forgetMissingVoice)
    }

    private var voicePicker: some View {
        Picker("Voice", selection: $settings.voiceIdentifier) {
            Text("Default").tag(String?.none)
            ForEach(VoiceCatalog.grouped(voices), id: \.quality) { group in
                Section(group.quality.title) {
                    ForEach(group.voices) { voice in
                        Text(voice.label).tag(String?.some(voice.id))
                    }
                }
            }
        }
        .pickerStyle(.navigationLink)
    }

    private func slider(
        _ title: String, value: Binding<Float>, range: ClosedRange<Float>, low: String, high: String
    ) -> some View {
        VStack(alignment: .leading) {
            Text(title)
            Slider(value: value, in: range) {
                Text(title)
            } minimumValueLabel: {
                Image(systemName: low)
            } maximumValueLabel: {
                Image(systemName: high)
            }
        }
    }

    /// A stored voice that has since been removed from the device falls back to the default.
    private func forgetMissingVoice() {
        if let chosen = settings.voiceIdentifier, !voices.contains(where: { $0.id == chosen }) {
            settings.voiceIdentifier = nil
        }
    }
}

#Preview {
    VoiceSettingsView(settings: VoiceSettings(), onPreview: {})
        .preferredColorScheme(.dark)
}
