import SwiftUI

struct EquationRowView: View {
    let equation: Equation
    var isListening = false
    let onTapToken: (UUID) -> Void
    let onTapGap: (Int) -> Void

    var body: some View {
        if equation.tokens.isEmpty {
            placeholder
        } else {
            // Long equations scroll instead of shrinking, so numerals are never truncated.
            ViewThatFits(in: .horizontal) {
                row
                ScrollView(.horizontal) {
                    row
                }
                .scrollIndicators(.hidden)
                .defaultScrollAnchor(.trailing)
            }
        }
    }

    private var placeholder: some View {
        HStack(spacing: 0) {
            Text("0")
                .font(DesignTokens.Typography.display)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .accessibilityLabel("Empty equation")
            if isListening {
                CursorView(isGlowing: true)
            }
        }
        .padding(.horizontal, DesignTokens.Size.cursorWidth)
    }

    private var row: some View {
        HStack(spacing: 0) {
            ForEach(Array(equation.tokens.enumerated()), id: \.element.id) { index, token in
                let isEditing = token.id == equation.editingTokenID
                gap(at: index)
                Button {
                    onTapToken(token.id)
                } label: {
                    TokenChipView(token: token, isEditing: isEditing)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel(for: token, at: index))
                .accessibilityHint(isEditing ? "Double tap to stop editing" : "Double tap to edit")
                .accessibilityAddTraits(isEditing ? .isSelected : [])
            }
            gap(at: equation.tokens.count)
        }
        // Room for the cursor at either end.
        .padding(.horizontal, DesignTokens.Size.cursorWidth)
    }

    /// The boundary before the token at `index`. It takes no space, so tokens sit flush;
    /// the cursor and a narrow tap strip are drawn over it.
    private func gap(at index: Int) -> some View {
        Color.clear
            .frame(width: 0, height: DesignTokens.Size.cursorHeight)
            .overlay {
                Color.clear
                    .frame(width: DesignTokens.Spacing.cursorTapWidth, height: DesignTokens.Size.cursorHeight)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onTapGap(index)
                    }
            }
            .overlay {
                if equation.cursorIndex == index, equation.editingTokenID == nil {
                    CursorView(isGlowing: isListening)
                        .fixedSize()
                        .allowsHitTesting(false)
                }
            }
            .zIndex(1)
    }

    private func accessibilityLabel(for token: Token, at index: Int) -> String {
        let kind = token.isNumber ? "number" : "operator"
        return "Token \(index + 1) of \(equation.tokens.count), \(kind) \(token.spokenText)"
    }
}

private extension Token {
    var spokenText: String {
        switch self {
        case let .number(_, text): text
        case let .op(_, value):
            switch value {
            case .add: "plus"
            case .subtract: "minus"
            case .multiply: "times"
            case .divide: "divided by"
            case .percent: "percent"
            }
        }
    }
}
