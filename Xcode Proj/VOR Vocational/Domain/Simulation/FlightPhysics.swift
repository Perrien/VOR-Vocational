import CoreGraphics
import Foundation

/// Pure flight-movement math: no SwiftUI. Advances a position by heading and
/// speed over an elapsed time, then clamps it to the map bounds.
enum FlightPhysics {
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

        var difference = target - current
        if difference > 180 { difference -= 360 }
        if difference < -180 { difference += 360 }

        guard abs(difference) > maximumTurn else { return target }
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

    private static func normalizedHeading(_ heading: Double) -> Double {
        var normalized = heading.truncatingRemainder(dividingBy: 360)
        if normalized < 0 { normalized += 360 }
        return normalized
    }
}
