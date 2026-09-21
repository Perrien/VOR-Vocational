import CoreGraphics
import Foundation

/// Converts authored flight-plan references into validated chart geometry and
/// semantic NAV guidance. It has no Bundle or SwiftUI dependency so callers
/// can validate plans before presenting them.
nonisolated enum FlightPlanResolver {
    enum ValidationError: Error, Equatable, LocalizedError {
        case invalidMapDimensions
        case invalidCruiseSpeed
        case unknownAirport(String)
        case unknownStation(String)
        case invalidIntersectionRadialCount(Int)
        case duplicateIntersectionStations(String)
        case invalidRadialDegrees(Double)
        case parallelRadials
        case nonIntersectingRadials
        case intersectionOutsideChart
        case intersectionOutsideStationRange(String)
        case duplicateConsecutivePoints
        case unsupportedLeg
        case invalidTerminalReference

        var errorDescription: String? {
            switch self {
            case .invalidMapDimensions:
                return "Flight-plan map dimensions must be finite and greater than zero."
            case .invalidCruiseSpeed:
                return "Flight-plan cruise speed must be finite and greater than zero."
            case .unknownAirport(let icao):
                return "Flight plan references unknown airport \(icao)."
            case .unknownStation(let stationID):
                return "Flight plan references unknown VOR \(stationID)."
            case .invalidIntersectionRadialCount(let count):
                return "A radial intersection needs exactly two radials, not \(count)."
            case .duplicateIntersectionStations(let stationID):
                return "A radial intersection cannot use \(stationID) twice."
            case .invalidRadialDegrees(let degrees):
                return "VOR radial \(degrees) must be finite and in 0..<360 degrees."
            case .parallelRadials:
                return "The two VOR radials are parallel or coincident."
            case .nonIntersectingRadials:
                return "The two VOR radial rays do not meet ahead of both stations."
            case .intersectionOutsideChart:
                return "The VOR radial intersection is outside the Myosia chart."
            case .intersectionOutsideStationRange(let stationID):
                return "The intersection is outside \(stationID)'s service range."
            case .duplicateConsecutivePoints:
                return "Consecutive flight-plan points cannot occupy the same position."
            case .unsupportedLeg:
                return "This pair of flight-plan points has no VOR guidance rule yet."
            case .invalidTerminalReference:
                return "The terminal reference must be one radial of the final intersection."
            }
        }
    }

    static func resolve(
        _ plan: FlightPlan,
        airports: [Airport],
        stations: [VORStation],
        mapWidthNM: Double,
        mapHeightNM: Double,
        cruiseSpeedKnots: Double
    ) throws -> ResolvedFlightPlan {
        guard mapWidthNM.isFinite, mapWidthNM > 0,
              mapHeightNM.isFinite, mapHeightNM > 0 else {
            throw ValidationError.invalidMapDimensions
        }
        guard cruiseSpeedKnots.isFinite, cruiseSpeedKnots > 0 else {
            throw ValidationError.invalidCruiseSpeed
        }

        let points = try plan.orderedPoints.map {
            try resolve(point: $0,
                        airports: airports,
                        stations: stations,
                        mapWidthNM: mapWidthNM,
                        mapHeightNM: mapHeightNM)
        }
        let legs = try zip(points, points.dropFirst()).map { start, end in
            try makeLeg(from: start,
                        to: end,
                        stations: stations,
                        mapWidthNM: mapWidthNM,
                        mapHeightNM: mapHeightNM)
        }
        let totalDistanceNM = legs.reduce(0) { $0 + $1.distanceNM }
        guard totalDistanceNM.isFinite else {
            throw ValidationError.unsupportedLeg
        }

        return ResolvedFlightPlan(
            plan: plan,
            points: points,
            legs: legs,
            terminalReference: try resolveTerminalReference(
                plan.terminalReference,
                finalWaypoint: plan.waypoints.last,
                stations: stations
            ),
            totalDistanceNM: totalDistanceNM,
            stillAirEstimate: StillAirEstimate(
                cruiseSpeedKnots: cruiseSpeedKnots,
                durationSeconds: totalDistanceNM / cruiseSpeedKnots * 3_600
            )
        )
    }

    private static func resolve(
        point: PlanPoint,
        airports: [Airport],
        stations: [VORStation],
        mapWidthNM: Double,
        mapHeightNM: Double
    ) throws -> ResolvedPlanPoint {
        switch point {
        case .airport(let icao):
            let normalizedICAO = icao.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard let airport = airports.first(where: { $0.icao == normalizedICAO }) else {
                throw ValidationError.unknownAirport(icao)
            }
            return ResolvedPlanPoint(
                source: point,
                kind: .airport,
                name: airport.name,
                normalizedPosition: CGPoint(x: airport.x, y: airport.y)
            )

        case .vor(let stationID):
            let station = try station(for: stationID, in: stations)
            return ResolvedPlanPoint(
                source: point,
                kind: .vor,
                name: station.name,
                normalizedPosition: station.relativePosition
            )

        case .intersection(let radials):
            let intersection = try intersection(
                radials: radials,
                stations: stations,
                mapWidthNM: mapWidthNM,
                mapHeightNM: mapHeightNM
            )
            return ResolvedPlanPoint(
                source: point,
                kind: .intersection,
                name: "VOR radial intersection",
                normalizedPosition: intersection
            )
        }
    }

    private static func makeLeg(
        from start: ResolvedPlanPoint,
        to end: ResolvedPlanPoint,
        stations: [VORStation],
        mapWidthNM: Double,
        mapHeightNM: Double
    ) throws -> FlightPlanLeg {
        let distanceNM = VORNavigation.distanceNM(
            fromNormalized: start.normalizedPosition,
            toNormalized: end.normalizedPosition,
            mapWidthNM: mapWidthNM,
            mapHeightNM: mapHeightNM
        )
        guard distanceNM.isFinite, distanceNM > 0.000_001 else {
            throw ValidationError.duplicateConsecutivePoints
        }

        let guidance = try guidance(
            from: start,
            to: end,
            stations: stations,
            mapWidthNM: mapWidthNM,
            mapHeightNM: mapHeightNM
        )
        return FlightPlanLeg(start: start, end: end, distanceNM: distanceNM, guidance: guidance)
    }

    private static func guidance(
        from start: ResolvedPlanPoint,
        to end: ResolvedPlanPoint,
        stations: [VORStation],
        mapWidthNM: Double,
        mapHeightNM: Double
    ) throws -> VORGuidance? {
        switch (start.source, end.source) {
        case (.airport, .vor(let stationID)):
            let station = try station(for: stationID, in: stations)
            return guidance(for: station,
                            obsDegrees: roundedBearing(
                                from: start.normalizedPosition,
                                to: end.normalizedPosition,
                                mapWidthNM: mapWidthNM,
                                mapHeightNM: mapHeightNM
                            ),
                            flag: .to)

        case (.vor(let stationID), .intersection(let radials)):
            let radial = try radial(for: stationID, in: radials)
            let station = try station(for: stationID, in: stations)
            return guidance(for: station,
                            obsDegrees: roundedDegrees(radial.radialDegrees),
                            flag: .from)

        case (.intersection(let radials), .vor(let stationID)):
            let radial = try radial(for: stationID, in: radials)
            let station = try station(for: stationID, in: stations)
            return guidance(for: station,
                            obsDegrees: reciprocal(of: roundedDegrees(radial.radialDegrees)),
                            flag: .to)

        case (.intersection, .airport):
            // The Silverkeep plan's final segment is intentionally only a
            // chart geometry connection. Its separate terminal reference is
            // what the player uses before choosing Flight Complete.
            return nil

        default:
            throw ValidationError.unsupportedLeg
        }
    }

    private static func resolveTerminalReference(
        _ reference: RadialReference?,
        finalWaypoint: PlanPoint?,
        stations: [VORStation]
    ) throws -> VORGuidance? {
        guard let reference else { return nil }
        guard case .intersection(let radials)? = finalWaypoint,
              radials.contains(reference) else {
            throw ValidationError.invalidTerminalReference
        }
        let station = try station(for: reference.stationID, in: stations)
        return guidance(for: station,
                        obsDegrees: roundedDegrees(reference.radialDegrees),
                        flag: .from)
    }

    private static func intersection(
        radials: [RadialReference],
        stations: [VORStation],
        mapWidthNM: Double,
        mapHeightNM: Double
    ) throws -> CGPoint {
        guard radials.count == 2 else {
            throw ValidationError.invalidIntersectionRadialCount(radials.count)
        }
        let first = radials[0]
        let second = radials[1]
        guard first.stationID != second.stationID else {
            throw ValidationError.duplicateIntersectionStations(first.stationID)
        }
        try validate(radialDegrees: first.radialDegrees)
        try validate(radialDegrees: second.radialDegrees)

        let firstStation = try station(for: first.stationID, in: stations)
        let secondStation = try station(for: second.stationID, in: stations)
        let firstOrigin = mapPoint(firstStation.relativePosition,
                                   mapWidthNM: mapWidthNM,
                                   mapHeightNM: mapHeightNM)
        let secondOrigin = mapPoint(secondStation.relativePosition,
                                    mapWidthNM: mapWidthNM,
                                    mapHeightNM: mapHeightNM)
        let firstDirection = direction(for: first.radialDegrees)
        let secondDirection = direction(for: second.radialDegrees)
        let delta = CGPoint(x: secondOrigin.x - firstOrigin.x, y: secondOrigin.y - firstOrigin.y)
        let determinant = cross(firstDirection, secondDirection)
        guard abs(determinant) > 0.000_000_001 else {
            throw ValidationError.parallelRadials
        }

        let firstDistance = cross(delta, secondDirection) / determinant
        let secondDistance = cross(delta, firstDirection) / determinant
        guard firstDistance >= -0.000_001, secondDistance >= -0.000_001 else {
            throw ValidationError.nonIntersectingRadials
        }

        let mapIntersection = CGPoint(
            x: firstOrigin.x + max(0, firstDistance) * firstDirection.x,
            y: firstOrigin.y + max(0, firstDistance) * firstDirection.y
        )
        let normalizedIntersection = CGPoint(
            x: mapIntersection.x / mapWidthNM,
            y: mapIntersection.y / mapHeightNM
        )
        guard (0...1).contains(normalizedIntersection.x),
              (0...1).contains(normalizedIntersection.y) else {
            throw ValidationError.intersectionOutsideChart
        }

        for station in [firstStation, secondStation] {
            let distanceNM = VORNavigation.distanceNM(
                fromNormalized: normalizedIntersection,
                toNormalized: station.relativePosition,
                mapWidthNM: mapWidthNM,
                mapHeightNM: mapHeightNM
            )
            guard distanceNM <= station.rangeNM else {
                throw ValidationError.intersectionOutsideStationRange(station.id)
            }
        }
        return normalizedIntersection
    }

    private static func station(for stationID: String, in stations: [VORStation]) throws -> VORStation {
        guard let station = stations.first(where: { $0.id == stationID }) else {
            throw ValidationError.unknownStation(stationID)
        }
        return station
    }

    private static func radial(for stationID: String, in radials: [RadialReference]) throws -> RadialReference {
        guard let radial = radials.first(where: { $0.stationID == stationID }) else {
            throw ValidationError.unsupportedLeg
        }
        try validate(radialDegrees: radial.radialDegrees)
        return radial
    }

    private static func validate(radialDegrees: Double) throws {
        guard radialDegrees.isFinite, (0..<360).contains(radialDegrees) else {
            throw ValidationError.invalidRadialDegrees(radialDegrees)
        }
    }

    private static func guidance(for station: VORStation, obsDegrees: Int, flag: VORGuidance.Flag) -> VORGuidance {
        VORGuidance(
            stationID: station.id,
            stationIdent: station.ident,
            frequencyMHz: station.frequency,
            obsDegrees: obsDegrees,
            flag: flag
        )
    }

    private static func mapPoint(_ normalized: CGPoint, mapWidthNM: Double, mapHeightNM: Double) -> CGPoint {
        CGPoint(x: normalized.x * mapWidthNM, y: normalized.y * mapHeightNM)
    }

    private static func direction(for degrees: Double) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(x: sin(radians), y: -cos(radians))
    }

    private static func cross(_ lhs: CGPoint, _ rhs: CGPoint) -> Double {
        lhs.x * rhs.y - lhs.y * rhs.x
    }

    private static func roundedBearing(
        from start: CGPoint,
        to end: CGPoint,
        mapWidthNM: Double,
        mapHeightNM: Double
    ) -> Int {
        let eastNM = (end.x - start.x) * mapWidthNM
        let northNM = -(end.y - start.y) * mapHeightNM
        let degrees = atan2(eastNM, northNM) * 180 / .pi
        return roundedDegrees(degrees)
    }

    private static func roundedDegrees(_ degrees: Double) -> Int {
        let rounded = Int(degrees.rounded()) % 360
        return rounded >= 0 ? rounded : rounded + 360
    }

    private static func reciprocal(of degrees: Int) -> Int {
        (degrees + 180) % 360
    }
}
