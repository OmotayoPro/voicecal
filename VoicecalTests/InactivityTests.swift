import Foundation
import Testing
@testable import Voicecal

struct InactivityTrackerTests {
    private let start = ContinuousClock.now

    private func tracker(_ policy: InactivityPolicy = InactivityPolicy()) -> InactivityTracker {
        InactivityTracker(policy: policy, now: start)
    }

    private func after(_ seconds: Double) -> ContinuousClock.Instant {
        start.advanced(by: .seconds(seconds))
    }

    @Test func defaultsMatchTheSpec() {
        let policy = InactivityPolicy()
        #expect(policy.timeout == .seconds(10))
        #expect(policy.hardCap == .seconds(180))
        #expect(policy.warning == .seconds(3))
    }

    @Test func staysActiveUntilTheWarningWindow() {
        #expect(tracker().deadline(at: after(0)) == .active)
        #expect(tracker().deadline(at: after(6.9)) == .active)
    }

    @Test func countsDownOverTheLastThreeSeconds() {
        #expect(tracker().deadline(at: after(7)) == .closing(remaining: 1))
        #expect(tracker().deadline(at: after(8.5)) == .closing(remaining: 0.5))
    }

    @Test func expiresAtTheTimeout() {
        #expect(tracker().deadline(at: after(10)) == .expired)
        #expect(tracker().deadline(at: after(60)) == .expired)
    }

    @Test func activityResetsTheTimeoutAndCancelsTheCountdown() {
        var tracker = tracker()
        #expect(tracker.deadline(at: after(9)) == .closing(remaining: 1.0 / 3))
        tracker.noteActivity(at: after(9))
        #expect(tracker.deadline(at: after(9)) == .active)
        #expect(tracker.deadline(at: after(18.9)) != .expired)
        #expect(tracker.deadline(at: after(19)) == .expired)
    }

    @Test func hardCapStopsEvenWithConstantActivity() {
        var tracker = tracker()
        for second in stride(from: 1.0, through: 179, by: 1) {
            tracker.noteActivity(at: after(second))
        }
        #expect(tracker.deadline(at: after(176.9)) == .active)
        #expect(tracker.deadline(at: after(178.5)) == .closing(remaining: 0.5))
        #expect(tracker.deadline(at: after(180)) == .expired)
    }

    @Test func timeoutOffLeavesOnlyTheHardCap() {
        let tracker = tracker(InactivityPolicy(timeout: nil))
        #expect(tracker.deadline(at: after(120)) == .active)
        #expect(tracker.deadline(at: after(180)) == .expired)
    }

    @Test(arguments: [5.0, 15, 30])
    func otherTimeouts(seconds: Double) {
        let tracker = tracker(InactivityPolicy(timeout: .seconds(seconds)))
        #expect(tracker.deadline(at: after(seconds - 3.1)) == .active)
        #expect(tracker.deadline(at: after(seconds)) == .expired)
    }
}

/// The timer wired into the view model, using a very short real timeout.
@MainActor
struct InactivityStopTests {
    private let speech = FakeSpeechRecognizer()
    private let policy = InactivityPolicy(timeout: .milliseconds(250), warning: .milliseconds(100))

    private func makeViewModel() async -> CalculatorViewModel {
        let viewModel = CalculatorViewModel(speech: speech, pauseBeforeCommit: .seconds(60), inactivityPolicy: policy)
        await viewModel.startListening()
        return viewModel
    }

    @Test func stopsListeningAndCommitsWhenNothingHappens() async throws {
        let viewModel = await makeViewModel()
        speech.hear("four plus four")
        try await Task.sleep(for: .milliseconds(800))
        #expect(!viewModel.isListening)
        #expect(speech.stopCount == 1)
        #expect(viewModel.micCountdown == nil)
        #expect(viewModel.equation.tokens.map(\.text) == ["4", "+", "4"])
        #expect(viewModel.equation.pendingTokenIDs.isEmpty)
    }

    @Test func activityKeepsTheMicOn() async throws {
        let viewModel = await makeViewModel()
        for step in 1 ... 6 {
            try await Task.sleep(for: .milliseconds(100))
            if step.isMultiple(of: 2) {
                viewModel.handle(.digit(step))
            } else {
                speech.hear(String(repeating: "one ", count: step))
            }
        }
        #expect(viewModel.isListening)
    }

    @Test func timingOutMidEditKeepsTheEdit() async throws {
        let viewModel = await makeViewModel()
        viewModel.handle(.digit(1))
        viewModel.handle(.add)
        viewModel.handle(.digit(2))
        let target = viewModel.equation.tokens[0].id
        viewModel.tapToken(id: target)
        try await Task.sleep(for: .milliseconds(800))
        #expect(!viewModel.isListening)
        #expect(viewModel.equation.editingTokenID == target)
        #expect(viewModel.equation.tokens.map(\.text) == ["1", "+", "2"])
    }

    @Test func silenceFromTheRecognizerIsNotActivity() async throws {
        let viewModel = await makeViewModel()
        speech.hear("nine")
        for _ in 1 ... 6 {
            try await Task.sleep(for: .milliseconds(100))
            speech.hear("nine") // same words again: nothing new was said
        }
        #expect(!viewModel.isListening)
    }
}
