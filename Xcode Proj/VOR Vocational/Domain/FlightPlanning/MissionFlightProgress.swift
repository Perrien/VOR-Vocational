import CoreGraphics
import Foundation

/// Player-controlled checklist for a supplied mission's ordered briefing
/// actions. Completion never inspects aircraft position: the player decides
/// when a navigation cue has been satisfied and can revisit any instruction.
nonisolated struct MissionFlightProgress: Equatable {
    let instructionCount: Int
    private(set) var completedInstructionIndices: Set<Int> = []

    init(instructionCount: Int) {
        precondition(instructionCount > 0, "A mission needs at least one instruction.")
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
    let simulatedElapsedSeconds: TimeInterval
    let distanceFromDestinationNM: Double

    init(
        resolvedPlan: ResolvedFlightPlan,
        aircraftPosition: CGPoint,
        simulatedElapsedSeconds: TimeInterval,
        mapWidthNM: Double,
        mapHeightNM: Double
    ) {
        precondition(simulatedElapsedSeconds.isFinite && simulatedElapsedSeconds >= 0,
                     "Simulated elapsed time must be finite and non-negative.")
        precondition(mapWidthNM.isFinite && mapWidthNM > 0 &&
                     mapHeightNM.isFinite && mapHeightNM > 0,
                     "Mission map dimensions must be finite and greater than zero.")
        guard let destination = resolvedPlan.points.last else {
            preconditionFailure("A resolved mission plan needs a destination.")
        }

        self.simulatedElapsedSeconds = simulatedElapsedSeconds
        distanceFromDestinationNM = VORNavigation.distanceNM(
            fromNormalized: aircraftPosition,
            toNormalized: destination.normalizedPosition,
            mapWidthNM: mapWidthNM,
            mapHeightNM: mapHeightNM
        )
    }
}
