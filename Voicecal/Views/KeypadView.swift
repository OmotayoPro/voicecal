import SwiftUI

struct KeypadView: View {
    var isListening = false
    var micCountdown: Double?
    let onKey: (KeypadKey) -> Void

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.keypadRow) {
            ForEach(KeypadKey.layout, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(row, id: \.self) { key in
                        if key != row.first {
                            Spacer(minLength: 0)
                        }
                        Button {
                            onKey(key)
                        } label: {
                            key.label
                        }
                        .buttonStyle(KeyButtonStyle(kind: key.kind, glow: key == .mic ? isListening : nil))
                        .overlay {
                            if key == .mic, let micCountdown {
                                CountdownRing(remaining: micCountdown)
                            }
                        }
                        .accessibilityLabel(key == .mic && isListening ? "Stop listening" : key.accessibilityLabel)
                        .accessibilityValue(key == .mic && isListening ? "Listening" : "")
                    }
                }
            }
        }
    }
}

/// Drains around the mic key in the last seconds before listening stops by itself.
private struct CountdownRing: View {
    let remaining: Double

    var body: some View {
        Circle()
            .trim(from: 0, to: remaining)
            .stroke(
                DesignTokens.Colors.textPrimary,
                style: StrokeStyle(lineWidth: DesignTokens.Size.countdownRing, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .padding(DesignTokens.Size.countdownRing / 2)
            .animation(.linear(duration: 0.05), value: remaining)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private extension KeypadKey {
    var kind: KeyKind {
        switch self {
        case .digit, .decimalPoint: .tertiary
        case .backspace, .clear, .percent, .mic: .secondary
        case .add, .subtract, .multiply, .divide, .equals: .primary
        }
    }

    @ViewBuilder var label: some View {
        switch self {
        case let .digit(value): Text(String(value))
        case .decimalPoint: Text(".")
        case .clear: Text("AC")
        case .backspace: Image(systemName: "delete.backward")
        case .percent: Image(systemName: "percent")
        case .divide: Image(systemName: "divide")
        case .multiply: Image(systemName: "multiply")
        case .subtract: Image(systemName: "minus")
        case .add: Image(systemName: "plus")
        case .equals: Image(systemName: "equal")
        case .mic: Image(systemName: "mic")
        }
    }

    var accessibilityLabel: String {
        switch self {
        case let .digit(value): String(value)
        case .decimalPoint: "Decimal point"
        case .clear: "Clear all"
        case .backspace: "Delete"
        case .percent: "Percent"
        case .divide: "Divide"
        case .multiply: "Multiply"
        case .subtract: "Subtract"
        case .add: "Add"
        case .equals: "Equals"
        case .mic: "Start listening"
        }
    }
}

#Preview {
    KeypadView(onKey: { _ in })
        .padding(DesignTokens.Spacing.screenHorizontal)
        .background(DesignTokens.Colors.surface)
}
