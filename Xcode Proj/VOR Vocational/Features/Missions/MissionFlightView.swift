import SwiftUI

/// Common instrument-led mission runner. Mission content is supplied as data.
struct MissionFlightView: View {
    let mission: MissionFlightDefinition
    let conditions: FlightConditions
    var onBriefing: () -> Void
    var onMissions: () -> Void
    var onHome: () -> Void

    @State private var session: FlightSession
    @State private var progress: MissionFlightProgress
    @State private var showsMissionPanel = true
    @Environment(FlightDiagnosticsStore.self) private var diagnosticsStore

    init(mission: MissionFlightDefinition, conditions: FlightConditions,
         onBriefing: @escaping () -> Void, onMissions: @escaping () -> Void,
         onHome: @escaping () -> Void) {
        self.mission = mission
        self.conditions = conditions
        self.onBriefing = onBriefing
        self.onMissions = onMissions
        self.onHome = onHome
        _session = State(initialValue: FlightSession(mission: mission, conditions: conditions))
        _progress = State(initialValue: MissionFlightProgress(instructionCount: mission.instructions.count))
    }

    var body: some View {
        MapView(session: session, configuration: .mission,
                sidePanelTitle: "Mission", isSidePanelPresented: $showsMissionPanel,
                sidePanel: { flightCard })
            .id(ObjectIdentifier(session))
            .overlay(alignment: .topLeading) {
                HStack(spacing: 10) {
                    HomeControl(action: { leave(onHome) })
                    Button { leave(onBriefing) } label: {
                        Label("Back to Briefing", systemImage: "chevron.backward")
                    }
                    .buttonStyle(.glass)
                }
                .padding(.top, 40).padding(.leading, 16)
            }
            .ignoresSafeArea()
            .onAppear { diagnosticsStore.activeSession = session }
            .onDisappear {
                session.isFlying = false
                if diagnosticsStore.activeSession === session { diagnosticsStore.activeSession = nil }
            }
    }

    @ViewBuilder private var flightCard: some View {
        if let completion = session.completion { resultCard(completion) }
        else { missionCard }
    }

    private var missionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(mission.title).font(.headline.weight(.bold))
                .foregroundStyle(ControlPalette.primaryText)
            if !mission.instructions.isEmpty {
                Divider()
                Text("\(progress.completedInstructionIndices.count) OF \(mission.instructions.count) STEPS COMPLETE")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(ControlPalette.accent)
                Text("Check off steps as you complete them. Clear a check to revisit a step.")
                    .font(.caption).foregroundStyle(ControlPalette.secondaryText)
                ForEach(Array(mission.instructions.enumerated()), id: \.offset) { index, step in
                    instructionRow(step, at: index)
                }
            }
            Divider()
            resultMetric(title: "SIMULATED TIME", value: formatTime(session.elapsedSimulatedSeconds))
            Text(session.conditions.label)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(ControlPalette.primaryText)
            Button(role: .destructive) {
                session.completeMission()
                showsMissionPanel = true
            } label: {
                Label("Flight Complete", systemImage: "flag.checkered").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).tint(.orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func instructionRow(_ step: MissionInstruction, at index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(get: { progress.isInstructionComplete(at: index) },
                                 set: { progress.setInstructionComplete($0, at: index) })) {
                Text("\(index + 1). \(step.title)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ControlPalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .toggleStyle(.checkbox)
            VStack(alignment: .leading, spacing: 4) {
                if let guidance = step.guidance {
                    Text("Tune \(guidance.stationIdent) \(String(format: "%.2f", guidance.frequencyMHz))")
                        .font(.caption.monospacedDigit()).foregroundStyle(ControlPalette.secondaryText)
                    Text("Set OBS \(String(format: "%03d", guidance.obsDegrees))° · Confirm \(guidance.flag.rawValue)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(ControlPalette.primaryText)
                }
                if let detail = step.detail {
                    Text(detail).font(.caption).foregroundStyle(ControlPalette.secondaryText)
                }
            }
            .padding(.leading, 20)
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
    }

    private func resultCard(_ completion: MissionFlightCompletion) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Flight Complete").font(.title3.weight(.bold))
            Text(completion.mission.title).font(.caption.weight(.semibold))
            Text("Your position was measured when you marked the flight complete.")
                .font(.caption).foregroundStyle(ControlPalette.secondaryText)
            Divider()
            resultMetric(title: "SIMULATED TIME", value: formatTime(completion.simulatedElapsedSeconds))
            Text(completion.conditions.label).font(.caption.monospacedDigit())
            if let destination = completion.mission.arrivalReference,
               let distance = completion.distanceFromDestinationNM {
                resultMetric(title: "DISTANCE FROM \(destination.name.uppercased())",
                             value: String(format: "%.2f NM", distance))
            }
            Divider()
            Button(action: flyAgain) {
                Label("Fly Again", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).tint(ControlPalette.accent)
            Button("Back to Missions") { leave(onMissions) }.buttonStyle(.bordered)
        }
        .foregroundStyle(ControlPalette.primaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func resultMetric(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.caption2.weight(.bold)).foregroundStyle(ControlPalette.secondaryText)
            Spacer()
            Text(value).font(.subheadline.monospacedDigit().weight(.semibold))
        }
    }

    private func formatTime(_ elapsed: TimeInterval) -> String {
        let seconds = max(0, Int(elapsed.rounded()))
        return String(format: "%d:%02d:%02d", seconds / 3_600, seconds % 3_600 / 60, seconds % 60)
    }

    private func flyAgain() {
        session.isFlying = false
        session = session.freshMissionSession()
        progress = MissionFlightProgress(instructionCount: mission.instructions.count)
        showsMissionPanel = true
        diagnosticsStore.activeSession = session
    }

    private func leave(_ action: () -> Void) {
        session.isFlying = false
        action()
    }
}

#if DEBUG
/// A bounded development preview: no production catalog entry or bundle lookup.
struct MissionRunnerPreviewView: View {
    @State private var diagnosticsStore = FlightDiagnosticsStore()
    @Environment(\.dismissWindow) private var dismissWindow
    private let destination = MissionChartPoint(name: "Survey endpoint", normalizedPosition: CGPoint(x: 0.6, y: 0.5))

    var body: some View {
        MissionFlightView(
            mission: MissionFlightDefinition(
                id: "preview-survey", title: "Crosswind survey",
                initialState: FlightAircraftState(normalizedPosition: CGPoint(x: 0.4, y: 0.4), heading: 90, speedKnots: 120),
                plannedPoints: [MissionChartPoint(name: "Survey start", normalizedPosition: CGPoint(x: 0.3, y: 0.3)),
                                destination],
                arrivalReference: destination,
                instructions: [MissionInstruction(title: "Establish a position fix using both NAV receivers.")]),
            conditions: .steady(SteadyWind(fromDegrees: 180, speedKnots: 15)!),
            onBriefing: closePreview, onMissions: closePreview, onHome: closePreview
        )
        .environment(diagnosticsStore)
    }

    private func closePreview() { dismissWindow(id: "mission-runner-preview") }
}

#Preview("Alternate mission — no bundled plan") {
    MissionRunnerPreviewView().frame(width: 1100, height: 760)
}
#endif
