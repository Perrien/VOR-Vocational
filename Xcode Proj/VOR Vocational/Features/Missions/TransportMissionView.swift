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
        MapView(session: session, configuration: .transportMission)
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
            .overlay(alignment: .bottomTrailing) {
                flightCard
                    .padding(16)
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
        let step = briefing.steps[progress.activeInstructionIndex]

        return VStack(alignment: .leading, spacing: 12) {
            Text("Transport")
                .font(.headline.weight(.bold))
                .foregroundStyle(ControlPalette.primaryText)
            Text("\(briefing.originName) → \(briefing.destinationName)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ControlPalette.secondaryText)

            Divider()

            Text("STEP \(progress.activeInstructionNumber) OF \(briefing.steps.count)")
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(ControlPalette.accent)
            Text(step.kind == .terminalReference ? "Final position reference" : step.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ControlPalette.primaryText)
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
            } else {
                Text("Advance when you judge this instruction is complete.")
                    .font(.caption)
                    .foregroundStyle(ControlPalette.secondaryText)
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

            if progress.canAdvance {
                Button("Next instruction") {
                    progress.advanceInstruction()
                }
                .buttonStyle(.borderedProminent)
                .tint(ControlPalette.accent)
                .frame(maxWidth: .infinity)
            } else {
                Text("Final instruction active")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            Button(role: .destructive, action: completeFlight) {
                Label("Flight Complete", systemImage: "flag.checkered")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding(16)
        .frame(width: 310, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.96),
                    in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.1)))
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
        .padding(16)
        .frame(width: 310, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.96),
                    in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.1)))
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
