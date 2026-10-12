import SwiftUI

/// A third Mode-boundary wrapper alongside `FreeFlightView` (ADR-0001): owns
/// one `FlightSession`, whose `normalizedAircraftPosition` doubles as the
/// player's guess marker exactly as `MapView`'s existing plane-drag already
/// works, and one `PositionChallenge.State`. Renders `MapView` with the
/// hidden target as its reception position, so the NAV radios read as if
/// standing at the target rather than at the freely-dragged guess, plus the
/// chart-overlay extension point supplying the target/result reveal.
struct PositionChallengeView: View {
    @State private var session = FlightSession(normalizedAirportPosition: CGPoint(x: 0.5, y: 0.5))
    @State private var state: PositionChallenge.State = .inactive
    @State private var showsPracticePanel = true
    /// Reveal positions remain normalized so changing the chart's size when
    /// collapsing the panel cannot move the checked fix or its target.
    @State private var target: CGPoint?
    @State private var checkedGuess: CGPoint?
    @State private var latestImageRect: CGRect = .zero

    var onHome: () -> Void

    private let stations: [VORStation] = VORStation.myosia

    var body: some View {
        MapView(session: session,
                configuration: .positionChallenge,
                receptionPosition: target,
                sidePanelTitle: "Practice",
                isSidePanelPresented: $showsPracticePanel,
                sidePanel: {
                    PositionChallengePanel(state: state, onStart: start, onCheck: check, onReset: start)
                }) { imageRect in
            challengeOverlay(imageRect: imageRect)
        }
        .overlay(alignment: .topLeading) {
            HomeControl(action: onHome)
                .padding(.top, 40)
                .padding(.leading, 16)
        }
        .ignoresSafeArea()
    }

    /// The hidden target and the guess/target line, revealed only once
    /// checked; drawn in the same fitted `imageRect` `MapView` uses
    /// internally, so it lines up with the chart without recomputing that
    /// geometry independently. Also tracks the latest `imageRect` for use by
    /// `check()`, which runs outside this closure.
    @ViewBuilder
    private func challengeOverlay(imageRect: CGRect) -> some View {
        ZStack {
            if case .revealed = state, let checkedGuess, let target {
                let guessPoint = FlatMap.point(for: checkedGuess, in: imageRect)
                let targetPoint = FlatMap.point(for: target, in: imageRect)

                Path { path in
                    path.move(to: guessPoint)
                    path.addLine(to: targetPoint)
                }
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .foregroundStyle(ControlPalette.accent)

                Image(systemName: "mappin.circle.fill")
                    .font(.title)
                    .foregroundStyle(.red)
                    .position(targetPoint)
            }
        }
        .onAppear { latestImageRect = imageRect }
        .onChange(of: imageRect) { _, newValue in latestImageRect = newValue }
    }

    /// Hides the target, resets the guess marker to the chart's center, and
    /// picks a fresh solvable target (also used for "New Challenge").
    private func start() {
        // A session can be paused or flying before an exercise begins. The
        // configuration also omits the timer, but clear stale state before
        // assigning a new guess so it cannot be advanced during this reset.
        session.isFlying = false
        showsPracticePanel = true
        checkedGuess = nil
        session.normalizedAircraftPosition = CGPoint(x: 0.5, y: 0.5)
        let newTarget = PositionChallenge.randomTarget(stations: stations,
                                                         mapWidthNM: FlatMap.widthNM,
                                                         mapHeightNM: FlatMap.heightNM)
        target = newTarget
        state = .active(target: newTarget)
    }

    /// Scores the current guess against the hidden target, converting both
    /// through the fitted `imageRect` into the same unscaled map space
    /// `PositionChallenge.score` expects.
    private func check() {
        guard case .active = state, let target, latestImageRect != .zero else { return }
        let guessPoint = FlatMap.point(for: session.normalizedAircraftPosition, in: latestImageRect)
        let targetPoint = FlatMap.point(for: target, in: latestImageRect)
        let pixelsPerNM = FlatMap.pixelsPerNM(in: latestImageRect, mapWidthNM: FlatMap.widthNM)
        checkedGuess = session.normalizedAircraftPosition
        state = .revealed(PositionChallenge.score(guess: guessPoint, target: targetPoint, pixelsPerNM: pixelsPerNM))
    }
}

/// The "find your position" challenge status and controls: start a
/// challenge, check a placed guess, or start a new one.
struct PositionChallengePanel: View {
    let state: PositionChallenge.State
    let onStart: () -> Void
    let onCheck: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Position Challenge")
                .font(.headline.weight(.bold))
                .foregroundStyle(ControlPalette.primaryText)

            switch state {
            case .inactive:
                Text("Tune in-range VORs, dial OBS until the needles center, then drag the plane to your fix.")
                    .font(.caption)
                    .foregroundStyle(ControlPalette.secondaryText)
                Button("Start Challenge", action: onStart)
                    .buttonStyle(.borderedProminent)
                    .tint(ControlPalette.accent)

            case .active:
                Text("Drag the plane to where you think you are.")
                    .font(.caption)
                    .foregroundStyle(ControlPalette.secondaryText)
                Button("Check Placement", action: onCheck)
                    .buttonStyle(.borderedProminent)
                    .tint(ControlPalette.accent)

            case .revealed(let result):
                Text(String(format: "Off by %.1f NM", result.errorNM))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ControlPalette.accent)
                Button("New Challenge", action: onReset)
                    .buttonStyle(.borderedProminent)
                    .tint(ControlPalette.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    PositionChallengeView(onHome: {})
        .frame(width: 1100, height: 760)
}
