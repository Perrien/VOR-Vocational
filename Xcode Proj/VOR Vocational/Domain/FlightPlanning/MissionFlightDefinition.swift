import CoreGraphics
import Foundation

/// Presentation geometry needs only a label and source-chart position.
nonisolated struct MissionChartPoint: Equatable {
    let name: String
    let normalizedPosition: CGPoint
}

nonisolated struct MissionInstruction: Equatable {
    let title: String
    var guidance: VORGuidance? = nil
    var detail: String? = nil
    /// Explicit association for displaying timing beside guidance. Checklist
    /// order and geometric leg order are independent for generic missions.
    var timingLegIndex: Int? = nil
    var timingDetail: String? = nil
}

/// The shared runner accepts values from a catalog, an author, or a generator.
/// It does not know how those values were produced.
nonisolated struct MissionFlightDefinition: Equatable {
    let id: String
    let title: String
    let initialState: FlightAircraftState
    let plannedPoints: [MissionChartPoint]
    let arrivalReference: MissionChartPoint?
    let instructions: [MissionInstruction]
    /// Explicit timing input; arbitrary chart points/instructions imply no schedule.
    let timingSchedule: MissionTimingSchedule?

    init(id: String, title: String, initialState: FlightAircraftState,
         plannedPoints: [MissionChartPoint] = [], arrivalReference: MissionChartPoint? = nil,
         instructions: [MissionInstruction] = [], timingSchedule: MissionTimingSchedule? = nil) {
        self.id = id
        self.title = title
        self.initialState = initialState
        self.plannedPoints = plannedPoints
        self.arrivalReference = arrivalReference
        self.instructions = instructions
        self.timingSchedule = timingSchedule
    }

    init(resolvedPlan: ResolvedFlightPlan) {
        guard let origin = resolvedPlan.points.first else {
            preconditionFailure("A resolved route needs an origin.")
        }
        let briefing = FlightPlanBriefing(resolvedPlan: resolvedPlan)
        self.init(
            id: resolvedPlan.plan.id,
            title: resolvedPlan.plan.name,
            initialState: FlightAircraftState(normalizedPosition: origin.normalizedPosition,
                                              speedKnots: resolvedPlan.stillAirEstimate.cruiseSpeedKnots),
            plannedPoints: resolvedPlan.points.map {
                MissionChartPoint(name: $0.name, normalizedPosition: $0.normalizedPosition)
            },
            arrivalReference: resolvedPlan.points.last.map {
                MissionChartPoint(name: $0.name, normalizedPosition: $0.normalizedPosition)
            },
            instructions: briefing.instructions,
            timingSchedule: briefing.timingSchedule
        )
    }
}
