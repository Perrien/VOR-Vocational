import SwiftUI

/// Direct-launch wrapper that owns exactly one fresh Free Flight session and
/// shows a persistent Home control (U2).
struct FreeFlightView: View {
    @State private var session: FlightSession
    @Environment(FlightDiagnosticsStore.self) private var diagnosticsStore

    var onHome: () -> Void

    init(onHome: @escaping () -> Void) {
        self.onHome = onHome
        let airports = Airport.myosia.filter { $0.icao == "GPMC" }
        guard let airport = airports.only else {
            preconditionFailure("Midland Cityport (GPMC) is missing from Airports.json")
        }
        _session = State(initialValue: FlightSession(
            normalizedAirportPosition: CGPoint(x: airport.x, y: airport.y)
        ))
    }

    var body: some View {
        MapView(session: session, configuration: .freeFlight)
            .overlay(alignment: .topLeading) {
                // Extra top clearance keeps the control clear of the window's
                // title bar, matching ChartButton's top-trailing treatment.
                HomeControl(action: onHome)
                    .padding(.top, 40)
                    .padding(.leading, 16)
            }
            // MapView's own content ignores the safe area so ChartButton can
            // sit this close to the title bar; this overlay needs the same
            // to land at the same height instead of the safe-area-inset one.
            .ignoresSafeArea()
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
