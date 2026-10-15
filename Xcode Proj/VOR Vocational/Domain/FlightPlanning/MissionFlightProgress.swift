import CoreGraphics
import Foundation

/// Player-controlled checklist for a supplied mission's ordered briefing
/// actions. Completion never inspects aircraft position: the player decides
/// when a navigation cue has been satisfied and can revisit any instruction.
nonisolated struct MissionFlightProgress: Equatable {
    let instructionCount: Int
    private(set) var completedInstructionIndices: Set<Int> = []

    init(instructionCount: Int) {
        precondition(instructionCount >= 0, "Instruction count must be non-negative.")
        self.instructionCount = instructionCount
    }

    func isInstructionComplete(at index: Int) -> Bool {
        completedInstructionIndices.contains(index)
    }

    mutating func setInstructionComplete(_ isComplete: Bool, at index: Int) {
        precondition((0..<instructionCount).contains(index), "Instruction index must belong to the mission.")
        if isComplete {
            completedInstructionIndices.insert(index)
        } else {
            completedInstructionIndices.remove(index)
        }
    }
}

/// The unscored measurement captured when a player explicitly marks a mission
/// flight complete. It reports raw distance from the destination; it does not
/// decide whether the player arrived successfully.
nonisolated struct MissionFlightCompletion: Equatable {
    let mission: MissionFlightDefinition
    let aircraftState: FlightAircraftState
    let conditions: FlightConditions
    let simulatedElapsedSeconds: TimeInterval
    let distanceFromDestinationNM: Double?

    init(mission: MissionFlightDefinition, aircraftState: FlightAircraftState,
         conditions: FlightConditions, simulatedElapsedSeconds: TimeInterval,
         mapWidthNM: Double = FlightWorld.widthNM, mapHeightNM: Double = FlightWorld.heightNM) {
        precondition(simulatedElapsedSeconds.isFinite && simulatedElapsedSeconds >= 0,
                     "Simulated elapsed time must be finite and non-negative.")
        precondition(mapWidthNM.isFinite && mapWidthNM > 0 &&
                     mapHeightNM.isFinite && mapHeightNM > 0,
                     "Mission map dimensions must be finite and greater than zero.")
        self.mission = mission
        self.aircraftState = aircraftState
        self.conditions = conditions
        self.simulatedElapsedSeconds = simulatedElapsedSeconds
        distanceFromDestinationNM = mission.arrivalReference.map {
            VORNavigation.distanceNM(fromNormalized: aircraftState.normalizedPosition,
                                     toNormalized: $0.normalizedPosition,
                                     mapWidthNM: mapWidthNM, mapHeightNM: mapHeightNM)
        }
    }

    init(
        resolvedPlan: ResolvedFlightPlan,
        aircraftPosition: CGPoint,
        simulatedElapsedSeconds: TimeInterval,
        mapWidthNM: Double,
        mapHeightNM: Double
    ) {
        self.init(mission: MissionFlightDefinition(resolvedPlan: resolvedPlan),
                  aircraftState: FlightAircraftState(normalizedPosition: aircraftPosition),
                  conditions: .calm, simulatedElapsedSeconds: simulatedElapsedSeconds,
                  mapWidthNM: mapWidthNM, mapHeightNM: mapHeightNM)
    }
}
