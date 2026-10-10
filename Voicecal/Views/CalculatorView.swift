import SwiftUI

struct CalculatorView: View {
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.section) {
            // Reserved for the settings button (build step 10).
            Color.clear
                .frame(height: DesignTokens.Size.toolbarButton)

            display

            KeypadView(onKey: { _ in })
        }
        .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
        .padding(.bottom, DesignTokens.Spacing.screenBottom)
        .background(DesignTokens.Colors.surface.ignoresSafeArea())
    }

    /// Placeholder until the token row lands (build step 3).
    private var display: some View {
        Text("0")
            .font(DesignTokens.Typography.display)
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}

#Preview {
    CalculatorView()
        .preferredColorScheme(.dark)
}
