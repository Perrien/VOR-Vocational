import SwiftUI

/// Read-only preflight reference for the supplied Silverkeep-to-Midland plan.
/// It intentionally renders a static chart rather than a live flight surface.
struct TransportBriefingView: View {
    var onMissions: () -> Void
    var onHome: () -> Void

    @State private var isShowingTransportFlight = false
    private let content: TransportBriefingContent?
    private let loadError: String?

    init(onMissions: @escaping () -> Void, onHome: @escaping () -> Void) {
        self.onMissions = onMissions
        self.onHome = onHome

        do {
            content = try TransportBriefingContent.load()
            loadError = nil
        } catch {
            content = nil
            loadError = error.localizedDescription
        }
    }

    var body: some View {
        if isShowingTransportFlight, let content {
            TransportMissionView(
                resolvedPlan: content.resolvedPlan,
                briefing: content.briefing,
                onBriefing: { isShowingTransportFlight = false },
                onMissions: onMissions,
                onHome: onHome
            )
        } else {
            Group {
                if let content {
                    briefing(content)
                } else {
                    unavailableBriefing
                }
            }
            .overlay(alignment: .topLeading) {
                HomeControl(action: onHome)
                    .padding(.top, 40)
                    .padding(.leading, 16)
            }
            .ignoresSafeArea()
        }
    }

    private func briefing(_ content: TransportBriefingContent) -> some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                routeChart(points: content.resolvedPlan.points)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                FlightPlanPanel(briefing: content.briefing,
                                onMissions: onMissions,
                                onStart: { isShowingTransportFlight = true })
                    .frame(width: min(max(340, geometry.size.width * 0.34), 430))
            }
            .background(FlatMap.oceanColor)
        }
    }

    private func routeChart(points: [ResolvedPlanPoint]) -> some View {
        GeometryReader { geometry in
            let imageRect = FlatMap.fittedRect(in: geometry.size)
            ZStack {
                FlatMap(imageRect: imageRect)
                FlightPlanRouteOverlay(points: points, imageRect: imageRect)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }

    private var unavailableBriefing: some View {
        ZStack {
            Image("MyosiaMap")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .blur(radius: 20)
                .overlay(Color.black.opacity(0.28))

            VStack(alignment: .leading, spacing: 16) {
                Text("Transport briefing unavailable")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(ControlPalette.primaryText)
                Text(loadError ?? "The supplied flight plan could not be loaded.")
                    .foregroundStyle(ControlPalette.secondaryText)
                Button("Back to Missions", action: onMissions)
                    .buttonStyle(.borderedProminent)
                    .tint(ControlPalette.accent)
            }
            .padding(28)
            .frame(maxWidth: 460, alignment: .leading)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.94),
                        in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

private struct TransportBriefingContent {
    let resolvedPlan: ResolvedFlightPlan
    let briefing: FlightPlanBriefing

    static func load() throws -> TransportBriefingContent {
        let plan = try FlightPlanCatalog.load(named: "SilverkeepToMidland")
        let resolvedPlan = try FlightPlanResolver.resolve(
            plan,
            airports: Airport.myosia,
            stations: VORStation.myosia,
            mapWidthNM: FlatMap.widthNM,
            mapHeightNM: FlatMap.heightNM,
            cruiseSpeedKnots: 260
        )
        return TransportBriefingContent(
            resolvedPlan: resolvedPlan,
            briefing: FlightPlanBriefing(resolvedPlan: resolvedPlan)
        )
    }
}

private struct FlightPlanPanel: View {
    let briefing: FlightPlanBriefing
    let onMissions: () -> Void
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button("Back to Missions", action: onMissions)
                    .buttonStyle(.bordered)
                Spacer()
            }
            .padding(.bottom, 16)

            Text("Flight Plan")
                .font(.title2.weight(.bold))
                .foregroundStyle(ControlPalette.primaryText)
            Text(briefing.planName)
                .font(.headline)
                .foregroundStyle(ControlPalette.secondaryText)
                .padding(.bottom, 18)

            summary

            Divider().padding(.vertical, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(briefing.steps.enumerated()), id: \.offset) { index, step in
                        FlightPlanStepRow(number: index + 1, step: step)
                    }
                }
            }

            Button(action: onStart) {
                Label("Fly Transport", systemImage: "airplane.departure")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(ControlPalette.accent)
            .padding(.top, 14)
        }
        .padding(24)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.97))
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(briefing.originName) → \(briefing.destinationName)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ControlPalette.primaryText)
            Text(String(format: "%.1f NM planned distance", briefing.totalDistanceNM))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(ControlPalette.secondaryText)
            Text(stillAirEstimateLabel)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(ControlPalette.secondaryText)
        }
    }

    private var stillAirEstimateLabel: String {
        let minutes = Int((briefing.stillAirEstimate.durationSeconds / 60).rounded())
        return "Still air: \(minutes) min at \(Int(briefing.stillAirEstimate.cruiseSpeedKnots)) kt"
    }
}

private struct FlightPlanStepRow: View {
    let number: Int
    let step: FlightPlanBriefingStep

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(step.kind == .terminalReference ? Color.orange : ControlPalette.accent,
                            in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(step.kind == .terminalReference ? "Final position reference" : step.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ControlPalette.primaryText)

                if let distanceNM = step.distanceNM {
                    Text(String(format: "%.1f NM", distanceNM))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(ControlPalette.secondaryText)
                }

                Text("Tune \(step.guidance.stationIdent) \(String(format: "%.2f", step.guidance.frequencyMHz))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(ControlPalette.secondaryText)
                Text("Set OBS \(String(format: "%03d", step.guidance.obsDegrees))° · Confirm \(step.guidance.flag.rawValue)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(ControlPalette.primaryText)

                if step.kind == .terminalReference {
                    Text("Use this practical radial reference to locate Midland; it is not a literal airport course.")
                        .font(.caption)
                        .foregroundStyle(ControlPalette.secondaryText)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    TransportBriefingView(onMissions: {}, onHome: {})
        .frame(width: 1100, height: 760)
}
