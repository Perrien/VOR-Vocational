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
        ZStack {
            if let completion = session.completion {
                MissionDebriefView(completion: completion, onFlyAgain: flyAgain,
                                   onBriefing: { leave(onBriefing) },
                                   onMissions: { leave(onMissions) }, onHome: { leave(onHome) })
            } else {
                MapView(session: session, configuration: .mission,
                        sidePanelTitle: "Mission", isSidePanelPresented: $showsMissionPanel,
                        flightStatusHeight: mission.timingSchedule == nil ? 0 : 56,
                        sidePanel: { missionCard },
                        flightStatus: {
                            if let display = session.timingDisplay { MissionTimingStrip(display: display) }
                        })
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
            }
        }
        .ignoresSafeArea()
        .onAppear { diagnosticsStore.activeSession = session }
        .onDisappear {
            session.leaveMission()
            if diagnosticsStore.activeSession === session { diagnosticsStore.activeSession = nil }
        }
    }

    private var missionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(mission.title).font(.headline.weight(.bold))
                .foregroundStyle(ControlPalette.primaryText)
            if session.legTiming != nil {
                Divider()
                MissionTimingPanel(session: session)
            }
            if !mission.instructions.isEmpty {
                Divider()
                Text("\(progress.completedInstructionIndices.count) OF \(mission.instructions.count) STEPS COMPLETE")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(ControlPalette.accent)
                    .help("Check or clear any step independently. Checkmarks never change leg timing.")
            }
            MissionInstructionListView(instructions: mission.instructions, schedule: mission.timingSchedule,
                display: session.timingDisplay, selectedLegIndex: session.legTiming?.selectedContext?.legIndex,
                actionsAreEnabled: session.canAdjustMissionTiming,
                onStartLeg: { session.startMissionLeg(at: $0) },
                completion: { index in
                    Binding(get: { progress.isInstructionComplete(at: index) },
                            set: { progress.setInstructionComplete($0, at: index) })
                })
            if let error = session.simulationError {
                Text(error).font(.caption).foregroundStyle(.red)
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
        session.leaveMission()
        session = session.freshMissionSession()
        progress = MissionFlightProgress(instructionCount: mission.instructions.count)
        showsMissionPanel = true
        diagnosticsStore.activeSession = session
    }

    private func leave(_ action: () -> Void) {
        session.leaveMission()
        action()
    }
}

#if DEBUG
/// A bounded development preview: no production catalog entry or bundle lookup.
struct MissionRunnerPreviewView: View {
    @State private var diagnosticsStore = FlightDiagnosticsStore()
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var preset: Preset = .timed

    private enum Preset: String, CaseIterable {
        case timed = "Timed 20-NM route with a 4-NM next leg at 120 kt"
        case manual = "Manual start away from origin"
        case noTiming = "No timing"
        case invalid = "Invalid timing"

        var mission: MissionFlightDefinition {
            let points = [
                MissionChartPoint(name: "Training departure airport", normalizedPosition: CGPoint(x: 0.4, y: 0.5)),
                MissionChartPoint(name: "Repeated radial intersection reference", normalizedPosition: CGPoint(x: 0.44, y: 0.5)),
                MissionChartPoint(name: "Repeated radial intersection reference", normalizedPosition: CGPoint(x: 0.448, y: 0.5))
            ]
            let schedule: MissionTimingSchedule?
            switch self {
            case .noTiming: schedule = nil
            case .invalid:
                schedule = MissionTimingSchedule(legs: [], planningAirspeedKnots: 120)
            case .timed, .manual:
                schedule = MissionTimingSchedule(legs: [
                    .init(startLabel: points[0].name, endLabel: points[1].name, distanceNM: 20),
                    .init(startLabel: points[1].name, endLabel: points[2].name, distanceNM: 4)
                ], planningAirspeedKnots: 120,
                   startupPolicy: self == .manual ? .manual : .firstLegOnFirstPlay)
            }
            return MissionFlightDefinition(
                id: "timing-preview-\(rawValue)", title: rawValue,
                initialState: FlightAircraftState(normalizedPosition: self == .manual
                    ? CGPoint(x: 0.42, y: 0.55) : points[0].normalizedPosition, heading: 90, speedKnots: 120),
                plannedPoints: points, arrivalReference: points.last,
                instructions: [MissionInstruction(title: "Establish a position fix using both NAV receivers.", timingLegIndex: 0),
                               MissionInstruction(title: "Choose when to begin the next leg.", timingLegIndex: 1)],
                timingSchedule: schedule)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Preview preset (resets flight)", selection: $preset) {
                ForEach(Preset.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu).padding(8).frame(maxWidth: 680)
            MissionFlightView(mission: preset.mission,
                conditions: .steady(SteadyWind(fromDegrees: 180, speedKnots: 15)!),
                onBriefing: closePreview, onMissions: closePreview, onHome: closePreview)
                .id(preset)
                .clipped()
        }
        .environment(diagnosticsStore)
    }

    private func closePreview() { dismissWindow(id: "mission-runner-preview") }
}

#Preview("Alternate mission — no bundled plan") {
    MissionRunnerPreviewView().frame(width: 1100, height: 760)
}
#endif
