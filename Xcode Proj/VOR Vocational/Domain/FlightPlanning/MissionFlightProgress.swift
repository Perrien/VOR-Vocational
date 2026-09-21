import CoreGraphics
import Foundation

/// Player-controlled progress through a supplied mission's ordered briefing
/// actions. Advancing an instruction never inspects aircraft position: the
/// player decides when a navigation cue has been satisfied.
nonisolated struct MissionFlightProgress: Equatable {
    let instructionCount: Int
    private(set) var activeInstructionIndex: Int = 0

    init(instructionCount: Int) {
        precondition(instructionCount > 0, "A mission needs at least one instruction.")
        self.instructionCount = instructionCount
    }

    var activeInstructionNumber: Int {
        activeInstructionIndex + 1
    }

    var canAdvance: Bool {
        activeInstructionIndex + 1 < instructionCount
    }

    /// Returns whether there was another instruction to activate.
    @discardableResult
    mutating func advanceInstruction() -> Bool {
        guard canAdvance else { return false }
        activeInstructionIndex += 1
        return true
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
