#if DEBUG
import SwiftUI

/// Debug-only window showing the active live-flight session's simulation
/// truth — real position and receiver/signal data that never appears in
/// normal play. `cdiMax` is its only editable control. Reads the shared
/// `FlightDiagnosticsStore` and calls `VORNavigation.receiverReading`
/// directly rather than duplicating any flight calculation.
struct FlightDiagnosticsView: View {
    @Environment(FlightDiagnosticsStore.self) private var diagnosticsStore

    private let stations: [VORStation] = VORStation.myosia

    var body: some View {
        if let session = diagnosticsStore.activeSession {
            FlightDiagnosticsContent(session: session, stations: stations)
        } else {
            Text("No live flight session is active.")
                .foregroundStyle(.secondary)
                .padding()
                .frame(minWidth: 320, minHeight: 200)
        }
    }
}

private struct FlightDiagnosticsContent: View {
    @Bindable var session: FlightSession
    let stations: [VORStation]

    var body: some View {
        Form {
            Section("Flight") {
                LabeledContent("Heading", value: String(format: "%.0f°", session.heading))
                LabeledContent("Simulated time", value: String(format: "%.2f s", session.elapsedSimulatedSeconds))
            }

            Section("Position") {
                LabeledContent(
                    "Normalized",
                    value: String(format: "%.4f, %.4f",
                                  session.normalizedAircraftPosition.x,
                                  session.normalizedAircraftPosition.y)
                )
            }

            Section("True position and heading") {
                FlightDiagnosticsMap(session: session)
                    .frame(height: 250)
            }

            Section("NAV1") {
                receiverRows(for: session.nav1)
            }

            Section("NAV2") {
                receiverRows(for: session.nav2)
            }

            Section("CDI") {
                CDIMaxField(value: $session.cdiMax)
            }
        }
        .padding()
        .frame(minWidth: 420, minHeight: 700)
    }

    @ViewBuilder
    private func receiverRows(for receiver: NAVReceiver) -> some View {
        let reading = VORNavigation.receiverReading(
            frequencyHundredths: receiver.frequencyHundredths,
            obs: receiver.obs,
            normalizedAircraftPosition: session.normalizedAircraftPosition,
            stations: stations,
            mapWidthNM: FlatMap.widthNM,
            mapHeightNM: FlatMap.heightNM,
            cdiMax: session.cdiMax
        )

        LabeledContent("Frequency", value: receiver.frequencyLabel)
        LabeledContent("Ident", value: reading.station?.ident ?? "No reception")
        LabeledContent("OBS", value: "\(receiver.obs)°")
        LabeledContent("CDI", value: cdiDescription(reading))
    }

    private func cdiDescription(_ reading: ReceiverReading) -> String {
        guard reading.station != nil else { return "NAV flag" }
        let flagLabel: String
        switch reading.cdiReading.flag {
        case .to: flagLabel = "TO"
        case .from: flagLabel = "FROM"
        case .off: flagLabel = "NAV flag"
        }
        return String(format: "%.2f (%@)", reading.cdiReading.deflection, flagLabel)
    }
}

/// A diagnostic-only truth view. It projects the session's actual normalized
/// position through the same chart conversion as `MapView`, but exposes no
/// gesture and is never added to the player-facing mission chart.
private struct FlightDiagnosticsMap: View {
    @Bindable var session: FlightSession

    var body: some View {
        GeometryReader { geometry in
            let imageRect = FlatMap.fittedRect(in: geometry.size)
            ZStack {
                FlatMap(imageRect: imageRect)
                PlaneIcon(heading: session.heading)
                    .position(FlatMap.point(for: session.normalizedAircraftPosition,
                                             in: imageRect))
                    .allowsHitTesting(false)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
#endif
