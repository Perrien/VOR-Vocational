import Foundation

/// Immutable still-air planning values. Inputs are independent of instructions,
/// chart presentation, and the aircraft's actual progress or wind conditions.
nonisolated struct MissionTimingSchedule: Equatable {
    nonisolated enum StartupPolicy: Equatable {
        case manual
        case firstLegOnFirstPlay
    }

    nonisolated struct LegInput: Equatable {
        let startLabel: String
        let endLabel: String
        let distanceNM: Double
    }

    nonisolated struct Leg: Equatable, Identifiable {
        /// Zero-based geometric route order; repeated endpoint labels are valid.
        let index: Int
        let startLabel: String
        let endLabel: String
        let distanceNM: Double
        let plannedDurationSeconds: TimeInterval
        let plannedReachSeconds: TimeInterval

        var id: Int { index }
        var number: Int { index + 1 }
    }

    nonisolated enum ValidationIssue: Equatable {
        case emptyLegs
        case invalidPlanningAirspeed
        case invalidDistance(legNumber: Int)
        case invalidDuration(legNumber: Int)
        case nonFiniteCumulativeTime(legNumber: Int)

        var reason: String {
            switch self {
            case .emptyLegs:
                return "No timing legs were supplied."
            case .invalidPlanningAirspeed:
                return "Planning airspeed must be finite and greater than zero."
            case .invalidDistance(let number):
                return "Leg \(number) needs a finite distance greater than zero."
            case .invalidDuration(let number):
                return "Leg \(number)'s duration cannot be represented at this planning airspeed."
            case .nonFiniteCumulativeTime(let number):
                return "Planned flight time through leg \(number) exceeds the timing range."
            }
        }
    }

    nonisolated enum Availability: Equatable {
        case available([Leg])
        case unavailable(ValidationIssue)
    }

    let planningAirspeedKnots: Double
    let startupPolicy: StartupPolicy
    let availability: Availability

    /// Nil means invalid supplied timing, never a valid-looking empty schedule.
    /// A mission's optional schedule distinguishes this from absent timing.
    var legs: [Leg]? {
        guard case .available(let legs) = availability else { return nil }
        return legs
    }

    init(legs: [LegInput], planningAirspeedKnots: Double,
         startupPolicy: StartupPolicy = .manual) {
        self.planningAirspeedKnots = planningAirspeedKnots
        self.startupPolicy = startupPolicy
        availability = Self.validate(legs, planningAirspeedKnots: planningAirspeedKnots)
    }

    /// Every geometric leg participates, including a final leg without NAV guidance.
    init(resolvedPlan: ResolvedFlightPlan) {
        self.init(
            legs: resolvedPlan.legs.map {
                LegInput(startLabel: $0.start.name, endLabel: $0.end.name, distanceNM: $0.distanceNM)
            },
            planningAirspeedKnots: resolvedPlan.stillAirEstimate.cruiseSpeedKnots,
            startupPolicy: .firstLegOnFirstPlay
        )
    }

    private static func validate(_ inputs: [LegInput], planningAirspeedKnots: Double) -> Availability {
        guard !inputs.isEmpty else { return .unavailable(.emptyLegs) }
        guard planningAirspeedKnots.isFinite, planningAirspeedKnots > 0 else {
            return .unavailable(.invalidPlanningAirspeed)
        }

        var result: [Leg] = []
        var reachSeconds = 0.0
        for (index, input) in inputs.enumerated() {
            guard input.distanceNM.isFinite, input.distanceNM > 0 else {
                return .unavailable(.invalidDistance(legNumber: index + 1))
            }
            let durationSeconds = input.distanceNM / planningAirspeedKnots * 3_600
            guard durationSeconds.isFinite, durationSeconds > 0 else {
                return .unavailable(.invalidDuration(legNumber: index + 1))
            }
            reachSeconds += durationSeconds
            guard reachSeconds.isFinite else {
                return .unavailable(.nonFiniteCumulativeTime(legNumber: index + 1))
            }
            result.append(Leg(index: index, startLabel: input.startLabel, endLabel: input.endLabel,
                              distanceNM: input.distanceNM, plannedDurationSeconds: durationSeconds,
                              plannedReachSeconds: reachSeconds))
        }
        return .available(result)
    }
}
