import Foundation

/// Player-declared still-air progress. Only accepted simulated time and airspeed
/// enter this model; it has no aircraft, wind, receiver, or recording inputs.
nonisolated struct MissionLegTiming: Equatable {
    nonisolated struct Context: Equatable {
        let legIndex: Int
        let startedAtSeconds: TimeInterval
        private(set) var estimatedDistanceNM = 0.0
        private(set) var expirySeconds: TimeInterval?
        private(set) var arithmeticIsValid = true
        private var distanceCompensation = 0.0

        init(legIndex: Int, startedAtSeconds: TimeInterval) {
            self.legIndex = legIndex
            self.startedAtSeconds = startedAtSeconds
        }

        mutating func advance(distanceNM: Double, startingAt start: TimeInterval,
                              seconds: TimeInterval, airspeedKnots: Double) {
            guard expirySeconds == nil, arithmeticIsValid else { return }
            let travel = airspeedKnots / 3_600 * seconds
            let adjusted = travel - distanceCompensation
            let proposed = estimatedDistanceNM + adjusted
            guard travel.isFinite, proposed.isFinite else {
                arithmeticIsValid = false
                return
            }
            if proposed >= distanceNM {
                let untilExpiry = (distanceNM - estimatedDistanceNM) / airspeedKnots * 3_600
                let expiry = start + min(seconds, untilExpiry)
                guard expiry.isFinite else { arithmeticIsValid = false; return }
                expirySeconds = expiry
                estimatedDistanceNM = distanceNM
                distanceCompensation = 0
            } else {
                distanceCompensation = (proposed - estimatedDistanceNM) - adjusted
                estimatedDistanceNM = proposed
            }
        }
    }

    nonisolated enum CurrentEstimate: Equatable {
        case notStarted
        case selectLeg
        case remaining(seconds: TimeInterval, reachSeconds: TimeInterval)
        case pastEstimate(seconds: TimeInterval, reachSeconds: TimeInterval)
        case zeroAirspeed
        case unavailable
    }

    nonisolated enum DurationEstimate: Equatable {
        case available(TimeInterval)
        case zeroAirspeed
        case unavailable
    }

    nonisolated struct Display: Equatable {
        let currentLeg: MissionTimingSchedule.Leg?
        let current: CurrentEstimate
        let nextLeg: MissionTimingSchedule.Leg?
        let nextDuration: DurationEstimate?
    }

    let schedule: MissionTimingSchedule
    private(set) var selectedContext: Context?
    private var undoContext: Context?
    private(set) var canUndo = false
    private(set) var hasHandledFirstPlay = false

    init(schedule: MissionTimingSchedule) { self.schedule = schedule }

    mutating func firstPlay(at seconds: TimeInterval) {
        guard !hasHandledFirstPlay, seconds.isFinite, seconds >= 0 else { return }
        hasHandledFirstPlay = true
        if selectedContext == nil, schedule.startupPolicy == .firstLegOnFirstPlay,
           let first = schedule.legs?.first {
            selectedContext = Context(legIndex: first.index, startedAtSeconds: seconds)
        }
    }

    mutating func startLeg(at index: Int, flightTime: TimeInterval) {
        guard let legs = schedule.legs, legs.indices.contains(index),
              flightTime.isFinite, flightTime >= 0 else { return }
        undoContext = selectedContext
        canUndo = true
        selectedContext = Context(legIndex: index, startedAtSeconds: flightTime)
    }

    mutating func undoStart() {
        guard canUndo else { return }
        selectedContext = undoContext
        undoContext = nil
        canUndo = false
    }

    /// Both contexts receive the same accepted interval, so Undo restores the
    /// estimate the previous selection would have now, across speed changes.
    mutating func advance(startingAt start: TimeInterval, seconds: TimeInterval, airspeedKnots: Double) {
        guard let legs = schedule.legs, start.isFinite, start >= 0,
              seconds.isFinite, seconds > 0, airspeedKnots.isFinite, airspeedKnots >= 0 else { return }
        if let index = selectedContext?.legIndex {
            selectedContext?.advance(distanceNM: legs[index].distanceNM, startingAt: start,
                                     seconds: seconds, airspeedKnots: airspeedKnots)
        }
        if let index = undoContext?.legIndex {
            undoContext?.advance(distanceNM: legs[index].distanceNM, startingAt: start,
                                 seconds: seconds, airspeedKnots: airspeedKnots)
        }
    }

    func display(at flightTime: TimeInterval, airspeedKnots: Double) -> Display {
        let legs = schedule.legs
        let preparingFirstLeg = !hasHandledFirstPlay && schedule.startupPolicy == .firstLegOnFirstPlay
        let index = selectedContext?.legIndex ?? (preparingFirstLeg ? legs?.first?.index : nil)
        let currentLeg = index.flatMap { legs?[$0] }
        let nextLeg = index.flatMap { index in
            legs.flatMap { $0.indices.contains(index + 1) ? $0[index + 1] : nil }
        }
        let nextDuration = nextLeg.map { Self.duration(distanceNM: $0.distanceNM, airspeedKnots: airspeedKnots) }
        return Display(currentLeg: currentLeg,
                       current: currentEstimate(at: flightTime, airspeedKnots: airspeedKnots),
                       nextLeg: nextLeg, nextDuration: nextDuration)
    }

    private func currentEstimate(at flightTime: TimeInterval, airspeedKnots: Double) -> CurrentEstimate {
        guard let legs = schedule.legs, flightTime.isFinite, flightTime >= 0,
              airspeedKnots.isFinite, airspeedKnots >= 0 else { return .unavailable }
        guard let context = selectedContext else {
            return !hasHandledFirstPlay && schedule.startupPolicy == .firstLegOnFirstPlay ? .notStarted : .selectLeg
        }
        guard context.arithmeticIsValid else { return .unavailable }
        if let expiry = context.expirySeconds {
            let past = flightTime - expiry
            guard past.isFinite, past >= 0 else { return .unavailable }
            return .pastEstimate(seconds: past, reachSeconds: expiry)
        }
        switch Self.duration(distanceNM: legs[context.legIndex].distanceNM - context.estimatedDistanceNM,
                             airspeedKnots: airspeedKnots) {
        case .available(let remaining):
            let reach = flightTime + remaining
            guard reach.isFinite else { return .unavailable }
            return .remaining(seconds: remaining, reachSeconds: reach)
        case .zeroAirspeed: return .zeroAirspeed
        case .unavailable: return .unavailable
        }
    }

    private static func duration(distanceNM: Double, airspeedKnots: Double) -> DurationEstimate {
        guard airspeedKnots.isFinite, airspeedKnots >= 0 else { return .unavailable }
        guard airspeedKnots > 0 else { return .zeroAirspeed }
        let seconds = distanceNM / airspeedKnots * 3_600
        guard seconds.isFinite, seconds > 0 else { return .unavailable }
        return .available(seconds)
    }
}
