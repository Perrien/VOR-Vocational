import CoreGraphics
import Foundation

/// Pure scenario proof and raw measurements for the still-air Practice exercise.
nonisolated enum MovingPositionChallenge {
    static let speedKnots = 260.0
    static let guaranteedSeconds = 600.0

    struct Scenario {
        let initialState: FlightAircraftState
        let firstExit: FlightPhysics.Trajectory.ChartExit
        var trajectory: FlightPhysics.Trajectory {
            .init(start: initialState, selectedHeading: initialState.heading, conditions: .calm)
        }

        fileprivate init(initialState: FlightAircraftState, firstExit: FlightPhysics.Trajectory.ChartExit) {
            self.initialState = initialState
            self.firstExit = firstExit
        }
    }

    struct Estimate: Equatable {
        let position: CGPoint
        let heading: Double
        static let initial = Self(position: CGPoint(x: 0.5, y: 0.5), heading: 0)
    }

    enum Ending: Equatable {
        case submitted, leftChart
        var label: String { self == .submitted ? "Submitted" : "Left the chart" }
    }

    struct Result: Equatable {
        let estimate: Estimate
        let actual: FlightAircraftState
        let elapsedSeconds: TimeInterval
        let ending: Ending
        let distanceErrorNM: Double
        let headingErrorDegrees: Double

        init(estimate: Estimate, actual: FlightAircraftState, elapsedSeconds: TimeInterval, ending: Ending) {
            self.estimate = estimate
            self.actual = actual
            self.elapsedSeconds = elapsedSeconds
            self.ending = ending
            distanceErrorNM = VORNavigation.distanceNM(fromNormalized: estimate.position,
                toNormalized: actual.normalizedPosition, mapWidthNM: FlightWorld.widthNM, mapHeightNM: FlightWorld.heightNM)
            headingErrorDegrees = abs(VORNavigation.normalize180(estimate.heading - actual.heading))
        }
    }

    static func scenario(start: CGPoint, heading: Double, stations: [VORStation]) -> Scenario? {
        guard let candidate = straightScenario(start: start, heading: heading),
              candidate.firstExit.elapsed >= guaranteedSeconds,
              hasContinuousCoverage(from: start,
                to: candidate.trajectory.state(at: guaranteedSeconds).normalizedPosition, stations: stations) else { return nil }
        return candidate
    }

    static func randomScenario<R: RandomNumberGenerator>(stations: [VORStation], using random: inout R,
                                                         maxAttempts: Int = 1_000) -> Scenario? {
        for _ in 0..<max(0, maxAttempts) {
            let start = CGPoint(x: Double.random(in: 0.1...0.9, using: &random),
                                y: Double.random(in: 0.1...0.9, using: &random))
            let heading = Double(Int.random(in: 0..<360, using: &random))
            if let scenario = scenario(start: start, heading: heading, stations: stations) { return scenario }
        }
        return nil
    }

    /// Each station covers a closed interval of the straight segment. Coverage can only
    /// change at an interval endpoint; checking every resulting interval proves the path.
    static func hasContinuousCoverage(from start: CGPoint, to end: CGPoint, stations: [VORStation]) -> Bool {
        guard start.x.isFinite, start.y.isFinite, end.x.isFinite, end.y.isFinite else { return false }
        let origin = FlightWorld.nauticalMiles(for: start)
        let finish = FlightWorld.nauticalMiles(for: end)
        let dx = finish.x - origin.x, dy = finish.y - origin.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared.isFinite else { return false }
        var seen = Set<String>()
        let unique = stations.filter { seen.insert($0.id).inserted }
        guard unique.allSatisfy({ $0.relativePosition.x.isFinite && $0.relativePosition.y.isFinite
            && $0.rangeNM.isFinite && $0.rangeNM >= 0 }) else { return false }
        if lengthSquared == 0 {
            return unique.filter { distance(from: start, to: $0) <= $0.rangeNM }.count >= 2
        }

        let intervals: [(station: VORStation, range: ClosedRange<Double>)] = unique.compactMap { station in
            let center = FlightWorld.nauticalMiles(for: station.relativePosition)
            let x = center.x - origin.x, y = center.y - origin.y
            let projection = (x * dx + y * dy) / lengthSquared
            let cross = x * dy - y * dx
            let perpendicularSquared = cross * cross / lengthSquared
            let radiusSquared = station.rangeNM * station.rangeNM
            guard perpendicularSquared <= radiusSquared else { return nil }
            let halfInterval = sqrt((radiusSquared - perpendicularSquared) / lengthSquared)
            let entry = projection - halfInterval, exit = projection + halfInterval
            // Round inward, never widen a service range or bridge an uncertain gap.
            // Endpoints already beyond the segment remain clipped at exactly 0 and 1.
            let lower = entry <= 0 ? 0 : entry.nextUp
            let upper = exit >= 1 ? 1 : exit.nextDown
            guard lower <= upper, upper >= 0, lower <= 1 else { return nil }
            return (station, lower...upper)
        }
        guard intervals.count >= 2 else { return false }
        let cuts = Array(Set([0.0, 1.0] + intervals.flatMap { [$0.range.lowerBound, $0.range.upperBound] })).sorted()
        func covered(_ fraction: Double) -> Bool {
            let point = FlightWorld.normalizedPosition(for:
                CGPoint(x: origin.x + dx * fraction, y: origin.y + dy * fraction))
            return intervals.filter { $0.range.contains(fraction) && distance(from: point, to: $0.station) <= $0.station.rangeNM }.count >= 2
        }
        return cuts.allSatisfy(covered) && zip(cuts, cuts.dropFirst()).allSatisfy { a, b in covered(a + (b - a) / 2) }
    }

    private static func distance(from point: CGPoint, to station: VORStation) -> Double {
        VORNavigation.distanceNM(fromNormalized: point, toNormalized: station.relativePosition,
                                mapWidthNM: FlightWorld.widthNM, mapHeightNM: FlightWorld.heightNM)
    }

    private static func straightScenario(start: CGPoint, heading: Double) -> Scenario? {
        guard start.x.isFinite, start.y.isFinite, heading.isFinite,
              (0...1).contains(start.x), (0...1).contains(start.y) else { return nil }
        let state = FlightAircraftState(normalizedPosition: start, heading: heading, speedKnots: speedKnots)
        let trajectory = FlightPhysics.Trajectory(start: state, selectedHeading: state.heading, conditions: .calm)
        let horizon = hypot(FlightWorld.widthNM, FlightWorld.heightNM) / (speedKnots / 3_600) + 1
        guard let exit = try? trajectory.firstChartExit(through: horizon) else { return nil }
        return Scenario(initialState: state, firstExit: exit)
    }

    #if DEBUG
    /// Development fixture only: deliberately bypasses the production ten-minute/radio proof.
    static func debugNearExitScenario() -> Scenario? {
        straightScenario(start: FlightWorld.normalizedPosition(for:
            CGPoint(x: FlightWorld.widthNM - speedKnots * 5 / 3_600, y: 150)), heading: 90)
    }
    #endif
}
