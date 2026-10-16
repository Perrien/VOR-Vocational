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

        private var turnDifference: Double {
            signedHeadingDifference(from: start.heading, to: normalizedHeading(selectedHeading))
        }
        private var turnDuration: Double { abs(turnDifference) / turnRateDegreesPerSecond }
        private var angularVelocity: Double {
            (turnDifference < 0 ? -1 : 1) * turnRateDegreesPerSecond * .pi / 180
        }

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

        struct ChartExit {
            let elapsed: TimeInterval
            let state: FlightAircraftState
        }

        enum BoundaryError: Error, LocalizedError {
            case invalidStart
            case didNotConverge

            var errorDescription: String? {
                switch self {
                case .invalidStart: return "The mission aircraft must start inside the full chart."
                case .didNotConverge: return "The chart crossing could not be resolved. The flight is paused."
                }
            }
        }

        /// Finds every monotone interval analytically, then solves only outward
        /// roots. An arc can leave and reenter even when its final point is inside.
        func firstChartExit(through elapsed: TimeInterval,
                            startingAt simulatedStart: TimeInterval = 0) throws -> ChartExit? {
            let roundoff = FlightWorld.widthNM * Double.ulpOfOne * 32
            let origin = FlightWorld.nauticalMiles(for: start.normalizedPosition)
            guard origin.x >= -roundoff, origin.x <= FlightWorld.widthNM + roundoff,
                  origin.y >= -roundoff, origin.y <= FlightWorld.heightNM + roundoff else {
                throw BoundaryError.invalidStart
            }
            guard elapsed > 0 else { return nil }
            let cuts = monotoneTimes(through: elapsed)
            var candidates: [(time: Double, edge: ChartEdge)] = []
            for edge in ChartEdge.allCases {
                func distance(_ time: Double) -> Double { edge.outsideDistance(state(at: time).normalizedPosition) }
                for (a, b) in zip(cuts, cuts.dropFirst()) {
                    let da = distance(a), db = distance(b)
                    guard db > da else { continue }
                    if abs(da) <= roundoff && continuesOutward(edge, at: a) {
                        candidates.append((a, edge))
                        break
                    }
                    if da < 0 && db > roundoff {
                        var low = a, high = b
                        var converged = false
                        for _ in 0..<128 {
                            if high - low <= 1e-8 && abs(distance(high) - distance(low)) <= 1e-9 {
                                converged = true
                                break
                            }
                            let middle = low + (high - low) / 2
                            if distance(middle) > 0 { high = middle }
                            else { low = middle }
                        }
                        guard converged else { throw BoundaryError.didNotConverge }
                        var time = low + (high - low) / 2
                        // A regular sample and crossing of the same numerical
                        // event share one timestamp and one authoritative state.
                        let regular = (simulatedStart + time).rounded() - simulatedStart
                        if regular >= low && regular <= high,
                           abs(distance(regular)) <= 1e-9, continuesOutward(edge, at: regular) {
                            time = regular
                        }
                        candidates.append((time, edge))
                        break
                    }
                    if da < 0 && abs(db) <= roundoff && continuesOutward(edge, at: b) {
                        candidates.append((b, edge))
                        break
                    }
                }
            }
            guard let first = candidates.min(by: { $0.time < $1.time }) else { return nil }
            let evaluated = state(at: first.time)
            var position = evaluated.normalizedPosition
            first.edge.pin(&position)
            // A coincident corner crossing is a single ending, with both crossed
            // coordinates pinned; an unrelated coordinate is never clamped.
            for candidate in candidates where candidate.edge != first.edge {
                if abs(candidate.time - first.time) <= 1e-8 &&
                    abs(candidate.edge.outsideDistance(evaluated.normalizedPosition)) <= 1e-9 {
                    candidate.edge.pin(&position)
                }
            }
            return ChartExit(elapsed: first.time,
                             state: FlightAircraftState(normalizedPosition: position,
                                                        heading: evaluated.heading, speedKnots: evaluated.speedKnots))
        }

        private func monotoneTimes(through elapsed: Double) -> [Double] {
            let turningEnd = min(turnDuration, elapsed)
            var times = [0.0, elapsed]
            if turningEnd > 0 { times.append(turningEnd) }
            let speed = start.speedKnots / 3_600
            if speed > 0 && turningEnd > 0 {
                let theta = start.heading * .pi / 180
                let wind = conditions.windVelocity
                var angles: [Double] = []
                let xRatio = -Double(wind.x) / speed
                if abs(xRatio) <= 1 {
                    let root = asin(xRatio)
                    angles += [root, .pi - root]
                }
                let yRatio = Double(wind.y) / speed
                if abs(yRatio) <= 1 {
                    let root = acos(yRatio)
                    angles += [root, -root]
                }
                // A shortest turn sweeps at most π, starting in 0..<2π.
                for angle in angles {
                    for revolution in -2...2 {
                        let time = (angle + Double(revolution) * 2 * .pi - theta) / angularVelocity
                        if time > 0 && time < turningEnd { times.append(time) }
                    }
                }
            }
            return Array(Set(times)).sorted()
        }

        /// Classify the right-hand continuation. At a tangency, acceleration
        /// (or jerk at a wind-cancelled extremum) distinguishes exit from touch.
        private func continuesOutward(_ edge: ChartEdge, at time: Double) -> Bool {
            let speed = start.speedKnots / 3_600
            let theta = turn(heading: start.heading, toward: selectedHeading, elapsed: time) * .pi / 180
            let wind = conditions.windVelocity
            let velocity = CGPoint(x: speed * sin(theta) + wind.x, y: -speed * cos(theta) + wind.y)
            let epsilon = max(speed, hypot(wind.x, wind.y)) * Double.ulpOfOne * 64
            let outward = edge.component(velocity)
            if abs(outward) > epsilon { return outward > 0 }
            guard time < turnDuration else { return false }
            let omega = angularVelocity
            let acceleration = CGPoint(x: speed * omega * cos(theta), y: speed * omega * sin(theta))
            let outwardAcceleration = edge.component(acceleration)
            if abs(outwardAcceleration) > epsilon * abs(omega) { return outwardAcceleration > 0 }
            let jerk = CGPoint(x: -speed * omega * omega * sin(theta), y: speed * omega * omega * cos(theta))
            return edge.component(jerk) > epsilon * omega * omega
        }

        private enum ChartEdge: CaseIterable {
            case west, east, north, south

            func component(_ vector: CGPoint) -> Double {
                switch self {
                case .west: return -vector.x
                case .east: return vector.x
                case .north: return -vector.y
                case .south: return vector.y
                }
            }

            func outsideDistance(_ position: CGPoint) -> Double {
                switch self {
                case .west: return -position.x * FlightWorld.widthNM
                case .east: return (position.x - 1) * FlightWorld.widthNM
                case .north: return -position.y * FlightWorld.heightNM
                case .south: return (position.y - 1) * FlightWorld.heightNM
                }
            }

            func pin(_ position: inout CGPoint) {
                switch self {
                case .west: position.x = 0
                case .east: position.x = 1
                case .north: position.y = 0
                case .south: position.y = 1
                }
            }
        }
    }
}
