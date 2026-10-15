import SwiftUI

/// Live, instrument-led flight for the supplied Silverkeep-to-Midland plan.
/// The mission surface deliberately hides the aircraft marker and planned
/// route; the player uses the chart and NAV instruments to navigate.
struct TransportMissionView: View {
    let resolvedPlan: ResolvedFlightPlan
    let briefing: FlightPlanBriefing
    var onBriefing: () -> Void
    var onMissions: () -> Void
    var onHome: () -> Void

    @State private var session: FlightSession
    @State private var progress: MissionFlightProgress
    @State private var completion: MissionFlightCompletion?
    @State private var showsMissionPanel = true
    @Environment(FlightDiagnosticsStore.self) private var diagnosticsStore

    init(
        resolvedPlan: ResolvedFlightPlan,
        briefing: FlightPlanBriefing,
        onBriefing: @escaping () -> Void,
        onMissions: @escaping () -> Void,
        onHome: @escaping () -> Void
    ) {
        guard let origin = resolvedPlan.points.first else {
            preconditionFailure("Transport mission needs a resolved origin.")
        }
        precondition(!briefing.steps.isEmpty, "Transport mission needs briefing instructions.")

        self.resolvedPlan = resolvedPlan
        self.briefing = briefing
        self.onBriefing = onBriefing
        self.onMissions = onMissions
        self.onHome = onHome
        _session = State(initialValue: FlightSession(normalizedAirportPosition: origin.normalizedPosition))
        _progress = State(initialValue: MissionFlightProgress(instructionCount: briefing.steps.count))
    }

    var body: some View {
        MapView(session: session,
                configuration: .transportMission,
                sidePanelTitle: "Mission",
                isSidePanelPresented: $showsMissionPanel,
                sidePanel: { flightCard })
            .overlay(alignment: .topLeading) {
                HStack(spacing: 10) {
                    HomeControl(action: leaveForHome)
                    Button(action: leaveForBriefing) {
                        Label("Back to Briefing", systemImage: "chevron.backward")
                    }
                    .buttonStyle(.glass)
                }
                .padding(.top, 40)
                .padding(.leading, 16)
            }
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

    private var missionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Transport")
                .font(.headline.weight(.bold))
                .foregroundStyle(ControlPalette.primaryText)
            Text("\(briefing.originName) → \(briefing.destinationName)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ControlPalette.secondaryText)

            Divider()

            Text("\(progress.completedInstructionIndices.count) OF \(briefing.steps.count) STEPS COMPLETE")
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(ControlPalette.accent)
            Text("Check off steps as you complete them. Clear a check to revisit a step.")
                .font(.caption)
                .foregroundStyle(ControlPalette.secondaryText)

            ForEach(Array(briefing.steps.enumerated()), id: \.offset) { index, step in
                instructionRow(step, at: index)
            }

            Divider()

            HStack {
                Text("SIMULATED TIME")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(ControlPalette.secondaryText)
                Spacer()
                Text(simulatedTimeLabel)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(ControlPalette.primaryText)
            }

            Button(role: .destructive, action: completeFlight) {
                Label("Flight Complete", systemImage: "flag.checkered")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func instructionRow(_ step: FlightPlanBriefingStep, at index: Int) -> some View {
        let title = step.kind == .terminalReference ? "Final position reference" : step.title

        return VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(
                get: { progress.isInstructionComplete(at: index) },
                set: { progress.setInstructionComplete($0, at: index) }
            )) {
                Text("\(index + 1). \(title)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ControlPalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .toggleStyle(.checkbox)

            VStack(alignment: .leading, spacing: 4) {
                Text("Tune \(step.guidance.stationIdent) \(String(format: "%.2f", step.guidance.frequencyMHz))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(ControlPalette.secondaryText)
                Text("Set OBS \(String(format: "%03d", step.guidance.obsDegrees))° · Confirm \(step.guidance.flag.rawValue)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(ControlPalette.primaryText)

                if step.kind == .terminalReference {
                    Text("Use this practical radial reference to locate Midland before marking the flight complete.")
                        .font(.caption)
                        .foregroundStyle(ControlPalette.secondaryText)
                }
            }
            .padding(.leading, 20)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
    }

    private var resultCard: some View {
        let completion = completion!

        return VStack(alignment: .leading, spacing: 14) {
            Text("Flight Complete")
                .font(.title3.weight(.bold))
                .foregroundStyle(ControlPalette.primaryText)
            Text("Silverkeep Strip → Midland Cityport")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ControlPalette.secondaryText)
            Text("Your position was recorded when you marked the flight complete.")
                .font(.caption)
                .foregroundStyle(ControlPalette.secondaryText)

            Divider()

            resultMetric(title: "SIMULATED TIME", value: formatTime(completion.simulatedElapsedSeconds))
            resultMetric(title: "DISTANCE FROM MIDLAND", value: String(format: "%.2f NM", completion.distanceFromDestinationNM))

            Divider()

            Button(action: flyAgain) {
                Label("Fly Again", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(ControlPalette.accent)

            Button("Back to Missions", action: leaveForMissions)
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var flightCard: some View {
        if completion == nil {
            missionCard
        } else {
            resultCard
        }
    }

    private func resultMetric(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(ControlPalette.secondaryText)
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(ControlPalette.primaryText)
        }
    }

    private var simulatedTimeLabel: String {
        formatTime(session.elapsedSimulatedSeconds)
    }

    private func formatTime(_ elapsedSeconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(elapsedSeconds.rounded()))
        let hours = totalSeconds / 3_600
        let minutes = totalSeconds % 3_600 / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }

    private func completeFlight() {
        session.isFlying = false
        showsMissionPanel = true
        completion = MissionFlightCompletion(
            resolvedPlan: resolvedPlan,
            aircraftPosition: session.normalizedAircraftPosition,
            simulatedElapsedSeconds: session.elapsedSimulatedSeconds,
            mapWidthNM: FlatMap.widthNM,
            mapHeightNM: FlatMap.heightNM
        )
    }

    private func flyAgain() {
        guard let origin = resolvedPlan.points.first else {
            preconditionFailure("Transport mission needs a resolved origin.")
        }
        session.isFlying = false
        session = FlightSession(normalizedAirportPosition: origin.normalizedPosition)
        progress = MissionFlightProgress(instructionCount: briefing.steps.count)
        completion = nil
        showsMissionPanel = true
        diagnosticsStore.activeSession = session
    }

    private func leaveForBriefing() {
        session.isFlying = false
        onBriefing()
    }

    private func leaveForHome() {
        session.isFlying = false
        onHome()
    }

    private func leaveForMissions() {
        session.isFlying = false
        onMissions()
    }
}

#Preview {
    let plan = try! FlightPlanCatalog.load(named: "SilverkeepToMidland")
    let resolvedPlan = try! FlightPlanResolver.resolve(
        plan,
        airports: Airport.myosia,
        stations: VORStation.myosia,
        mapWidthNM: FlatMap.widthNM,
        mapHeightNM: FlatMap.heightNM,
        cruiseSpeedKnots: 260
    )
    TransportMissionView(
        resolvedPlan: resolvedPlan,
        briefing: FlightPlanBriefing(resolvedPlan: resolvedPlan),
        onBriefing: {},
        onMissions: {},
        onHome: {}
    )
    .frame(width: 1100, height: 760)
}
