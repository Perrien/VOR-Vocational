import Foundation

/// Read-only plan information prepared for a player-facing briefing. It keeps
/// calculated route geometry separate from the instructions a player acts on:
/// the terminal position reference is an instruction, while the final
/// intersection-to-airport geometry belongs to the chart and timing schedule.
nonisolated struct FlightPlanBriefing: Equatable {
    let planName: String
    let originName: String
    let destinationName: String
    let totalDistanceNM: Double
    let stillAirEstimate: StillAirEstimate
    let timingSchedule: MissionTimingSchedule
    let steps: [FlightPlanBriefingStep]

    var instructions: [MissionInstruction] {
        steps.map { step in
            MissionInstruction(title: step.title, guidance: step.guidance,
                detail: step.kind == .terminalReference
                    ? "Use this practical radial reference to locate \(destinationName); it is not a literal airport course." : nil,
                timingLegIndex: step.timingLegIndex,
                timingDetail: step.kind == .terminalReference
                    ? timingSchedule.legs?.last.map { "Timing: \($0.startLabel) → \($0.endLabel)." } : nil)
        }
    }

    init(resolvedPlan: ResolvedFlightPlan) {
        planName = resolvedPlan.plan.name
        originName = resolvedPlan.points.first?.name ?? "Origin"
        destinationName = resolvedPlan.points.last?.name ?? "Destination"
        totalDistanceNM = resolvedPlan.totalDistanceNM
        stillAirEstimate = resolvedPlan.stillAirEstimate
        timingSchedule = MissionTimingSchedule(resolvedPlan: resolvedPlan)

        var steps = resolvedPlan.legs.enumerated().compactMap { index, leg -> FlightPlanBriefingStep? in
            guard let guidance = leg.guidance else { return nil }
            return FlightPlanBriefingStep(
                kind: .leg,
                title: "\(leg.start.name) to \(leg.end.name)",
                distanceNM: leg.distanceNM,
                guidance: guidance,
                timingLegIndex: index
            )
        }

        if let terminalReference = resolvedPlan.terminalReference {
            steps.append(
                FlightPlanBriefingStep(
                    kind: .terminalReference,
                    title: "Final position reference near \(destinationName)",
                    distanceNM: nil,
                    guidance: terminalReference,
                    timingLegIndex: resolvedPlan.legs.indices.last
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
    let timingLegIndex: Int?
}
