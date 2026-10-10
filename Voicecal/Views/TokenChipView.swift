import SwiftUI

struct TokenChipView: View {
    let token: Token
    let isEditing: Bool

    var body: some View {
        Text(token.displayText)
            .font(DesignTokens.Typography.display)
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .lineLimit(1)
            .fixedSize()
            .frame(minHeight: DesignTokens.Size.minTapTarget)
            .background {
                if isEditing {
                    // A filled, outlined box so the focused state does not rely on color alone.
                    RoundedRectangle(cornerRadius: DesignTokens.Size.chipRadius)
                        .fill(DesignTokens.Colors.tertiaryPressed)
                        .strokeBorder(
                            DesignTokens.Colors.highlight.opacity(DesignTokens.Opacity.edgeHighlightStrong),
                            lineWidth: DesignTokens.Size.keyRing
                        )
                        .padding(.horizontal, -DesignTokens.Spacing.chipOutset)
                }
            }
            .contentShape(Rectangle())
    }
}

#Preview {
    HStack {
        TokenChipView(token: .number("12"), isEditing: false)
        TokenChipView(token: .op(.add), isEditing: false)
        TokenChipView(token: .number("3.5"), isEditing: true)
    }
    .padding()
    .background(DesignTokens.Colors.surface)
}
