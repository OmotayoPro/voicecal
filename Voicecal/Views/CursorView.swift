import SwiftUI

/// The blinking insertion marker. It glows while the mic is listening.
struct CursorView: View {
    var isGlowing = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDimmed = false

    var body: some View {
        Capsule()
            .fill(DesignTokens.Colors.textPrimary)
            .frame(width: DesignTokens.Size.cursorWidth, height: DesignTokens.Size.cursorHeight)
            .shadow(
                color: isGlowing ? DesignTokens.Colors.cursorGlowCool : .clear,
                radius: DesignTokens.Size.cursorGlowRadius,
                y: DesignTokens.Size.cursorGlowOffset
            )
            .shadow(
                color: isGlowing ? DesignTokens.Colors.cursorGlowWarm : .clear,
                radius: DesignTokens.Size.cursorGlowRadius,
                y: -DesignTokens.Size.cursorGlowOffset
            )
            .opacity(isDimmed ? 0 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    isDimmed = true
                }
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 40) {
        CursorView()
        CursorView(isGlowing: true)
    }
    .padding(40)
    .background(DesignTokens.Colors.surface)
}
