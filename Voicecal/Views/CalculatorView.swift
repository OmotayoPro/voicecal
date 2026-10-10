import SwiftUI

struct CalculatorView: View {
    @State private var viewModel: CalculatorViewModel

    @MainActor
    init(viewModel: CalculatorViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? CalculatorViewModel())
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.section) {
            // Reserved for the settings button (build step 10).
            Color.clear
                .frame(height: DesignTokens.Size.toolbarButton)

            if let notice = viewModel.micNotice {
                MicNoticeView(notice: notice, onDismiss: viewModel.dismissMicNotice)
            }

            display

            KeypadView(isListening: viewModel.isListening, onKey: viewModel.handle)
        }
        .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
        .padding(.bottom, DesignTokens.Spacing.screenBottom)
        .background(DesignTokens.Colors.surface.ignoresSafeArea())
        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.isListening)
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
