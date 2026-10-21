import SwiftUI
import AppKit

/// The normal exercise surface; Stage 2 exposes it through the Debug preview.
struct MovingPositionChallengeView: View {
    @State private var attempt: MovingPositionChallengeSession
    @State private var showsPracticePanel = true
    @State private var chartSize = CGSize.zero
    @State private var fitRevision = 0
    @Environment(\.scenePhase) private var scenePhase
    let onPractice: () -> Void
    let onHome: () -> Void
    var developmentNote: String? = nil

    init(session: MovingPositionChallengeSession? = nil,
         onPractice: @escaping () -> Void, onHome: @escaping () -> Void, developmentNote: String? = nil) {
        _attempt = State(initialValue: session ?? MovingPositionChallengeSession())
        self.onPractice = onPractice
        self.onHome = onHome
        self.developmentNote = developmentNote
    }

    private var cameraPolicy: ChartCameraPolicy { attempt.result == nil ? .fullChart : .comparison }
    private var fitRequest: ChartFitRequest? {
        guard let result = attempt.result else { return nil }
        return ChartFitRequest(positions: [result.estimate.position, result.actual.normalizedPosition], revision: fitRevision)
    }

    var body: some View {
        let id = attempt.attemptID
        MapView(session: attempt.surface, configuration: .movingPositionChallenge,
                receptionPosition: attempt.actualState?.normalizedPosition,
                sidePanelTitle: "Practice", isSidePanelPresented: $showsPracticePanel,
                flightStatusHeight: 44, cameraPolicy: cameraPolicy, fitRequest: fitRequest,
                estimatedHeading: headingBinding(for: id),
                nav1Override: receiverBinding(.nav1, for: id), nav2Override: receiverBinding(.nav2, for: id),
                onSwapOverride: { attempt.swapReceivers(for: id) },
                cockpitInputsEnabled: attempt.isActive, receptionEnabled: attempt.actualState != nil,
                controlResetID: id,
                sidePanel: { panel(for: id) },
                flightStatus: { status(for: id) },
                screenOverlay: { viewport in
                    Group {
                        if let result = attempt.result {
                            PracticeComparisonView(estimatePosition: result.estimate.position,
                                estimatedHeading: result.estimate.heading, actualPosition: result.actual.normalizedPosition,
                                actualHeading: result.actual.heading, viewport: viewport)
                        } else if attempt.isActive {
                            DraggablePositionEstimateMarker(position: positionBinding(for: id),
                                heading: attempt.estimate.heading, viewport: viewport)
                                .id(id)
                        } else {
                            PositionEstimateMarker(heading: attempt.estimate.heading)
                                .position(viewport.point(for: attempt.estimate.position))
                                .allowsHitTesting(false)
                        }
                    }
                    .onAppear { chartSize = viewport.size }
                    .onChange(of: viewport.size) { _, size in chartSize = size }
                })
            .overlay(alignment: .topLeading) {
                HStack(spacing: 8) {
                    HomeControl { leave(onHome) }
                    Button("Back to Practice") { leave(onPractice) }
                        .buttonStyle(.glass)
                }
                .padding(.top, 40).padding(.leading, 16)
            }
            .task(id: id) { await refreshAttempt(for: id) }
            .onChange(of: attempt.phase) { _, phase in
                if phase == .completed { showsPracticePanel = true }
            }
            .onChange(of: scenePhase) { _, _ in attempt.refresh(for: id) }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                attempt.refresh(for: id)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didDeminiaturizeNotification)) { _ in
                attempt.refresh(for: id)
            }
    }

    private func panel(for id: UUID) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Position & Heading Challenge").font(.title3.bold())
            if let developmentNote {
                Text(developmentNote).font(.caption).foregroundStyle(.secondary)
            }
            switch attempt.phase {
            case .ready:
                Text("Use two VOR fixes taken at different times to estimate the moving aircraft's current position and heading.")
                Text("Begin starts the timer and enables the instruments. Drag the circle to your estimate, set estimated heading with the knob, and Submit when ready.")
                    .font(.callout)
                Text("The aircraft flies continuously at 260 kt in still air. Switching apps does not pause it; system sleep pauses flight and elapsed time.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Begin", action: begin).buttonStyle(.borderedProminent).tint(ControlPalette.accent)
            case .active:
                Text("Find a position fix, then use a later fix to infer heading. Update the circle to the aircraft's current estimated position.")
                    .font(.callout)
                Text("The heading indicator and arrow show your estimate. Turning the knob does not steer the hidden aircraft.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Submit") { attempt.submit(for: id) }
                    .buttonStyle(.borderedProminent).tint(ControlPalette.accent)
            case .completed:
                if let result = attempt.result {
                    Text(result.ending.label).font(.headline)
                    Text("Accuracy").font(.subheadline.bold())
                    measurement("Distance error", value: result.distanceErrorNM > 0 && result.distanceErrorNM < 0.01
                        ? "<0.01 NM" : String(format: "%.2f NM", result.distanceErrorNM))
                    measurement("Heading error", value: String(format: "%.1f°", result.headingErrorDegrees))
                    Text("Time").font(.subheadline.bold()).padding(.top, 4)
                    measurement("Elapsed", value: MovingPositionChallengeSession.elapsedLabel(result.elapsedSeconds))
                    Text(String(format: "Estimate %03d° · Actual %03d°", Int(result.estimate.heading), Int(result.actual.heading)))
                        .font(.caption.monospacedDigit())
                    Button("Try Again", action: begin).buttonStyle(.borderedProminent).tint(ControlPalette.accent)
                }
            case .generationFailed:
                Text("Couldn't create a valid challenge. Try again.")
                Button("Try Again", action: begin).buttonStyle(.borderedProminent).tint(ControlPalette.accent)
            case .abandoned:
                Text("Attempt closed.")
            }
        }
        .foregroundStyle(ControlPalette.primaryText)
    }

    private func measurement(_ title: String, value: String) -> some View {
        HStack { Text(title); Spacer(); Text(value).monospacedDigit().bold() }
            .font(.callout)
    }

    private func status(for id: UUID) -> some View {
        HStack(spacing: 16) {
            Text("Elapsed \(MovingPositionChallengeSession.elapsedLabel(attempt.elapsedSeconds))")
                .font(.callout.monospacedDigit().weight(.semibold))
            Text("Still air · 260 kt · 1×").font(.caption).foregroundStyle(.secondary)
            Spacer()
            if attempt.isActive {
                Button("Submit") { attempt.submit(for: id) }
                    .buttonStyle(.borderedProminent).tint(ControlPalette.accent)
            } else if attempt.result != nil {
                PracticeComparisonControls(onZoomOut: { zoom(by: 0.8) }, onZoomIn: { zoom(by: 1.25) },
                                           onFit: { fitRevision += 1 })
            }
        }
        .padding(.horizontal, 16)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func begin() {
        attempt.begin()
        showsPracticePanel = true
    }

    private func leave(_ action: () -> Void) {
        attempt.abandon()
        action()
    }

    private func positionBinding(for id: UUID) -> Binding<CGPoint> {
        Binding(get: { attempt.estimate.position }, set: { attempt.setPosition($0, for: id) })
    }

    private func headingBinding(for id: UUID) -> Binding<Double> {
        Binding(get: { attempt.estimate.heading }, set: { attempt.setHeading($0, for: id) })
    }

    private func receiverBinding(_ receiver: MovingPositionChallengeSession.Receiver, for id: UUID) -> Binding<NAVReceiver> {
        Binding(get: { receiver == .nav1 ? attempt.surface.nav1 : attempt.surface.nav2 },
                set: { attempt.setReceiver($0, receiver: receiver, for: id) })
    }

    private func zoom(by factor: CGFloat) {
        let surface = attempt.surface
        let viewport = ChartViewport(size: chartSize, crop: cameraPolicy.crop, zoom: surface.zoom, pan: surface.pan)
        let camera = viewport.zoomed(by: factor,
            anchoredAt: CGPoint(x: chartSize.width / 2, y: chartSize.height / 2), policy: cameraPolicy)
        surface.zoom = camera.zoom
        surface.pan = camera.pan
    }

    private func refreshAttempt(for id: UUID) async {
        let clock = SuspendingClock()
        while !Task.isCancelled && attempt.isActive && attempt.attemptID == id {
            attempt.refresh(for: id)
            do { try await clock.sleep(for: .milliseconds(33)) }
            catch { return }
        }
    }
}
