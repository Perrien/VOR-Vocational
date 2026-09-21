import Foundation

/// Read-only plan information prepared for a player-facing briefing. It keeps
/// calculated route geometry separate from the instructions a player acts on:
/// the terminal position reference is an instruction, while the final
/// intersection-to-airport geometry remains chart-only.
nonisolated struct FlightPlanBriefing: Equatable {
    let planName: String
    let originName: String
    let destinationName: String
    let totalDistanceNM: Double
    let stillAirEstimate: StillAirEstimate
    let steps: [FlightPlanBriefingStep]

    init(resolvedPlan: ResolvedFlightPlan) {
        planName = resolvedPlan.plan.name
        originName = resolvedPlan.points.first?.name ?? "Origin"
        destinationName = resolvedPlan.points.last?.name ?? "Destination"
        totalDistanceNM = resolvedPlan.totalDistanceNM
        stillAirEstimate = resolvedPlan.stillAirEstimate

        var steps = resolvedPlan.legs.compactMap { leg -> FlightPlanBriefingStep? in
            guard let guidance = leg.guidance else { return nil }
            return FlightPlanBriefingStep(
                kind: .leg,
                title: "\(leg.start.name) to \(leg.end.name)",
                distanceNM: leg.distanceNM,
                guidance: guidance
            )
        }

        if let terminalReference = resolvedPlan.terminalReference {
            steps.append(
                FlightPlanBriefingStep(
                    kind: .terminalReference,
                    title: "Final position reference near \(destinationName)",
                    distanceNM: nil,
                    guidance: terminalReference
                )
            )
        }

        self.steps = steps
    }
}

/// One action in a player-facing flight-plan briefing.
nonisolated struct FlightPlanBriefingStep: Equatable {
    nonisolated enum Kind: Equatable {
        case leg
        case terminalReference
    }

    let kind: Kind
    let title: String
    /// A normal route leg's chart distance. A terminal radial is deliberately
    /// a position reference, not a fabricated airport leg, so it has no value.
    let distanceNM: Double?
    let guidance: VORGuidance
}
