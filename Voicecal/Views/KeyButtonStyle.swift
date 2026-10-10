import SwiftUI

/// The three key variants of the Figma `button` component.
enum KeyKind {
    case primary
    case secondary
    case tertiary
}

struct KeyButtonStyle: ButtonStyle {
    let kind: KeyKind
    var size: CGFloat = DesignTokens.Size.key

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignTokens.Typography.key)
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .frame(width: size, height: size)
            .background(KeySurface(kind: kind, isPressed: configuration.isPressed))
            .contentShape(Circle())
    }
}

private struct KeySurface: View {
    let kind: KeyKind
    let isPressed: Bool

    var body: some View {
        ZStack {
            Circle().fill(fill)
            if hasGloss {
                Circle().fill(
                    LinearGradient(
                        colors: [
                            DesignTokens.Colors.highlight.opacity(DesignTokens.Opacity.keyGloss),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            edgeHighlight(offset: highlightWidth, opacity: topHighlightOpacity)
            edgeHighlight(offset: -highlightWidth, opacity: bottomHighlightOpacity)
        }
        .overlay(
            Circle()
                .strokeBorder(ring, lineWidth: DesignTokens.Size.keyRing)
                .padding(-DesignTokens.Size.keyRing)
        )
    }

    private func edgeHighlight(offset: CGFloat, opacity: Double) -> some View {
        InsetEdge(offset: offset)
            .fill(DesignTokens.Colors.highlight.opacity(opacity), style: FillStyle(eoFill: true))
            .clipShape(Circle())
    }

    private var fill: Color {
        switch (kind, isPressed) {
        case (.primary, false): DesignTokens.Colors.primaryDefault
        case (.primary, true): DesignTokens.Colors.primaryPressed
        case (.secondary, false): DesignTokens.Colors.secondaryDefault
        case (.secondary, true): DesignTokens.Colors.secondaryPressed
        case (.tertiary, false): DesignTokens.Colors.tertiaryDefault
        case (.tertiary, true): DesignTokens.Colors.tertiaryPressed
        }
    }

    private var ring: Color {
        kind == .primary ? DesignTokens.Colors.primaryRing : DesignTokens.Colors.neutralRing
    }

    private var hasGloss: Bool {
        kind != .tertiary
    }

    private var highlightWidth: CGFloat {
        kind == .primary ? 2 : 1
    }

    private var topHighlightOpacity: Double {
        kind == .tertiary && !isPressed
            ? DesignTokens.Opacity.edgeHighlightTop
            : DesignTokens.Opacity.edgeHighlightStrong
    }

    private var bottomHighlightOpacity: Double {
        kind == .tertiary && !isPressed
            ? DesignTokens.Opacity.edgeHighlightBottom
            : DesignTokens.Opacity.edgeHighlightStrong
    }
}

/// A circle plus the same circle shifted vertically. Filled even-odd and clipped
/// to the circle, it leaves a thin crescent on one edge, matching Figma's inset shadow.
private struct InsetEdge: Shape {
    let offset: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: rect)
        path.addEllipse(in: rect.offsetBy(dx: 0, dy: offset))
        return path
    }
}
