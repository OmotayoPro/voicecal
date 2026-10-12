import Foundation

/// Where the orb is at a given moment: how far the blob group is turned, how visible it is,
/// and how long the blobs have been drifting.
///
/// The transition follows the Figma prototype. The idle variant holds the blobs hidden and turned
/// 102.92° clockwise, as one group, from where they sit in the listening variant, and tapping
/// smart-animates between the two over 0.3 s with ease-out. Turning the mic on therefore sweeps
/// the group into place while it fades in. Figma stops there; in the app the blobs then keep
/// moving for as long as the mic is on (see `OrbBlob.placement(at:)`), so the orb reads as live.
///
/// Pure logic: every question takes the time as a parameter.
struct OrbMotion {
    /// Figma: smart animate, 300 ms, ease out.
    static let transition: TimeInterval = 0.3
    /// How far the idle variant's blob group is turned, clockwise, relative to the listening variant.
    static let idleAngle: Double = 102.92

    struct Pose: Equatable {
        /// Clockwise degrees to turn the blob group about its pivot. Zero is the listening pose in Figma.
        var angle: Double
        var opacity: Double
        /// Seconds the blobs have spent moving. Zero puts every blob exactly where Figma has it.
        var drift: TimeInterval
    }

    private var isActive = false
    private var changedAt = Date.distantPast
    /// Starts as if the mic had been turned off long ago from the listening pose.
    private var poseAtChange = Pose(angle: 0, opacity: 0, drift: 0)

    mutating func setActive(_ active: Bool, at now: Date) {
        guard active != isActive else { return }
        var current = pose(at: now)
        if active, current.opacity == 0 {
            // From rest, start at the idle variant's pose with the blobs where Figma has them.
            // Caught mid-fade, it carries on from wherever it is instead.
            current.angle = Self.idleAngle
            current.drift = 0
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
            guard !reduceMotion else { return Pose(angle: 0, opacity: opacity, drift: 0) }
            return Pose(
                angle: poseAtChange.angle * (1 - progress),
                opacity: opacity,
                drift: poseAtChange.drift + elapsed
            )
        }
        let opacity = poseAtChange.opacity * (1 - progress)
        guard !reduceMotion else { return Pose(angle: 0, opacity: opacity, drift: 0) }
        // The blobs hold still while the group sweeps back and fades.
        return Pose(
            angle: poseAtChange.angle + Self.idleAngle * progress,
            opacity: opacity,
            drift: poseAtChange.drift
        )
    }

    private static func easeOut(_ value: Double) -> Double {
        1 - (1 - value) * (1 - value)
    }
}
