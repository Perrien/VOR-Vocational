import CoreGraphics
import Foundation

/// Pure flight math. Live motion uses a direct trajectory in physical NM.
nonisolated enum FlightPhysics {
    /// The first-pass turn rate for the teaching simulation. The flight loop
    /// supplies simulated elapsed time, so playback speed scales the rate just
    /// as it scales aircraft movement.
    static let turnRateDegreesPerSecond = 3.0

    /// Turns the aircraft's actual heading toward a selected heading without
    /// exceeding `turnRateDegreesPerSecond`. A 180° change consistently turns
    /// right, and the result always remains in 0..<360.
    static func turn(heading: Double, toward selectedHeading: Double,
                     elapsed: TimeInterval,
                     turnRateDegreesPerSecond: Double = turnRateDegreesPerSecond) -> Double {
        let current = normalizedHeading(heading)
        let target = normalizedHeading(selectedHeading)
        let maximumTurn = max(0, turnRateDegreesPerSecond) * max(0, elapsed)
        guard maximumTurn > 0 else { return current }

        let difference = signedHeadingDifference(from: current, to: target)
        guard abs(difference) > maximumTurn + angularRoundoff else { return target }
        return normalizedHeading(current + (difference > 0 ? maximumTurn : -maximumTurn))
    }

    /// Returns the new position after flying `speedKnots` on `heading` for
    /// `elapsed` seconds, starting from `position`. `pixelsPerNM` converts the
    /// simulated distance into map-space points; `bounds` clamps the result to
    /// the map area.
    static func advance(position: CGPoint, heading: Double, speedKnots: Double,
                        elapsed: TimeInterval, pixelsPerNM: CGFloat, bounds: CGSize) -> CGPoint {
        guard pixelsPerNM > 0 else { return position }

        let distanceNM = max(0, speedKnots) * elapsed / 3_600
        let radians = heading * .pi / 180
        let distanceInPoints = CGFloat(distanceNM) * pixelsPerNM
        let proposed = CGPoint(
            x: position.x + sin(radians) * distanceInPoints,
            y: position.y - cos(radians) * distanceInPoints
        )

        return CGPoint(
            x: min(max(proposed.x, 0), bounds.width),
            y: min(max(proposed.y, 0), bounds.height)
        )
    }

    static func normalizedHeading(_ heading: Double) -> Double {
        var normalized = heading.truncatingRemainder(dividingBy: 360)
        if normalized < 0 { normalized += 360 }
        return normalized
    }

    // Roundoff at the shared 0/180/360 boundaries must not reverse a turn when
    // the same elapsed duration arrives in differently sized clock updates.
    private static let angularRoundoff = 360 * Double.ulpOfOne * 8

    private static func signedHeadingDifference(from current: Double, to target: Double) -> Double {
        var difference = target - current
        if abs(abs(difference) - 180) <= angularRoundoff { return 180 }
        if difference > 180 { difference -= 360 }
        if difference < -180 { difference += 360 }
        return difference
    }

    /// One constant-control trajectory, evaluable at any simulated offset.
    /// The arc integral uses a midpoint/sinc form to avoid cancellation during
    /// very short turns. No frame subdivision or chart projection is involved.
    struct Trajectory {
        let start: FlightAircraftState
        let selectedHeading: Double
        let conditions: FlightConditions

        func state(at elapsed: TimeInterval) -> FlightAircraftState {
            precondition(elapsed.isFinite && elapsed >= 0)
            let target = normalizedHeading(selectedHeading)
            let difference = signedHeadingDifference(from: start.heading, to: target)
            let turningTime = min(elapsed, abs(difference) / turnRateDegreesPerSecond)
            let signedRate = (difference < 0 ? -1.0 : 1.0) * turnRateDegreesPerSecond * .pi / 180
            let halfAngle = signedRate * turningTime / 2
            let sinc = abs(halfAngle) < 1e-8
                ? 1 - halfAngle * halfAngle / 6
                : sin(halfAngle) / halfAngle
            let midpointHeading = start.heading * .pi / 180 + halfAngle
            let speed = start.speedKnots / 3_600
            let heading = turn(heading: start.heading, toward: target, elapsed: elapsed)
            let finalRadians = heading * .pi / 180
            let straightTime = elapsed - turningTime
            let wind = conditions.windVelocity
            let origin = FlightWorld.nauticalMiles(for: start.normalizedPosition)
            let position = CGPoint(
                x: origin.x + speed * turningTime * sinc * sin(midpointHeading)
                    + speed * straightTime * sin(finalRadians) + wind.x * elapsed,
                y: origin.y - speed * turningTime * sinc * cos(midpointHeading)
                    - speed * straightTime * cos(finalRadians) + wind.y * elapsed
            )
            return FlightAircraftState(normalizedPosition: FlightWorld.normalizedPosition(for: position),
                                       heading: heading, speedKnots: start.speedKnots)
        }
    }
}
