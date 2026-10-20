import CoreGraphics
import Foundation
import Observation

/// The frequency, selected course, and tuning behavior of one physical NAV receiver.
struct NAVReceiver: Equatable {
    var wholeMHz: Int = 108
    var fineStep: Int = 0
    var obs: Int = 0
    /// Whether this receiver currently has an active tuned frequency. A failed
    /// out-of-range ident selection clears it, so stale reception cannot keep
    /// driving the indicator.
    var hasActiveFrequency = true

    var frequencyHundredths: Int {
        wholeMHz * 100 + fineStep * 5
    }

    var frequencyLabel: String {
        guard hasActiveFrequency else { return "---.--" }
        return String(format: "%.2f", Double(frequencyHundredths) / 100)
    }

    mutating func adjustWhole(by amount: Int) {
        wholeMHz = min(max(wholeMHz + amount, 108), 117)
        hasActiveFrequency = true
    }

    mutating func adjustFine(by amount: Int) {
        fineStep = (fineStep + amount % 20 + 20) % 20
        hasActiveFrequency = true
    }

    mutating func adjustOBS(by amount: Int) {
        obs = (obs + amount % 360 + 360) % 360
    }

    /// Sets the channel directly from a known station's frequency (e.g. a
    /// resolved ident lookup), bypassing the whole/fine knob adjustments.
    mutating func tune(toFrequencyHundredths frequencyHundredths: Int) {
        wholeMHz = frequencyHundredths / 100
        fineStep = (frequencyHundredths % 100) / 5
        hasActiveFrequency = true
    }

    /// Clears the displayed and active frequency without replacing it with a
    /// made-up channel. The last physical knob position is retained so a
    /// subsequent adjustment can retune the receiver.
    mutating func clearFrequency() {
        hasActiveFrequency = false
    }
}

/// Per-flight state shared by the reusable flight surface and its cockpit.
@Observable
final class FlightSession {
    var normalizedAircraftPosition: CGPoint
    /// Nose heading; wind can make the ground track differ.
    var heading: Double = 0
    /// The heading selected with the heading knob. The aircraft turns toward
    /// this target at the simulation's bounded turn rate.
    var selectedHeading: Double = 0
    var speedKnots: Double = 260
    private var flightIsPlaying = false
    var isFlying: Bool {
        get { flightIsPlaying && completion == nil && simulationError == nil && !hasLeftMission }
        set {
            let willPlay = newValue && completion == nil && simulationError == nil && !hasLeftMission
            if willPlay && !flightIsPlaying { legTiming?.firstPlay(at: elapsedSimulatedSeconds) }
            flightIsPlaying = willPlay
        }
    }
    var timeMultiplier: Double = 1
    /// Transient launcher choice; each timing context consumes its own return.
    var returnsToNormalPlayback = false
    /// Elapsed simulation time, including the selected playback multiplier.
    /// A mission completion records this value; it is not a score or ETA.
    private(set) var elapsedSimulatedSeconds: TimeInterval = 0
    let conditions: FlightConditions
    let mission: MissionFlightDefinition?
    private(set) var completion: MissionFlightCompletion?
    private(set) var recording: FlightRecording?
    private(set) var simulationError: String?
    private(set) var legTiming: MissionLegTiming?
    private(set) var hasLeftMission = false
    private var clockCompensation = 0.0
    var nav1 = NAVReceiver()
    var nav2 = NAVReceiver()

    var zoom: CGFloat = 1
    var pan: CGSize = .zero
    var showVORs = true
    var visibleVORServiceVolumes = Set(VORServiceVolume.allCases)
    var showAirports = true
    var showRadials = true
    var showGrid = false
    var showSightseeingRegions = false
    var showSightseeingRegionNames = false
    var gridSizeNM: Double = 50
    var selectedVORID: String?
    var cdiMax: Double = 10

    init(initialState: FlightAircraftState, conditions: FlightConditions = .calm,
         mission: MissionFlightDefinition? = nil) {
        normalizedAircraftPosition = initialState.normalizedPosition
        heading = initialState.heading
        selectedHeading = initialState.heading
        speedKnots = initialState.speedKnots
        self.conditions = conditions
        self.mission = mission
        legTiming = mission?.timingSchedule.map { MissionLegTiming(schedule: $0) }
        recording = mission == nil ? nil : FlightRecording(initialState: initialState)
    }

    convenience init(normalizedAirportPosition: CGPoint) {
        self.init(initialState: FlightAircraftState(normalizedPosition: normalizedAirportPosition))
    }

    convenience init(mission: MissionFlightDefinition, conditions: FlightConditions) {
        self.init(initialState: mission.initialState, conditions: conditions, mission: mission)
    }

    var aircraftState: FlightAircraftState {
        FlightAircraftState(normalizedPosition: normalizedAircraftPosition,
                            heading: heading, speedKnots: speedKnots)
    }

    var timingDisplay: MissionLegTiming.Display? {
        legTiming?.display(at: elapsedSimulatedSeconds, airspeedKnots: speedKnots)
    }

    var canAdjustMissionTiming: Bool {
        mission != nil && completion == nil && simulationError == nil && !hasLeftMission
    }

    func startMissionLeg(at index: Int) {
        guard canAdjustMissionTiming else { return }
        legTiming?.startLeg(at: index, flightTime: elapsedSimulatedSeconds)
    }

    func undoMissionLegStart() {
        guard canAdjustMissionTiming else { return }
        legTiming?.undoStart()
    }

    func leaveMission() {
        isFlying = false
        if mission != nil { hasLeftMission = true }
    }

    /// The only live advancement entry point. Pause/completion guard stale ticks.
    func advance(wallElapsed: TimeInterval) {
        guard isFlying, completion == nil, wallElapsed.isFinite, wallElapsed > 0,
              timeMultiplier.isFinite, timeMultiplier > 0,
              heading.isFinite, selectedHeading.isFinite,
              speedKnots.isFinite, speedKnots >= 0 else { return }
        let elapsed = wallElapsed * timeMultiplier
        guard elapsed.isFinite else { return }
        if returnsToNormalPlayback, timeMultiplier > 1,
           let untilReturn = legTiming?.secondsUntilPlaybackReturn(at: elapsedSimulatedSeconds,
                                                                  airspeedKnots: speedKnots) {
            let wallUntilReturn = untilReturn / timeMultiplier
            if wallUntilReturn <= wallElapsed {
                // A zero-time threshold still gives an outward chart crossing
                // at this instant priority over the playback action.
                advance(simulatedElapsed: untilReturn, immediateExitLookahead: untilReturn == 0 ? elapsed : nil)
                guard isFlying else { return }
                legTiming?.consumePlaybackReturn()
                timeMultiplier = 1
                let remainingWall = wallElapsed - wallUntilReturn
                if remainingWall > 0 { advance(simulatedElapsed: remainingWall) }
                return
            }
        }
        advance(simulatedElapsed: elapsed)
    }

    /// One accepted trajectory segment. Ordinary playback retains the original
    /// clock compensation, first-exit solver, and integer recording schedule.
    private func advance(simulatedElapsed elapsed: TimeInterval, immediateExitLookahead: TimeInterval? = nil) {
        let trajectory = FlightPhysics.Trajectory(start: aircraftState,
                                                 selectedHeading: selectedHeading,
                                                 conditions: conditions)
        let startTime = elapsedSimulatedSeconds
        let adjusted = immediateExitLookahead == nil ? elapsed - clockCompensation : 0
        let proposedEnd = startTime + adjusted
        guard proposedEnd.isFinite else { return }
        let duration = proposedEnd - startTime
        let exit: FlightPhysics.Trajectory.ChartExit?
        do {
            let candidate = try mission == nil ? nil : trajectory.firstChartExit(
                through: immediateExitLookahead ?? duration, startingAt: startTime)
            exit = immediateExitLookahead == nil ? candidate : candidate.flatMap { $0.elapsed == 0 ? $0 : nil }
        } catch {
            isFlying = false
            simulationError = error.localizedDescription
            return
        }
        if immediateExitLookahead != nil, exit == nil { return }
        let endTime = exit.map { startTime + $0.elapsed } ?? proposedEnd
        let next = exit?.state ?? trajectory.state(at: duration)
        recording?.record(trajectory, startingAt: startTime, through: endTime)
        legTiming?.advance(startingAt: startTime, seconds: endTime - startTime, airspeedKnots: speedKnots)
        clockCompensation = exit == nil ? (proposedEnd - startTime) - adjusted : 0
        normalizedAircraftPosition = next.normalizedPosition
        heading = next.heading
        elapsedSimulatedSeconds = endTime
        if exit != nil { finishMission(ending: .leftChart) }
    }

    @discardableResult
    func completeMission() -> MissionFlightCompletion? {
        finishMission(ending: .playerCompleted)
    }

    @discardableResult
    private func finishMission(ending: MissionFlightEnding) -> MissionFlightCompletion? {
        if let completion { return completion }
        guard let mission else { return nil }
        isFlying = false
        recording?.finish(at: elapsedSimulatedSeconds, state: aircraftState)
        let result = MissionFlightCompletion(mission: mission, recording: recording!.samples,
                                             conditions: conditions, ending: ending)
        completion = result
        return result
    }

    func freshMissionSession() -> FlightSession {
        guard let mission else { preconditionFailure("Retry requires a mission definition.") }
        let fresh = FlightSession(mission: mission, conditions: conditions)
        fresh.returnsToNormalPlayback = returnsToNormalPlayback
        return fresh
    }

    func swapNAVReceivers() {
        swap(&nav1, &nav2)
    }
}

/// A Debug-only scene registry for the currently visible live-flight session.
@Observable
final class FlightDiagnosticsStore {
    var activeSession: FlightSession?
}
