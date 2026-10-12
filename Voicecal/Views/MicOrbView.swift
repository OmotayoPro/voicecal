import SwiftUI

/// The orb inside the mic key while listening. It mirrors the Figma component
/// `button / Type=audio-input`, layer for layer, bottom to top:
///
///     blob 5, blob 4, blob 3, blob 2, blob 1   blurred vectors, added together (linear dodge)
///     glass                                    an ellipse with Figma's glass effect
///     icon                                     drawn by the key itself
///
/// In Figma the idle variant holds the same layers, hidden, with the five blobs turned as one
/// group; tapping smart-animates between the variants. `OrbMotion` reproduces that sweep and
/// then keeps the group turning for as long as the mic is on. Place this inside a circle clip.
struct MicOrbView: View {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var motion = OrbMotion()
    /// Keeps frames coming while the orb fades out after the mic is turned off.
    @State private var isSettling = false

    var body: some View {
        TimelineView(.animation(paused: !isActive && !isSettling)) { context in
            let pose = motion.pose(at: context.date, reduceMotion: reduceMotion)
            ZStack {
                blobs
                    .rotationEffect(.degrees(pose.angle), anchor: DesignTokens.MicOrb.pivot)
                    .opacity(pose.opacity * blobStrength)
                    .blendMode(.plusLighter)
                glass(blobAngle: pose.angle)
                    .opacity(pose.opacity)
            }
        }
        .frame(width: DesignTokens.Size.key, height: DesignTokens.Size.key)
        .accessibilityHidden(true)
        .onChange(of: isActive, initial: true) { _, isActive in
            motion.setActive(isActive, at: .now)
            settle()
        }
    }

    /// The system glass brightens what it refracts more than Figma's does, so the blobs
    /// are toned down beneath it to land on the same overall brightness.
    private var blobStrength: Double {
        if #available(iOS 26.0, *) {
            DesignTokens.MicOrb.blobStrengthUnderGlass
        } else {
            1
        }
    }

    /// Figma layers `blob 5` to `blob 1`, in layer order.
    private var blobs: some View {
        ZStack {
            ForEach(OrbBlob.allCases, id: \.self) { blob in
                SVGPath(blob.path)
                    .fill(blob.color)
                    .frame(width: blob.size.width, height: blob.size.height)
                    .blur(radius: DesignTokens.MicOrb.blobBlur)
                    .rotationEffect(.degrees(blob.rotation))
                    .position(blob.center)
                    .blendMode(.plusLighter)
            }
        }
        .frame(width: DesignTokens.Size.key, height: DesignTokens.Size.key)
    }

    /// Figma layer `glass`: a clear ellipse whose glass effect refracts the blobs beneath it.
    @ViewBuilder
    private func glass(blobAngle: Double) -> some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(.clear, in: .circle)
        } else {
            // No glass before iOS 26. A wider, softer copy of the blobs stands in for the way
            // the glass spreads their light towards the rim.
            blobs
                .rotationEffect(.degrees(blobAngle), anchor: DesignTokens.MicOrb.pivot)
                .scaleEffect(DesignTokens.MicOrb.fallbackSpreadScale)
                .blur(radius: DesignTokens.MicOrb.fallbackSpreadBlur)
                .opacity(DesignTokens.MicOrb.fallbackSpreadOpacity)
                .blendMode(.plusLighter)
        }
    }

    private func settle() {
        guard !isActive else {
            isSettling = false
            return
        }
        isSettling = true
        Task {
            try? await Task.sleep(for: .seconds(OrbMotion.transition + 0.1))
            if !isActive {
                isSettling = false
            }
        }
    }
}

/// The five blurred vectors of the orb. Case names, order, geometry and colors match the
/// Figma layers of `Type=audio-input, State=Hover` (node 711:299).
enum OrbBlob: CaseIterable {
    // Bottom to top, as in the Figma layer list.
    case blob5
    case blob4
    case blob3
    case blob2
    case blob1

    var figmaName: String {
        switch self {
        case .blob5: "blob 5"
        case .blob4: "blob 4"
        case .blob3: "blob 3"
        case .blob2: "blob 2"
        case .blob1: "blob 1"
        }
    }

    var figmaNodeID: String {
        switch self {
        case .blob5: "711:282"
        case .blob4: "711:286"
        case .blob3: "711:285"
        case .blob2: "711:283"
        case .blob1: "711:284"
        }
    }

    /// Centre of the layer inside the 84 pt key, in the listening pose.
    var center: CGPoint {
        switch self {
        case .blob5: CGPoint(x: 25.51, y: 41.59)
        case .blob4: CGPoint(x: 53.71, y: 27.99)
        case .blob3: CGPoint(x: 47.29, y: 49.58)
        case .blob2: CGPoint(x: 42.95, y: 44.47)
        case .blob1: CGPoint(x: 31.82, y: 22.55)
        }
    }

    /// Clockwise degrees in the listening pose (Figma reports the same angles anticlockwise).
    var rotation: Double {
        switch self {
        case .blob5: -16.98
        case .blob4: -65.79
        case .blob3: -16.98
        case .blob2: 58.02
        case .blob1: 74.16
        }
    }

    var color: Color {
        switch self {
        case .blob5, .blob4: DesignTokens.MicOrb.blobLight
        case .blob3: DesignTokens.MicOrb.blobDeep
        case .blob2, .blob1: DesignTokens.MicOrb.blobCore
        }
    }

    /// Size of the exported artwork: the vector plus 20 pt of room on every side for its blur.
    var size: CGSize {
        switch self {
        case .blob5, .blob4: CGSize(width: 83, height: 80)
        case .blob3: CGSize(width: 84, height: 80)
        case .blob2: CGSize(width: 73.4334, height: 71.6353)
        case .blob1: CGSize(width: 60.4672, height: 100.253)
        }
    }

    /// Path data as exported from Figma.
    var path: String {
        switch self {
        case .blob5, .blob4: Self.roundFlame
        case .blob3: Self.wideFlame
        case .blob2: Self.smallFlame
        case .blob1: Self.tallFlame
        }
    }

    static let roundFlame = """
    M36.2888 21.1371C31.1824 17.0582 23.7888 24.9283 20.7303 29.3732C18.7356 33.2952 20.7303 35.2562 27.9111 \
    31.7264C35.092 34.0796 23.9218 41.1391 25.5175 52.9051C27.1133 64.671 40.6771 58.788 55.4378 56.4349C70.1984 \
    54.0817 60.624 50.5519 49.8527 45.4533C39.0814 40.3547 43.4697 39.9625 44.2676 33.6874C45.0654 27.4122 \
    42.6718 26.2356 36.2888 21.1371Z
    """
    static let wideFlame = """
    M36.6676 21.1371C31.4425 17.0582 23.8769 24.9283 20.7473 29.3732C18.7062 33.2952 20.7473 35.2562 28.0951 \
    31.7264C35.443 34.0796 24.013 41.1391 25.6458 52.9051C27.2787 64.671 41.158 58.788 56.2619 56.4349C71.3658 \
    54.0817 61.5687 50.5519 50.5469 45.4533C39.5251 40.3547 44.0155 39.9625 44.8319 33.6874C45.6483 27.4122 \
    43.1991 26.2356 36.6676 21.1371Z
    """
    static let smallFlame = """
    M32.6649 20.8993C28.6946 17.6734 22.9459 23.8977 20.5678 27.4131C19.0169 30.5149 20.5678 32.0658 26.1511 \
    29.2742C31.7344 31.1353 23.0493 36.7186 24.29 46.024C25.5307 55.3295 36.0769 50.6768 47.5537 48.8157C59.0304 \
    46.9546 51.586 44.1629 43.2111 40.1306C34.8362 36.0982 38.2482 35.788 38.8686 30.8251C39.4889 25.8622 \
    37.6278 24.9316 32.6649 20.8993Z
    """
    static let tallFlame = """
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
    MicOrbView(isActive: true)
        .background(DesignTokens.Colors.secondaryDefault)
        .clipShape(Circle())
        .padding()
        .background(DesignTokens.Colors.surface)
}
