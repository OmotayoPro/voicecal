import SwiftUI

/// Values extracted from the Figma file (Pro Playground › ios-calculator-ui_by OmotayoTaiwo).
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

        /// Cursor glow while listening (one-off values on the Figma cursor layer).
        static let cursorGlowCool = Color(red: 0.663, green: 1, blue: 0.996)
        static let cursorGlowWarm = Color(red: 0.933, green: 0.624, blue: 0)
    }

    enum Spacing {
        static let screenHorizontal: CGFloat = 16
        /// Gap below the keypad, measured from the bottom safe area.
        static let screenBottom: CGFloat = 14
        /// Gap between the toolbar slot, the display and the keypad.
        static let section: CGFloat = 8
        static let keypadRow: CGFloat = 10
        static let displayPadding: CGFloat = 8
        /// Width of the invisible tap strip centred on each token boundary. Tokens themselves sit flush.
        static let cursorTapWidth: CGFloat = 16
        /// How far the focused-token box extends past the glyphs.
        static let chipOutset: CGFloat = 3
    }

    enum Size {
        static let key: CGFloat = 84
        static let toolbarButton: CGFloat = 40
        static let keyRing: CGFloat = 1
        static let countdownRing: CGFloat = 3
        static let minTapTarget: CGFloat = 44
        static let cursorWidth: CGFloat = 2
        /// Cursor height as a share of the display font size.
        static let cursorHeightRatio: CGFloat = 60.0 / 64.0
        static let chipRadius: CGFloat = 14
        static let cursorGlowRadius: CGFloat = 12
        static let cursorGlowOffset: CGFloat = 8
    }

    enum Opacity {
        static let keyGloss: Double = 0.2
        static let secondaryText: Double = 0.55
        static let edgeHighlightStrong: Double = 0.5
        static let edgeHighlightTop: Double = 0.2
        static let edgeHighlightBottom: Double = 0.3
    }

    /// The listening mic key's orb (Figma `button / Type=audio-input, State=Hover`).
    enum MicOrb {
        /// `buttons/primary-hover`, on blob 5 and blob 4.
        static let blobLight = Color(.buttonsPrimaryHover)
        /// `buttons/primary-default` and `yellow/500` (the same orange), on blob 2 and blob 1.
        static let blobCore = Color(.buttonsPrimaryDefault)
        /// `yellow/900`, on blob 3.
        static let blobDeep = Color(.yellow900)
        /// Figma layer blur 20, which is a blur radius of 10 here.
        static let blobBlur: CGFloat = 10
        /// The point the blob group turns about, as a fraction of the key. Derived from the two
        /// Figma variants: it is the one point that maps every idle blob onto its listening position.
        static let pivot = UnitPoint(x: 39.6 / 84, y: 37.7 / 84)

        // The hand-built glass layer.
        static let glassTint: Double = 0.38
        static let glassSpreadScale: CGFloat = 1.5
        static let glassSpreadBlur: CGFloat = 10
        static let glassSpreadOpacity: Double = 0.3
    }

    enum Typography {
        /// The display size at the default text size; it scales with Dynamic Type.
        static let displaySize: CGFloat = 64
        static let key = Font.system(size: 32, weight: .medium)
        static let smallKey = Font.system(size: 16, weight: .medium)
        static let liveResult = Font.system(size: 28, weight: .regular)
        static let notice = Font.footnote
    }
}
