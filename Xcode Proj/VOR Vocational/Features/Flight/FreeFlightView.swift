import SwiftUI

/// Direct-launch wrapper that owns exactly one fresh Free Flight session.
struct FreeFlightView: View {
    @State private var session: FlightSession
    @Environment(FlightDiagnosticsStore.self) private var diagnosticsStore

    init() {
        let airports = Airport.myosia.filter { $0.icao == "GPMC" }
        guard let airport = airports.only else {
            preconditionFailure("Midland Cityport (GPMC) is missing from Airports.json")
        }
        _session = State(initialValue: FlightSession(
            normalizedAirportPosition: CGPoint(x: airport.x, y: airport.y)
        ))
    }

    var body: some View {
        MapView(session: session)
            .onAppear {
                diagnosticsStore.activeSession = session
            }
            .onDisappear {
                if diagnosticsStore.activeSession === session {
                    diagnosticsStore.activeSession = nil
                }
            }
    }
}

private extension Collection {
    var only: Element? {
        count == 1 ? first : nil
    }
}
