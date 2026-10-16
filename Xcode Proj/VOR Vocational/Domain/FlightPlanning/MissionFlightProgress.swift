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

/// An immutable completed flight. The final recorded sample is authoritative
/// for the ending state, clock, and unscored arrival measurement.
nonisolated struct MissionFlightCompletion: Equatable {
    let mission: MissionFlightDefinition
    let recording: [FlightSample]
    let ending: MissionFlightEnding
    let conditions: FlightConditions
    let distanceFromDestinationNM: Double?

    var aircraftState: FlightAircraftState { recording.last!.aircraftState }
    var simulatedElapsedSeconds: TimeInterval { recording.last!.simulatedSeconds }

    init(mission: MissionFlightDefinition, recording: [FlightSample],
         conditions: FlightConditions, ending: MissionFlightEnding,
         mapWidthNM: Double = FlightWorld.widthNM, mapHeightNM: Double = FlightWorld.heightNM) {
        precondition(recording.first?.simulatedSeconds == 0 && !recording.isEmpty,
                     "A completed flight must retain its exact starting sample.")
        precondition(recording.allSatisfy { $0.simulatedSeconds.isFinite },
                     "Recording timestamps must be finite.")
        precondition(zip(recording, recording.dropFirst()).allSatisfy {
            $0.simulatedSeconds < $1.simulatedSeconds
        }, "Recording timestamps must increase strictly.")
        precondition(mapWidthNM.isFinite && mapWidthNM > 0 &&
                     mapHeightNM.isFinite && mapHeightNM > 0,
                     "Mission map dimensions must be finite and greater than zero.")
        self.mission = mission
        self.recording = recording
        self.conditions = conditions
        self.ending = ending
        distanceFromDestinationNM = mission.arrivalReference.map {
            VORNavigation.distanceNM(fromNormalized: recording.last!.aircraftState.normalizedPosition,
                                     toNormalized: $0.normalizedPosition,
                                     mapWidthNM: mapWidthNM, mapHeightNM: mapHeightNM)
        }
    }
}
