import Foundation

/// When listening should stop by itself.
struct InactivityPolicy: Equatable {
    /// Stop after this long with no activity. Nil turns the inactivity stop off.
    var timeout: Duration? = .seconds(10)
    /// Stop after this long regardless of activity.
    var hardCap: Duration = .seconds(180)
    /// How long before a stop the mic shows its countdown.
    var warning: Duration = .seconds(3)
}

enum ListeningDeadline: Equatable {
    case active
    /// The final seconds before stopping. `remaining` runs from 1 down to 0.
    case closing(remaining: Double)
    case expired
}

/// The timing rules as pure logic: every question takes "now" as a parameter,
/// so tests never have to wait.
struct InactivityTracker {
    let policy: InactivityPolicy
    let startedAt: ContinuousClock.Instant
    private(set) var lastActivityAt: ContinuousClock.Instant

    init(policy: InactivityPolicy, now: ContinuousClock.Instant) {
        self.policy = policy
        startedAt = now
        lastActivityAt = now
    }

    /// Activity is recognized words or any manual input. Silence and background noise are not.
    mutating func noteActivity(at now: ContinuousClock.Instant) {
        lastActivityAt = now
    }

    func deadline(at now: ContinuousClock.Instant) -> ListeningDeadline {
        var remaining = policy.hardCap - (now - startedAt)
        if let timeout = policy.timeout {
            remaining = min(remaining, timeout - (now - lastActivityAt))
        }
        if remaining <= .zero {
            return .expired
        }
        if remaining <= policy.warning {
            return .closing(remaining: remaining / policy.warning)
        }
        return .active
    }
}

/// Runs an `InactivityTracker` against the real clock and reports changes.
@MainActor
final class InactivityTimer {
    var onChange: ((ListeningDeadline) -> Void)?

    private let clock = ContinuousClock()
    private let tick: Duration
    private var tracker: InactivityTracker?
    private var loop: Task<Void, Never>?
    private var lastReported = ListeningDeadline.active

    init(tick: Duration = .milliseconds(50)) {
        self.tick = tick
    }

    func start(policy: InactivityPolicy) {
        stop()
        tracker = InactivityTracker(policy: policy, now: clock.now)
        loop = Task { [weak self, tick] in
            while !Task.isCancelled {
                try? await Task.sleep(for: tick)
                self?.evaluate()
            }
        }
    }

    func noteActivity() {
        tracker?.noteActivity(at: clock.now)
        evaluate()
    }

    func stop() {
        loop?.cancel()
        loop = nil
        tracker = nil
        report(.active)
    }

    private func evaluate() {
        guard let tracker else { return }
        let deadline = tracker.deadline(at: clock.now)
        if deadline == .expired {
            loop?.cancel()
            loop = nil
            self.tracker = nil
        }
        report(deadline)
    }

    private func report(_ deadline: ListeningDeadline) {
        guard deadline != lastReported else { return }
        lastReported = deadline
        onChange?(deadline)
    }
}
