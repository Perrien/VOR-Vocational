import CoreGraphics
import Foundation
import Observation

/// Owns truth and elapsed awake time. The chart session owns presentation/receiver settings only.
@MainActor @Observable
final class MovingPositionChallengeSession {
    enum Phase { case ready, active, generationFailed, completed, abandoned }
    enum Receiver { case nav1, nav2 }

    let surface = FlightSession(normalizedAirportPosition: CGPoint(x: 0.5, y: 0.5))
    private(set) var phase: Phase = .ready
    private(set) var attemptID = UUID()
    private(set) var estimate = MovingPositionChallenge.Estimate.initial
    private(set) var actualState: FlightAircraftState?
    private(set) var elapsedSeconds = 0.0
    private(set) var result: MovingPositionChallenge.Result?
    @ObservationIgnored private var scenario: MovingPositionChallenge.Scenario?
    @ObservationIgnored private var anchor: TimeInterval?
    @ObservationIgnored private let now: () -> TimeInterval
    @ObservationIgnored private let generate: () -> MovingPositionChallenge.Scenario?

    var isActive: Bool { phase == .active }

    init(now: (() -> TimeInterval)? = nil, scenarioFactory: (() -> MovingPositionChallenge.Scenario?)? = nil) {
        if let now { self.now = now }
        else {
            let clock = SuspendingClock()
            let epoch = clock.now
            self.now = {
                let value = epoch.duration(to: clock.now).components
                return Double(value.seconds) + Double(value.attoseconds) / 1e18
            }
        }
        generate = scenarioFactory ?? {
            var random = SystemRandomNumberGenerator()
            return MovingPositionChallenge.randomScenario(stations: VORStation.myosia, using: &random)
        }
        surface.showAirports = false
    }

    func begin() {
        attemptID = UUID()
        phase = .ready
        anchor = nil
        scenario = nil
        result = nil
        actualState = nil
        elapsedSeconds = 0
        estimate = .initial
        surface.isFlying = false
        surface.heading = 0
        surface.selectedHeading = 0
        surface.normalizedAircraftPosition = CGPoint(x: 0.5, y: 0.5)
        surface.speedKnots = MovingPositionChallenge.speedKnots
        surface.timeMultiplier = 1
        surface.nav1 = NAVReceiver()
        surface.nav2 = NAVReceiver()
        surface.selectedVORID = nil
        surface.zoom = 1
        surface.pan = .zero
        guard let generated = generate() else { phase = .generationFailed; return }
        let instant = now()
        guard instant.isFinite else { phase = .generationFailed; return }
        scenario = generated
        actualState = generated.initialState
        anchor = instant
        phase = .active
    }

    /// Delayed refreshes catch up from the original anchor; they never accumulate nominal frames.
    func refresh(for id: UUID) {
        guard id == attemptID, isActive else { return }
        synchronize(at: now())
    }

    private func synchronize(at instant: TimeInterval) {
        guard isActive, let scenario, let anchor, instant.isFinite else { return }
        let elapsed = max(elapsedSeconds, instant - anchor)
        if elapsed >= scenario.firstExit.elapsed {
            elapsedSeconds = scenario.firstExit.elapsed
            actualState = scenario.firstExit.state
            finish(.leftChart)
        } else {
            elapsedSeconds = elapsed
            actualState = scenario.trajectory.state(at: elapsed)
        }
    }

    func submit(for id: UUID) {
        guard id == attemptID, isActive else { return }
        synchronize(at: now())
        if isActive { finish(.submitted) }
    }

    @discardableResult
    private func canEdit(for id: UUID) -> Bool {
        guard id == attemptID, isActive else { return false }
        synchronize(at: now())
        return isActive
    }

    func setPosition(_ position: CGPoint, for id: UUID) {
        guard canEdit(for: id), position.x.isFinite, position.y.isFinite else { return }
        estimate = .init(position: CGPoint(x: min(1, max(0, position.x)), y: min(1, max(0, position.y))), heading: estimate.heading)
    }

    func setHeading(_ heading: Double, for id: UUID) {
        guard canEdit(for: id), heading.isFinite else { return }
        estimate = .init(position: estimate.position, heading: FlightPhysics.normalizedHeading(heading.rounded()))
    }

    func setReceiver(_ value: NAVReceiver, receiver: Receiver, for id: UUID) {
        guard canEdit(for: id) else { return }
        switch receiver {
        case .nav1: surface.nav1 = value
        case .nav2: surface.nav2 = value
        }
    }

    func swapReceivers(for id: UUID) {
        guard canEdit(for: id) else { return }
        surface.swapNAVReceivers()
    }

    func abandon() {
        attemptID = UUID()
        phase = .abandoned
        anchor = nil
        scenario = nil
        actualState = nil
        result = nil
        elapsedSeconds = 0
        estimate = .initial
        surface.isFlying = false
    }

    private func finish(_ ending: MovingPositionChallenge.Ending) {
        guard result == nil, let actualState else { return }
        result = .init(estimate: estimate, actual: actualState, elapsedSeconds: elapsedSeconds, ending: ending)
        phase = .completed
        anchor = nil
    }

    nonisolated static func elapsedLabel(_ elapsed: TimeInterval) -> String {
        let seconds = max(0, Int(elapsed.rounded(.down)))
        return seconds < 3_600 ? String(format: "%d:%02d", seconds / 60, seconds % 60)
            : String(format: "%d:%02d:%02d", seconds / 3_600, seconds % 3_600 / 60, seconds % 60)
    }
}
