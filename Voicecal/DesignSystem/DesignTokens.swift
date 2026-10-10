import SwiftUI

/// Values extracted from the Figma file (Pro Playground › ios-calculator-ui).
/// Colors live in `Assets.xcassets/Colors`, named after their Figma variables.
enum DesignTokens {
    enum Colors {
        static let surface = Color(.surfaceDefault)
        static let textPrimary = Color(.textPrimary)
        static let textPending = Color(.textPending)

        static let primaryDefault = Color(.buttonsPrimaryDefault)
        static let primaryPressed = Color(.buttonsPrimaryHover)
        static let primaryRing = Color(.primary700)

        static let secondaryDefault = Color(.buttonsSecondaryDefault)
        static let secondaryPressed = Color(.buttonsSecondaryHover)

        static let tertiaryDefault = Color(.buttonsTertiaryDefault)
        static let tertiaryPressed = Color(.buttonsTertiaryHover)

        static let neutralRing = Color(.neutral700)

        /// White highlight used for key gloss and inset edge highlights.
        static let highlight = Color.white
    }

    enum Spacing {
        static let screenHorizontal: CGFloat = 16
        /// Gap below the keypad, measured from the bottom safe area.
        static let screenBottom: CGFloat = 14
        /// Gap between the toolbar slot, the display and the keypad.
        static let section: CGFloat = 8
        static let keypadRow: CGFloat = 10
        static let displayPadding: CGFloat = 8
    }

    enum Size {
        static let key: CGFloat = 84
        static let toolbarButton: CGFloat = 40
        static let keyRing: CGFloat = 1
    }

    enum Opacity {
        static let keyGloss: Double = 0.2
        static let edgeHighlightStrong: Double = 0.5
        static let edgeHighlightTop: Double = 0.2
        static let edgeHighlightBottom: Double = 0.3
    }

    enum Typography {
        static let display = Font.system(size: 64, weight: .regular)
        static let key = Font.system(size: 32, weight: .medium)
    }
}
