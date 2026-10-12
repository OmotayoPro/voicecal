import Foundation

/// Where the orb's blob group is at a given moment: how far it is turned and how visible it is.
///
/// This follows the Figma prototype. The idle variant holds the blobs hidden and turned 102.92°
/// clockwise, as one group, from where they sit in the listening variant, and tapping
/// smart-animates between the two over 0.3 s with ease-out. Turning the mic on therefore sweeps
/// the group anticlockwise into place while it fades in; from there it keeps turning the same
/// way until the mic is turned off, when it sweeps back and fades out.
///
/// Pure logic: every question takes the time as a parameter.
struct OrbMotion {
    /// Figma: smart animate, 300 ms, ease out.
    static let transition: TimeInterval = 0.3
    /// How far the idle variant's blob group is turned, clockwise, relative to the listening variant.
    static let idleAngle: Double = 102.92
    /// One full turn of the blob group while listening.
    static let secondsPerTurn: TimeInterval = 12

    struct Pose: Equatable {
        /// Clockwise degrees to turn the blob group about its pivot. Zero is the listening pose in Figma.
        var angle: Double
        var opacity: Double
    }

    private var isActive = false
    private var changedAt = Date.distantPast
    /// Starts as if the mic had been turned off long ago from the listening pose.
    private var poseAtChange = Pose(angle: 0, opacity: 0)

    mutating func setActive(_ active: Bool, at now: Date) {
        guard active != isActive else { return }
        var current = pose(at: now)
        if active {
            // From rest, start at the idle variant's pose. If the orb is caught mid-fade, carry on
            // from where it is, by the shorter way round.
            current.angle = current.opacity == 0
                ? Self.idleAngle
                : (current.angle + 180).truncatingRemainder(dividingBy: 360) - 180
        }
        poseAtChange = current
        isActive = active
        changedAt = now
    }

    func pose(at now: Date, reduceMotion: Bool = false) -> Pose {
        let elapsed = max(now.timeIntervalSince(changedAt), 0)
        let progress = Self.easeOut(min(elapsed / Self.transition, 1))
        if isActive {
            let opacity = poseAtChange.opacity + (1 - poseAtChange.opacity) * progress
            guard !reduceMotion else { return Pose(angle: 0, opacity: opacity) }
            let sweep = poseAtChange.angle * (1 - progress)
            let spin = -360 * elapsed / Self.secondsPerTurn
            return Pose(angle: sweep + spin, opacity: opacity)
        }
        let opacity = poseAtChange.opacity * (1 - progress)
        guard !reduceMotion else { return Pose(angle: 0, opacity: opacity) }
        return Pose(angle: poseAtChange.angle + Self.idleAngle * progress, opacity: opacity)
    }

    private static func easeOut(_ value: Double) -> Double {
        1 - (1 - value) * (1 - value)
    }
}
