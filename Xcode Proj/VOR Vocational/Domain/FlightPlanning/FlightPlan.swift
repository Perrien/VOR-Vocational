import Foundation

/// Authored, bundle-friendly route input. It contains stable world references
/// and a terminal navigation reference, never calculated route measurements.
nonisolated struct FlightPlan: Codable, Equatable {
    let id: String
    let name: String
    let origin: PlanPoint
    let waypoints: [PlanPoint]
    let destination: PlanPoint
    /// An optional final VOR radial the player can use as a practical arrival
    /// reference. It is not a geometric leg or an automatic arrival rule.
    let terminalReference: RadialReference?

    var orderedPoints: [PlanPoint] {
        [origin] + waypoints + [destination]
    }
}

/// One VOR radial, always measured outbound FROM the named station.
nonisolated struct RadialReference: Codable, Equatable {
    let stationID: String
    let radialDegrees: Double
}

/// One route point authored as a stable airport/VOR reference or two VOR
/// radials. The custom coding keeps the JSON readable and explicit.
nonisolated enum PlanPoint: Codable, Equatable {
    case airport(icao: String)
    case vor(stationID: String)
    case intersection(radials: [RadialReference])

    private enum CodingKeys: String, CodingKey {
        case kind
        case icao
        case stationID
        case radials
    }

    private enum Kind: String, Codable {
        case airport
        case vor
        case intersection
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .airport:
            self = .airport(icao: try container.decode(String.self, forKey: .icao))
        case .vor:
            self = .vor(stationID: try container.decode(String.self, forKey: .stationID))
        case .intersection:
            self = .intersection(radials: try container.decode([RadialReference].self, forKey: .radials))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .airport(let icao):
            try container.encode(Kind.airport, forKey: .kind)
            try container.encode(icao, forKey: .icao)
        case .vor(let stationID):
            try container.encode(Kind.vor, forKey: .kind)
            try container.encode(stationID, forKey: .stationID)
        case .intersection(let radials):
            try container.encode(Kind.intersection, forKey: .kind)
            try container.encode(radials, forKey: .radials)
        }
    }
}

/// A resolved point with a normalized chart coordinate and a label for future
/// plan and chart presentation.
nonisolated struct ResolvedPlanPoint: Equatable {
    enum Kind: Equatable {
        case airport
        case vor
        case intersection
    }

    let source: PlanPoint
    let kind: Kind
    let name: String
    let normalizedPosition: CGPoint
}

/// The intended indication for one VOR-navigation action.
nonisolated struct VORGuidance: Equatable {
    enum Flag: String, Equatable {
        case to = "TO"
        case from = "FROM"
    }

    let stationID: String
    let stationIdent: String
    let frequencyMHz: Double
    let obsDegrees: Int
    let flag: Flag
}

/// One calculated line between consecutive plan points. A terminal airport
/// segment may intentionally have no guidance; its terminal reference is kept
/// separately on `ResolvedFlightPlan`.
nonisolated struct FlightPlanLeg: Equatable {
    let start: ResolvedPlanPoint
    let end: ResolvedPlanPoint
    let distanceNM: Double
    let guidance: VORGuidance?
}

/// Still-air time for a resolved route at a caller-supplied planning speed.
nonisolated struct StillAirEstimate: Equatable {
    let cruiseSpeedKnots: Double
    let durationSeconds: TimeInterval
}

/// Complete calculated output used by V0.3b's plan display and V0.3c's
/// mission wrapper.
nonisolated struct ResolvedFlightPlan: Equatable {
    let plan: FlightPlan
    let points: [ResolvedPlanPoint]
    let legs: [FlightPlanLeg]
    let terminalReference: VORGuidance?
    let totalDistanceNM: Double
    let stillAirEstimate: StillAirEstimate
}
