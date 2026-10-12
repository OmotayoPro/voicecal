import Foundation
import Testing
@testable import Voicecal

/// The orb's layers, checked against values read from the Figma component
/// `button / Type=audio-input, State=Hover` (node 711:299).
struct OrbBlobTests {
    @Test func layersMatchFigmaNamesAndOrder() {
        #expect(OrbBlob.allCases.map(\.figmaName) == ["blob 3", "blob 2", "blob 1"])
        #expect(OrbBlob.allCases.map(\.figmaNodeID) == ["711:285", "711:283", "711:284"])
    }

    @Test(arguments: [
        (OrbBlob.blob3, 47.29, 49.58, 16.98),
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
        (OrbBlob.blob3, 26.29, 42.52),
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

struct OrbBlobMotionTests {
    @Test(arguments: OrbBlob.allCases)
    func startsExactlyOnTheFigmaPose(blob: OrbBlob) {
        let placement = blob.placement(at: 0)
        #expect(abs(placement.center.x - blob.center.x) < 0.001)
        #expect(abs(placement.center.y - blob.center.y) < 0.001)
        #expect(abs(placement.rotation - blob.rotation) < 0.001)
    }

    @Test(arguments: OrbBlob.allCases)
    func keepsMovingAndTurning(blob: OrbBlob) {
        let early = blob.placement(at: 1)
        let later = blob.placement(at: 2)
        let travelled = hypot(later.center.x - early.center.x, later.center.y - early.center.y)
        #expect(travelled > 1)
        #expect(abs(later.rotation - early.rotation) > 5)
    }

    @Test(arguments: OrbBlob.allCases)
    func staysInsideTheButton(blob: OrbBlob) {
        for step in 0 ... 1200 {
            let center = blob.placement(at: Double(step) * 0.1).center
            #expect((0 ... 84).contains(center.x) && (0 ... 84).contains(center.y))
        }
    }

    @Test func blobsMoveAtDifferentPaces() {
        let turned = OrbBlob.allCases.map { $0.placement(at: 3).rotation - $0.rotation }
        #expect(Set(turned.map { ($0 * 10).rounded() }).count == OrbBlob.allCases.count)
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

    private let atRest = OrbMotion.Pose(angle: OrbMotion.idleAngle, opacity: 0, drift: 0)

    @Test func restsHiddenInTheIdlePose() {
        #expect(OrbMotion().pose(at: start) == atRest)
    }

    @Test func turningOnSweepsInFromTheIdlePoseWhileFadingIn() {
        let motion = listening()
        #expect(motion.pose(at: start) == atRest)
        let halfway = motion.pose(at: after(0.15))
        #expect(abs(halfway.opacity - 0.75) < 0.001) // ease-out: most of the change comes early
        #expect(halfway.angle < OrbMotion.idleAngle && halfway.angle > 0)
        let arrived = motion.pose(at: after(OrbMotion.transition))
        #expect(arrived.opacity == 1)
        #expect(arrived.angle == 0)
    }

    @Test func blobsDriftForAsLongAsTheMicIsOn() {
        let motion = listening()
        #expect(abs(motion.pose(at: after(3)).drift - 3) < 0.001)
        #expect(abs(motion.pose(at: after(600)).drift - 600) < 0.001)
        #expect(motion.pose(at: after(600)).opacity == 1)
        #expect(motion.pose(at: after(600)).angle == 0)
    }

    @Test func turningOffSweepsBackFadesOutAndStopsTheBlobs() {
        var motion = listening()
        let before = motion.pose(at: after(5))
        motion.setActive(false, at: after(5))
        #expect(motion.pose(at: after(5)) == before)
        let done = motion.pose(at: after(5 + OrbMotion.transition))
        #expect(done.opacity == 0)
        #expect(abs(done.angle - OrbMotion.idleAngle) < 0.001)
        #expect(done.drift == before.drift)
        #expect(motion.pose(at: after(60)) == done)
    }

    @Test func turningOnAgainStartsFromTheFigmaPose() {
        var motion = listening()
        motion.setActive(false, at: after(5))
        motion.setActive(true, at: after(20))
        #expect(motion.pose(at: after(20)) == atRest)
    }

    @Test func interruptingTheFadeCarriesOnFromWhereItIs() {
        var motion = listening()
        motion.setActive(false, at: after(5))
        let midFade = motion.pose(at: after(5.1))
        motion.setActive(true, at: after(5.1))
        #expect(motion.pose(at: after(5.1)) == midFade)
        #expect(motion.pose(at: after(6)).drift > midFade.drift)
    }

    @Test func repeatedCallsWithTheSameStateChangeNothing() {
        var motion = listening()
        motion.setActive(true, at: after(4))
        #expect(abs(motion.pose(at: after(12)).drift - 12) < 0.001)
    }

    @Test func reduceMotionFadesWithoutMoving() {
        let motion = listening()
        let halfway = motion.pose(at: after(0.15), reduceMotion: true)
        #expect(halfway.angle == 0 && halfway.drift == 0)
        #expect(abs(halfway.opacity - 0.75) < 0.001)
        #expect(motion.pose(at: after(9), reduceMotion: true) == OrbMotion.Pose(angle: 0, opacity: 1, drift: 0))
    }
}
