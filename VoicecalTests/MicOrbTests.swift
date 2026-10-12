import Foundation
import Testing
@testable import Voicecal

/// The orb's layers, checked against values read from the Figma component
/// `button / Type=audio-input, State=Hover` (node 711:299).
struct OrbBlobTests {
    @Test func layersMatchFigmaNamesAndOrder() {
        #expect(OrbBlob.allCases.map(\.figmaName) == ["blob 5", "blob 4", "blob 3", "blob 2", "blob 1"])
        #expect(OrbBlob.allCases.map(\.figmaNodeID) == ["711:282", "711:286", "711:285", "711:283", "711:284"])
    }

    @Test(arguments: [
        (OrbBlob.blob5, 25.51, 41.59, 16.98),
        (.blob4, 53.71, 27.99, 65.79),
        (.blob3, 47.29, 49.58, 16.98),
        (.blob2, 42.95, 44.47, -58.02),
        (.blob1, 31.82, 22.55, -74.16)
    ])
    func geometryMatchesFigma(blob: OrbBlob, centerX: Double, centerY: Double, figmaRotation: Double) {
        #expect(abs(blob.center.x - centerX) < 0.001)
        #expect(abs(blob.center.y - centerY) < 0.001)
        // Figma measures rotation anticlockwise; SwiftUI measures it clockwise.
        #expect(abs(blob.rotation + figmaRotation) < 0.001)
    }

    /// The idle variant's blob centres, read from Figma node 711:308.
    @Test(arguments: [
        (OrbBlob.blob5, 38.95, 23.08),
        (.blob4, 45.90, 53.60),
        (.blob3, 26.29, 42.52),
        (.blob2, 32.25, 39.43),
        (.blob1, 56.10, 33.48)
    ])
    func turningAboutThePivotByTheIdleAngleLandsOnTheIdleVariant(blob: OrbBlob, idleX: Double, idleY: Double) {
        let pivot = CGPoint(x: DesignTokens.MicOrb.pivot.x * 84, y: DesignTokens.MicOrb.pivot.y * 84)
        let radians = OrbMotion.idleAngle * .pi / 180
        let offsetX = blob.center.x - pivot.x
        let offsetY = blob.center.y - pivot.y
        let turnedX = pivot.x + offsetX * cos(radians) - offsetY * sin(radians)
        let turnedY = pivot.y + offsetX * sin(radians) + offsetY * cos(radians)
        #expect(abs(turnedX - idleX) < 0.15)
        #expect(abs(turnedY - idleY) < 0.15)
    }
}

struct OrbMotionTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1000)

    private func after(_ seconds: TimeInterval) -> Date {
        start.addingTimeInterval(seconds)
    }

    private func listening() -> OrbMotion {
        var motion = OrbMotion()
        motion.setActive(true, at: start)
        return motion
    }

    @Test func restsHiddenInTheIdlePose() {
        #expect(OrbMotion().pose(at: start) == OrbMotion.Pose(angle: OrbMotion.idleAngle, opacity: 0))
    }

    @Test func turningOnSweepsInFromTheIdlePoseWhileFadingIn() {
        let motion = listening()
        #expect(motion.pose(at: start) == OrbMotion.Pose(angle: OrbMotion.idleAngle, opacity: 0))
        let halfway = motion.pose(at: after(0.15))
        #expect(abs(halfway.opacity - 0.75) < 0.001) // ease-out: most of the change comes early
        #expect(halfway.angle < OrbMotion.idleAngle && halfway.angle > 0)
        #expect(motion.pose(at: after(OrbMotion.transition)).opacity == 1)
    }

    @Test func keepsTurningAnticlockwiseWhileListening() {
        let motion = listening()
        let early = motion.pose(at: after(3)).angle
        let later = motion.pose(at: after(6)).angle
        #expect(later < early)
        #expect(abs((early - later) - 90) < 0.001) // a quarter turn every 3 of 12 seconds
        #expect(abs(motion.pose(at: after(12)).angle + 360) < 0.001)
        #expect(motion.pose(at: after(600)).opacity == 1)
    }

    @Test func turningOffSweepsBackAndFadesOut() {
        var motion = listening()
        let before = motion.pose(at: after(5))
        motion.setActive(false, at: after(5))
        #expect(motion.pose(at: after(5)) == before)
        let done = motion.pose(at: after(5 + OrbMotion.transition))
        #expect(done.opacity == 0)
        #expect(abs(done.angle - (before.angle + OrbMotion.idleAngle)) < 0.001)
        #expect(motion.pose(at: after(60)) == done) // it stops turning
    }

    @Test func turningOnAgainStartsFromTheIdlePose() {
        var motion = listening()
        motion.setActive(false, at: after(5))
        motion.setActive(true, at: after(20))
        #expect(motion.pose(at: after(20)) == OrbMotion.Pose(angle: OrbMotion.idleAngle, opacity: 0))
    }

    @Test func interruptingTheFadeCarriesOnFromWhereItIs() {
        var motion = listening()
        motion.setActive(false, at: after(5))
        let midFade = motion.pose(at: after(5.1))
        motion.setActive(true, at: after(5.1))
        let resumed = motion.pose(at: after(5.1))
        #expect(resumed.opacity == midFade.opacity)
        #expect(abs(resumed.angle) <= 180)
    }

    @Test func repeatedCallsWithTheSameStateChangeNothing() {
        var motion = listening()
        motion.setActive(true, at: after(4))
        #expect(abs(motion.pose(at: after(12)).angle + 360) < 0.001)
    }

    @Test func reduceMotionFadesWithoutTurning() {
        let motion = listening()
        let halfway = motion.pose(at: after(0.15), reduceMotion: true)
        #expect(halfway.angle == 0)
        #expect(abs(halfway.opacity - 0.75) < 0.001)
        #expect(motion.pose(at: after(9), reduceMotion: true) == OrbMotion.Pose(angle: 0, opacity: 1))
    }
}
