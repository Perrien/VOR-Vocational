import SwiftUI

/// A fitted physical chart projection, independent of the former live camera.
nonisolated struct MissionChartProjection {
    let size: CGSize
    let centerNM: CGPoint
    let pointsPerNM: CGFloat

    init(positions: [CGPoint], size: CGSize, padding: CGFloat = 64) {
        let points = positions.map { FlightWorld.nauticalMiles(for: $0) }
        let minX = points.map(\.x).min() ?? 0
        let maxX = points.map(\.x).max() ?? 0
        let minY = points.map(\.y).min() ?? 0
        let maxY = points.map(\.y).max() ?? 0
        self.size = size
        centerNM = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        pointsPerNM = min(max(1, size.width - 2 * padding) / max(10, maxX - minX),
                          max(1, size.height - 2 * padding) / max(10, maxY - minY))
    }

    func point(for position: CGPoint) -> CGPoint {
        let nm = FlightWorld.nauticalMiles(for: position)
        return CGPoint(x: size.width / 2 + (nm.x - centerNM.x) * pointsPerNM,
                       y: size.height / 2 + (nm.y - centerNM.y) * pointsPerNM)
    }

    var sourceImageRect: CGRect {
        CGRect(origin: point(for: .zero),
               size: CGSize(width: FlightWorld.widthNM * pointsPerNM,
                            height: FlightWorld.heightNM * pointsPerNM))
    }
}

/// Only the completed value is observed. Viewing this screen cannot fly the aircraft.
struct MissionDebriefView: View {
    let completion: MissionFlightCompletion
    var onFlyAgain: () -> Void
    var onBriefing: () -> Void
    var onMissions: () -> Void
    var onHome: () -> Void

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                chart.frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .topLeading) {
                        HomeControl(action: onHome).padding(.top, 40).padding(.leading, 16)
                    }
                Divider()
                ScrollView { summary.padding(24).padding(.top, 40) }
                    .frame(width: min(400, max(340, geometry.size.width * 0.34)))
                    .background(Color(nsColor: .windowBackgroundColor))
            }
            .background(FlatMap.oceanColor)
        }
        .ignoresSafeArea()
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Flight debrief").font(.title2.weight(.bold))
            Text(completion.mission.title).font(.headline)
            Text(completion.ending.label).font(.title3.weight(.semibold))
            Text("Unscored flight review").font(.subheadline).foregroundStyle(.secondary)
            Divider()
            Text(completion.conditions.label).font(.subheadline.monospacedDigit())
            VStack(alignment: .leading, spacing: 6) {
                Text("SIMULATED TIME").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(formattedTime).font(.title3.monospacedDigit())
            }
            if let reference = completion.mission.arrivalReference,
               let distance = completion.distanceFromDestinationNM {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Distance from \(reference.name)").font(.subheadline)
                    Text(String(format: "%.2f NM", distance)).font(.title3.monospacedDigit())
                }
            }
            Divider()
            Button(action: onFlyAgain) {
                Label("Fly Again", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).tint(ControlPalette.accent)
            Button("Back to Briefing", action: onBriefing).buttonStyle(.bordered)
            Button("Back to Missions", action: onMissions).buttonStyle(.bordered)
        }
        .foregroundStyle(ControlPalette.primaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formattedTime: String {
        let seconds = max(0, Int(completion.simulatedElapsedSeconds.rounded()))
        return String(format: "%d:%02d:%02d", seconds / 3_600, seconds % 3_600 / 60, seconds % 60)
    }

    private var chart: some View {
        GeometryReader { geometry in
            let flown = completion.recording.map { $0.aircraftState.normalizedPosition }
            let planned = completion.mission.plannedPoints.map(\.normalizedPosition)
            let arrival = completion.mission.arrivalReference
            let projection = MissionChartProjection(positions: flown + planned + (arrival.map { [$0.normalizedPosition] } ?? []),
                                                    size: geometry.size)
            ZStack {
                Canvas { context, _ in
                    context.draw(Image("MyosiaMap"), in: projection.sourceImageRect)
                    if !planned.isEmpty {
                        let path = polyline(planned, projection: projection)
                        context.stroke(path, with: .color(.white.opacity(0.9)), lineWidth: 6)
                        context.stroke(path, with: .color(.orange), style: StrokeStyle(lineWidth: 3, dash: [8, 5]))
                    }
                    let path = polyline(flown, projection: projection)
                    context.stroke(path, with: .color(.white.opacity(0.9)), lineWidth: 6)
                    context.stroke(path, with: .color(.blue.opacity(0.9)), lineWidth: 3)
                }
                if let first = flown.first, let last = flown.last {
                    if first == last {
                        marker("Start / Finish", symbol: "flag.checkered.circle.fill", color: .blue)
                            .position(projection.point(for: last))
                    } else {
                        marker("Start", symbol: "circle.fill", color: .green)
                            .position(projection.point(for: first))
                        marker("Finish", symbol: "flag.checkered.circle.fill", color: .blue)
                            .position(projection.point(for: last))
                    }
                }
                if let arrival {
                    marker(arrival.name, symbol: "mappin.circle.fill", color: .orange)
                        .position(projection.point(for: arrival.normalizedPosition))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Planned and flown flight chart")
            .accessibilityValue("\(flown.count) recorded samples, \(planned.count) planned points. \(firstAndLastLabel)")
        }
        .overlay(alignment: .bottomLeading) {
            HStack(spacing: 16) {
                if !completion.mission.plannedPoints.isEmpty { legend("Planned", color: .orange, dashed: true) }
                legend("Flown", color: .blue, dashed: false)
            }
            .font(.caption.weight(.semibold)).padding(10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8)).padding(16)
        }
    }

    private var firstAndLastLabel: String {
        completion.recording.count == 1 ? "Start and finish coincide; no flight segment." : "Start and finish marked."
    }

    private func polyline(_ positions: [CGPoint], projection: MissionChartProjection) -> Path {
        Path { path in
            guard let first = positions.first else { return }
            path.move(to: projection.point(for: first))
            for position in positions.dropFirst() { path.addLine(to: projection.point(for: position)) }
        }
    }

    private func marker(_ title: String, symbol: String, color: Color) -> some View {
        Image(systemName: symbol).font(.system(size: 18)).foregroundStyle(color)
            .frame(width: 20, height: 20)
            .background(.white, in: Circle())
            .overlay(alignment: .top) {
                Text(title).font(.caption2.weight(.semibold)).fixedSize()
                    .padding(4).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
                    .offset(y: 22)
            }
    }

    private func legend(_ title: String, color: Color, dashed: Bool) -> some View {
        HStack(spacing: 6) {
            Path { path in path.move(to: .zero); path.addLine(to: CGPoint(x: 30, y: 0)) }
                .stroke(color, style: StrokeStyle(lineWidth: 3, dash: dashed ? [6, 4] : []))
                .frame(width: 30, height: 1)
            Text(title)
        }
    }
}
