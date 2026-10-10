import SwiftUI

struct CalculatorView: View {
    @State private var viewModel: CalculatorViewModel
    @State private var showsSettings = false
    @Environment(\.scenePhase) private var scenePhase

    @MainActor
    init(viewModel: CalculatorViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? CalculatorViewModel())
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.section) {
            HStack {
                Button {
                    viewModel.stopListening()
                    showsSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(KeyButtonStyle(kind: .tertiary, size: DesignTokens.Size.toolbarButton))
                .accessibilityLabel("Voice settings")
                Spacer()
            }

            if let notice = viewModel.micNotice {
                MicNoticeView(notice: notice, onDismiss: viewModel.dismissMicNotice)
            }

            display

            KeypadView(
                isListening: viewModel.isListening,
                micCountdown: viewModel.micCountdown,
                onKey: viewModel.handle
            )
        }
        .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
        .padding(.bottom, DesignTokens.Spacing.screenBottom)
        .background(DesignTokens.Colors.surface.ignoresSafeArea())
        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.isListening)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                viewModel.stopListening()
            }
        }
        .onDisappear(perform: viewModel.stopListening)
        .sheet(isPresented: $showsSettings, onDismiss: viewModel.stopPreview) {
            VoiceSettingsView(settings: viewModel.settings, onPreview: viewModel.previewVoice)
                .preferredColorScheme(.dark)
        }
    }

    private var display: some View {
        ZStack(alignment: .bottomTrailing) {
            // A sibling layer, not a parent gesture, so token taps are not also treated as background taps.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(perform: viewModel.tapDisplayBackground)

            VStack(alignment: .trailing, spacing: 0) {
                if let status = viewModel.statusText {
                    Text(status)
                        .font(DesignTokens.Typography.liveResult)
                        .foregroundStyle(
                            DesignTokens.Colors.textPrimary.opacity(DesignTokens.Opacity.secondaryText)
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.trailing, DesignTokens.Size.cursorWidth)
                        .accessibilityIdentifier("status")
                }
                EquationRowView(
                    equation: viewModel.equation,
                    isListening: viewModel.isListening,
                    onTapToken: viewModel.tapToken,
                    onTapGap: viewModel.tapGap
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    CalculatorView()
        .preferredColorScheme(.dark)
}
