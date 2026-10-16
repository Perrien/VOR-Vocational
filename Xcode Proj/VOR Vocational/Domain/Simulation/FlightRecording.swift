import Foundation

/// One exact evaluation of the flight model, not an interpolated display point.
nonisolated struct FlightSample: Equatable {
    let simulatedSeconds: TimeInterval
    let aircraftState: FlightAircraftState
}

/// A mission-local recording on an integer simulated-second schedule.
nonisolated struct FlightRecording: Equatable {
    private(set) var samples: [FlightSample]
    private var nextWholeSecond = 1

    init(initialState: FlightAircraftState) {
        samples = [FlightSample(simulatedSeconds: 0, aircraftState: initialState)]
    }

    mutating func record(_ trajectory: FlightPhysics.Trajectory,
                         startingAt start: TimeInterval, through end: TimeInterval) {
        while Double(nextWholeSecond) <= end {
            let time = Double(nextWholeSecond)
            samples.append(FlightSample(simulatedSeconds: time,
                                        aircraftState: trajectory.state(at: max(0, time - start))))
            nextWholeSecond += 1
        }
    }

    mutating func finish(at time: TimeInterval, state: FlightAircraftState) {
        let final = FlightSample(simulatedSeconds: time, aircraftState: state)
        if samples.last?.simulatedSeconds == time { samples[samples.count - 1] = final }
        else {
            precondition(time > samples.last!.simulatedSeconds, "Recording time must increase.")
            samples.append(final)
        }
    }
}

nonisolated enum MissionFlightEnding: String, Equatable {
    case playerCompleted
    case leftChart

    var label: String {
        switch self {
        case .playerCompleted: return "Flight Complete"
        case .leftChart: return "Left the chart"
        }
    }
}
