import SwiftUI

/// The orb inside the mic key while listening. It mirrors the Figma component
/// `button / Type=audio-input`, layer for layer, bottom to top:
///
///     blob 3, blob 2, blob 1   blurred vectors, added together (linear dodge)
///     glass                    an ellipse with Figma's glass effect
///     icon                     drawn by the key itself
///
/// In Figma the idle variant holds the same layers, hidden, with the blobs turned as one group;
/// tapping smart-animates between the variants. `OrbMotion` reproduces that sweep. After it,
/// each blob keeps circling and turning at its own pace for as long as the mic is on, which is
/// the feedback that the mic is live.
///
/// The view draws the key's own fill beneath the blobs, because the glass has to bend the
/// finished picture, fill included. Place it over the key's surface, inside a circle clip.
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
                keyFill
                blobs(at: pose.drift)
                    .rotationEffect(.degrees(pose.angle), anchor: DesignTokens.MicOrb.pivot)
                    .blendMode(.plusLighter)
            }
            .frame(width: DesignTokens.Size.key, height: DesignTokens.Size.key)
            .layerEffect(glass, maxSampleOffset: DesignTokens.MicOrb.glassMaxBend)
            .opacity(pose.opacity)
        }
        .frame(width: DesignTokens.Size.key, height: DesignTokens.Size.key)
        .accessibilityHidden(true)
        .onChange(of: isActive, initial: true) { _, isActive in
            motion.setActive(isActive, at: .now)
            settle()
        }
    }

    /// The same fill and gloss as the idle mic key.
    private var keyFill: some View {
        ZStack {
            DesignTokens.Colors.secondaryDefault
            LinearGradient(
                colors: [DesignTokens.Colors.highlight.opacity(DesignTokens.Opacity.keyGloss), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    /// Figma layers `blob 3` to `blob 1`, in layer order, each where its own motion has taken it.
    private func blobs(at drift: TimeInterval) -> some View {
        ZStack {
            ForEach(OrbBlob.allCases, id: \.self) { blob in
                let placement = blob.placement(at: drift)
                SVGPath(blob.path)
                    .fill(blob.color)
                    .frame(width: blob.size.width, height: blob.size.height)
                    .blur(radius: DesignTokens.MicOrb.blobBlur)
                    .rotationEffect(.degrees(placement.rotation))
                    .position(placement.center)
                    .blendMode(.plusLighter)
            }
        }
        .frame(width: DesignTokens.Size.key, height: DesignTokens.Size.key)
    }

    /// Figma layer `glass`, as a Metal shader (`Shaders/OrbGlass.metal`) taking Figma's own
    /// glass settings. It bends the blobs' light out to the rim and adds the rim highlights.
    private var glass: Shader {
        let light = DesignTokens.MicOrb.glassLightAngle * .pi / 180
        return ShaderLibrary.orbGlass(
            .float2(DesignTokens.Size.key, DesignTokens.Size.key),
            .float(DesignTokens.MicOrb.glassRefraction),
            .float(DesignTokens.MicOrb.glassDepth),
            .float(DesignTokens.MicOrb.glassDispersion),
            // Figma measures the angle from straight up, so -45° is the top left.
            .float2(sin(light), -cos(light)),
            .float(DesignTokens.MicOrb.glassLightIntensity)
        )
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

/// The blurred vectors of the orb. Case names, order, geometry and colors match the
/// Figma layers of `Type=audio-input, State=Hover` (node 711:299).
enum OrbBlob: CaseIterable {
    // Bottom to top, as in the Figma layer list.
    case blob3
    case blob2
    case blob1

    var figmaName: String {
        switch self {
        case .blob3: "blob 3"
        case .blob2: "blob 2"
        case .blob1: "blob 1"
        }
    }

    var figmaNodeID: String {
        switch self {
        case .blob3: "711:285"
        case .blob2: "711:283"
        case .blob1: "711:284"
        }
    }

    /// Centre of the layer inside the 84 pt key, in the listening pose.
    var center: CGPoint {
        switch self {
        case .blob3: CGPoint(x: 47.29, y: 49.58)
        case .blob2: CGPoint(x: 42.95, y: 44.47)
        case .blob1: CGPoint(x: 31.82, y: 22.55)
        }
    }

    /// Clockwise degrees in the listening pose (Figma reports the same angles anticlockwise).
    var rotation: Double {
        switch self {
        case .blob3: -16.98
        case .blob2: 58.02
        case .blob1: 74.16
        }
    }

    var color: Color {
        switch self {
        case .blob3: DesignTokens.MicOrb.blobDeep
        case .blob2, .blob1: DesignTokens.MicOrb.blobCore
        }
    }

    // MARK: Motion while listening

    /// How this blob moves once the mic is on. Every blob circles the pivot the same way round,
    /// but each at its own speed, breathing in and out from the pivot and turning on itself at
    /// its own rate, so the light keeps shifting and never visibly repeats.
    private var motion: BlobMotion {
        switch self {
        case .blob3: BlobMotion(orbit: 12, breath: 5.2, reach: 0.3, spin: 16)
        case .blob2: BlobMotion(orbit: 5.5, breath: 3.7, reach: 0.6, spin: -8)
        case .blob1: BlobMotion(orbit: 8, breath: 4.9, reach: 0.2, spin: 11)
        }
    }

    private struct BlobMotion {
        /// Seconds to circle the pivot once.
        let orbit: TimeInterval
        /// Seconds for one move out from the pivot and back.
        let breath: TimeInterval
        /// How far that move goes, as a share of the blob's distance from the pivot.
        let reach: Double
        /// Seconds for one turn about its own centre. Negative turns the other way.
        let spin: TimeInterval
    }

    /// Where the blob is, and how it is turned, after `drift` seconds of listening.
    /// At zero this is exactly the Figma listening pose.
    func placement(at drift: TimeInterval) -> (center: CGPoint, rotation: Double) {
        let pivot = CGPoint(
            x: DesignTokens.MicOrb.pivot.x * DesignTokens.Size.key,
            y: DesignTokens.MicOrb.pivot.y * DesignTokens.Size.key
        )
        // Anticlockwise, continuing the direction of the sweep that brings the orb in.
        let orbitDegrees = -360 * drift / motion.orbit
        let radians = orbitDegrees * .pi / 180
        let reach = 1 + motion.reach * sin(2 * .pi * drift / motion.breath)
        let offsetX = (center.x - pivot.x) * reach
        let offsetY = (center.y - pivot.y) * reach
        let moved = CGPoint(
            x: pivot.x + offsetX * cos(radians) - offsetY * sin(radians),
            y: pivot.y + offsetX * sin(radians) + offsetY * cos(radians)
        )
        return (moved, rotation + orbitDegrees + 360 * drift / motion.spin)
    }

    /// Size of the exported artwork: the vector plus 20 pt of room on every side for its blur.
    var size: CGSize {
        switch self {
        case .blob3: CGSize(width: 84, height: 80)
        case .blob2: CGSize(width: 73.4334, height: 71.6353)
        case .blob1: CGSize(width: 60.4672, height: 100.253)
        }
    }

    /// Path data as exported from Figma.
    var path: String {
        switch self {
        case .blob3: Self.wideFlame
        case .blob2: Self.smallFlame
        case .blob1: Self.tallFlame
        }
    }

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
