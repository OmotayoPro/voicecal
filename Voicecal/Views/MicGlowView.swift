import SwiftUI

/// The glowing orb inside the mic key (Figma `audio-input`, state Hover): five blurred blobs
/// added together over the key's base fill. It fades in and out with `isActive`, and while
/// active each blob keeps turning about its own centre. Place it inside a circle clip.
struct MicGlowView: View {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: !isActive || reduceMotion)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            ZStack {
                blobLayer(at: time)
                // Figma tops the blobs with a glass ellipse that refracts their light out to the rim.
                // Glass effects need iOS 26, so a wider, softer copy of the blobs stands in for it.
                blobLayer(at: time)
                    .scaleEffect(DesignTokens.MicGlow.spreadScale)
                    .blur(radius: DesignTokens.MicGlow.spreadBlur)
                    .opacity(DesignTokens.MicGlow.spreadOpacity)
                    .blendMode(.plusLighter)
            }
        }
        .frame(width: DesignTokens.Size.key, height: DesignTokens.Size.key)
        // Faded as one layer, then added onto the key, so the transition stays soft.
        .opacity(isActive ? 1 : 0)
        .blendMode(.plusLighter)
        .animation(.easeInOut(duration: DesignTokens.MicGlow.fadeDuration), value: isActive)
        .accessibilityHidden(true)
    }

    private func blobLayer(at time: TimeInterval) -> some View {
        ZStack {
            ForEach(Self.blobs.indices, id: \.self) { index in
                let blob = Self.blobs[index]
                SVGPath(blob.path)
                    .fill(blob.color)
                    .frame(width: blob.size.width, height: blob.size.height)
                    .blur(radius: DesignTokens.MicGlow.blur)
                    .rotationEffect(.degrees(blob.rotation + time * 360 / blob.secondsPerTurn))
                    .position(blob.center)
                    .blendMode(.plusLighter)
            }
        }
        .frame(width: DesignTokens.Size.key, height: DesignTokens.Size.key)
    }

    private struct Blob {
        let path: String
        let size: CGSize
        let center: CGPoint
        /// Resting angle from Figma, in degrees.
        let rotation: Double
        /// Time for one full turn. Negative turns anticlockwise. Each blob differs, so the orb never repeats visibly.
        let secondsPerTurn: Double
        let color: Color
    }

    /// Geometry and path data are taken as-is from the Figma component (nodes 711:282–286).
    private static let blobs: [Blob] = [
        Blob(
            path: flame, size: CGSize(width: 83, height: 80),
            center: CGPoint(x: 25.51, y: 41.59),
            rotation: -16.98, secondsPerTurn: 14, color: DesignTokens.MicGlow.light
        ),
        Blob(
            path: flame, size: CGSize(width: 83, height: 80),
            center: CGPoint(x: 53.71, y: 27.99),
            rotation: -65.79, secondsPerTurn: -18, color: DesignTokens.MicGlow.light
        ),
        Blob(
            path: wideFlame, size: CGSize(width: 84, height: 80),
            center: CGPoint(x: 47.29, y: 49.58),
            rotation: -16.98, secondsPerTurn: 22, color: DesignTokens.MicGlow.deep
        ),
        Blob(
            path: smallFlame, size: CGSize(width: 73.4334, height: 71.6353),
            center: CGPoint(x: 42.95, y: 44.47),
            rotation: 58.02, secondsPerTurn: -11, color: DesignTokens.MicGlow.core
        ),
        Blob(
            path: tallFlame, size: CGSize(width: 60.4672, height: 100.253),
            center: CGPoint(x: 31.82, y: 22.55),
            rotation: 74.16, secondsPerTurn: 16, color: DesignTokens.MicGlow.core
        )
    ]

    private static let flame = """
    M36.2888 21.1371C31.1824 17.0582 23.7888 24.9283 20.7303 29.3732C18.7356 33.2952 20.7303 35.2562 27.9111 \
    31.7264C35.092 34.0796 23.9218 41.1391 25.5175 52.9051C27.1133 64.671 40.6771 58.788 55.4378 56.4349C70.1984 \
    54.0817 60.624 50.5519 49.8527 45.4533C39.0814 40.3547 43.4697 39.9625 44.2676 33.6874C45.0654 27.4122 \
    42.6718 26.2356 36.2888 21.1371Z
    """
    private static let wideFlame = """
    M36.6676 21.1371C31.4425 17.0582 23.8769 24.9283 20.7473 29.3732C18.7062 33.2952 20.7473 35.2562 28.0951 \
    31.7264C35.443 34.0796 24.013 41.1391 25.6458 52.9051C27.2787 64.671 41.158 58.788 56.2619 56.4349C71.3658 \
    54.0817 61.5687 50.5519 50.5469 45.4533C39.5251 40.3547 44.0155 39.9625 44.8319 33.6874C45.6483 27.4122 \
    43.1991 26.2356 36.6676 21.1371Z
    """
    private static let smallFlame = """
    M32.6649 20.8993C28.6946 17.6734 22.9459 23.8977 20.5678 27.4131C19.0169 30.5149 20.5678 32.0658 26.1511 \
    29.2742C31.7344 31.1353 23.0493 36.7186 24.29 46.024C25.5307 55.3295 36.0769 50.6768 47.5537 48.8157C59.0304 \
    46.9546 51.586 44.1629 43.2111 40.1306C34.8362 36.0982 38.2482 35.788 38.8686 30.8251C39.4889 25.8622 \
    37.6278 24.9316 32.6649 20.8993Z
    """
    private static let tallFlame = """
    M27.7532 21.7128C25.3226 15.5687 21.8034 27.4237 20.3476 34.1192C19.3982 40.027 20.3476 42.9809 23.7656 \
    37.6638C27.1835 41.2085 21.8667 51.8426 22.6262 69.566C23.3858 87.2894 29.8419 78.4277 36.8677 74.883C43.8936 \
    71.3383 39.3363 66.0213 34.2093 58.3412C29.0824 50.661 31.1711 50.0702 31.5509 40.6177C31.9307 31.1653 \
    30.7914 29.3929 27.7532 21.7128Z
    """
}

/// Draws SVG path data made of absolute M, C and Z commands, which is all Figma exported here.
private struct SVGPath: Shape {
    private let commands: [(Character, [CGFloat])]

    init(_ data: String) {
        var commands: [(Character, [CGFloat])] = []
        var number = ""
        func flush() {
            if let value = Double(number), !commands.isEmpty {
                commands[commands.count - 1].1.append(value)
            }
            number = ""
        }
        for character in data {
            if character.isLetter {
                flush()
                commands.append((character, []))
            } else if character.isNumber || character == "." || character == "-" {
                number.append(character)
            } else {
                flush()
            }
        }
        flush()
        self.commands = commands
    }

    func path(in _: CGRect) -> Path {
        var path = Path()
        for (command, values) in commands {
            switch command {
            case "M" where values.count >= 2:
                path.move(to: CGPoint(x: values[0], y: values[1]))
            case "C":
                for start in stride(from: 0, to: values.count - 5, by: 6) {
                    path.addCurve(
                        to: CGPoint(x: values[start + 4], y: values[start + 5]),
                        control1: CGPoint(x: values[start], y: values[start + 1]),
                        control2: CGPoint(x: values[start + 2], y: values[start + 3])
                    )
                }
            case "Z":
                path.closeSubpath()
            default:
                break
            }
        }
        return path
    }
}

#Preview {
    MicGlowView(isActive: true)
        .background(DesignTokens.Colors.secondaryDefault)
        .clipShape(Circle())
        .padding()
        .background(DesignTokens.Colors.surface)
}
