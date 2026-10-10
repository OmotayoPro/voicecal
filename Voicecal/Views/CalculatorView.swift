import SwiftUI

struct CalculatorView: View {
    @State private var viewModel: CalculatorViewModel

    init(viewModel: CalculatorViewModel = CalculatorViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.section) {
            // Reserved for the settings button (build step 10).
            Color.clear
                .frame(height: DesignTokens.Size.toolbarButton)

            display

            KeypadView(onKey: viewModel.handle)
        }
        .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
        .padding(.bottom, DesignTokens.Spacing.screenBottom)
        .background(DesignTokens.Colors.surface.ignoresSafeArea())
    }

    private var display: some View {
        ZStack(alignment: .bottomTrailing) {
            // A sibling layer, not a parent gesture, so token taps are not also treated as background taps.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(perform: viewModel.tapDisplayBackground)

            EquationRowView(
                equation: viewModel.equation,
                onTapToken: viewModel.tapToken,
                onTapGap: viewModel.tapGap
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    CalculatorView()
        .preferredColorScheme(.dark)
}
