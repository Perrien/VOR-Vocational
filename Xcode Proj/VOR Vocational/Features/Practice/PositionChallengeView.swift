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
    /// The current target, normalized like `session.normalizedAircraftPosition`.
    /// Kept separately from `state` because `.revealed`'s `Result` stores its
    /// target already converted to unscaled map space for scoring.
    @State private var target: CGPoint?
    @State private var latestImageRect: CGRect = .zero

    /// The panel's drag offset from its default corner, so the player can
    /// pull it off a VOR it happens to be sitting on. Kept outside the
    /// chart overlay (unlike the target reveal) so it stays fixed on screen
    /// instead of scaling and panning with the map.
    @State private var panelOffset: CGSize = .zero
    @State private var panelDragStart: CGSize?

    var onHome: () -> Void

    private let stations: [VORStation] = VORStation.myosia

    var body: some View {
        MapView(session: session,
                configuration: .positionChallenge,
                receptionPosition: target) { imageRect in
            challengeOverlay(imageRect: imageRect)
        }
        .overlay(alignment: .topLeading) {
            HomeControl(action: onHome)
                .padding(.top, 40)
                .padding(.leading, 16)
        }
        .overlay(alignment: .bottomTrailing) {
            panelCard
                .padding(16)
                .offset(panelOffset)
                .gesture(panelDrag)
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
            if case .revealed(let result) = state {
                Path { path in
                    path.move(to: result.guess)
                    path.addLine(to: result.target)
                }
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .foregroundStyle(ControlPalette.accent)

                Image(systemName: "mappin.circle.fill")
                    .font(.title)
                    .foregroundStyle(.red)
                    .position(result.target)
            }
        }
        .onAppear { latestImageRect = imageRect }
        .onChange(of: imageRect) { _, newValue in latestImageRect = newValue }
    }

    private var panelCard: some View {
        PositionChallengePanel(state: state, onStart: start, onCheck: check, onReset: start)
            .padding(16)
            .frame(width: 260, alignment: .leading)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.94),
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.08)))
    }

    /// Drags the panel by its own background; the default 10pt drag
    /// threshold (unlike the map's own gestures, which need a named
    /// coordinate space) means a plain tap still reaches the buttons inside.
    private var panelDrag: some Gesture {
        DragGesture()
            .onChanged { value in
                let start = panelDragStart ?? panelOffset
                if panelDragStart == nil { panelDragStart = start }
                panelOffset = CGSize(width: start.width + value.translation.width,
                                      height: start.height + value.translation.height)
            }
            .onEnded { _ in panelDragStart = nil }
    }

    /// Hides the target, resets the guess marker to the chart's center, and
    /// picks a fresh solvable target (also used for "New Challenge").
    private func start() {
        // A session can be paused or flying before an exercise begins. The
        // configuration also omits the timer, but clear stale state before
        // assigning a new guess so it cannot be advanced during this reset.
        session.isFlying = false
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
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ControlPalette.primaryText)

            switch state {
            case .inactive:
                Text("Tune in-range VORs, dial OBS until the needles center, then drag the plane to your fix.")
                    .font(.caption2)
                    .foregroundStyle(ControlPalette.secondaryText)
                Button("Start Challenge", action: onStart)
                    .buttonStyle(.borderedProminent)
                    .tint(ControlPalette.accent)

            case .active:
                Text("Drag the plane to where you think you are.")
                    .font(.caption2)
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
    }
}

#Preview {
    PositionChallengeView(onHome: {})
        .frame(width: 1100, height: 760)
}
