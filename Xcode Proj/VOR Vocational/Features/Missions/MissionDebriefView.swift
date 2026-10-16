import SwiftUI

/// Only the completed value is observed. Viewing this screen cannot fly the aircraft.
struct MissionDebriefView: View {
    let completion: MissionFlightCompletion
    var onFlyAgain: () -> Void
    var onBriefing: () -> Void
    var onMissions: () -> Void
    var onHome: () -> Void

    @State private var camera = MissionDebriefCamera()
    @State private var dragTranslation: CGSize = .zero
    private let flownColor = Color(red: 0.06, green: 0.20, blue: 0.48)
    private let plannedStroke = StrokeStyle(lineWidth: 3, dash: [8, 5])

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
            Button("Home", action: onHome).buttonStyle(.bordered)
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
            let markers = self.markers
            let fitted = MissionChartProjection(
                positions: flown + planned + markers.map(\.position), size: geometry.size,
                fitRect: CGRect(x: 64, y: 104, width: max(1, geometry.size.width - 128),
                                height: max(1, geometry.size.height - 208)))
            let projection = fitted.applying(camera)
            let visibleMarkers = markers.filter { isVisible(projection.point(for: $0.position), in: geometry.size) }
            let placements = MissionDebriefMarkerLayout.place(visibleMarkers.map {
                .init(anchor: projection.point(for: $0.position), labelSize: labelSize(for: $0.title))
            }, in: CGRect(origin: .zero, size: geometry.size).insetBy(dx: 48, dy: 48),
               avoiding: [CGRect(x: 16, y: 40, width: 100, height: 44),
                          CGRect(x: geometry.size.width - 240, y: 40, width: 224, height: 44),
                          CGRect(x: 16, y: geometry.size.height - 64, width: 230, height: 48)])
            ZStack {
                Canvas { context, _ in
                    context.draw(Image("MyosiaMap"), in: projection.sourceImageRect)
                    if !planned.isEmpty {
                        let path = polyline(planned, projection: projection)
                        context.stroke(path, with: .color(.white.opacity(0.9)), lineWidth: 6)
                        context.stroke(path, with: .color(.orange), style: plannedStroke)
                        if planned.count == 1, let point = planned.first {
                            let center = projection.point(for: point)
                            let dot = Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8))
                            context.stroke(dot, with: .color(.white), lineWidth: 3)
                            context.fill(dot, with: .color(.orange))
                        }
                    }
                    let path = polyline(flown, projection: projection)
                    context.stroke(path, with: .color(.white.opacity(0.9)), lineWidth: 6)
                    context.stroke(path, with: .color(flownColor), lineWidth: 3)
                    for (marker, placement) in zip(visibleMarkers, placements) {
                        let anchor = projection.point(for: marker.position)
                        // Offscreen markers stay offscreen while inspecting another area.
                        guard isVisible(anchor, in: geometry.size) else { continue }
                        var leader = Path()
                        leader.move(to: anchor)
                        leader.addLine(to: placement.symbolCenter)
                        leader.addLine(to: CGPoint(x: placement.labelRect.midX, y: placement.labelRect.midY))
                        context.stroke(leader, with: .color(.white.opacity(0.9)), lineWidth: 3)
                        context.stroke(leader, with: .color(.secondary), lineWidth: 1)
                        if anchor != placement.symbolCenter {
                            context.fill(Path(ellipseIn: CGRect(x: anchor.x - 2, y: anchor.y - 2, width: 4, height: 4)),
                                         with: .color(marker.color))
                        }
                    }
                }
                ForEach(visibleMarkers.indices, id: \.self) { index in
                    let marker = visibleMarkers[index]
                    let placement = placements[index]
                    if isVisible(projection.point(for: marker.position), in: geometry.size) {
                        Image(systemName: marker.symbol).font(.system(size: 18)).foregroundStyle(marker.color)
                            .frame(width: 20, height: 20).background(.white, in: Circle())
                            .position(placement.symbolCenter)
                        Text(marker.title).font(.system(size: 11, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .frame(width: placement.labelRect.width - 12, height: placement.labelRect.height - 8)
                            .padding(.horizontal, 6).padding(.vertical, 4)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
                            .position(x: placement.labelRect.midX, y: placement.labelRect.midY)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(DragGesture().onChanged { value in
                camera.move(by: CGSize(width: value.translation.width - dragTranslation.width,
                                       height: value.translation.height - dragTranslation.height))
                dragTranslation = value.translation
            }.onEnded { _ in dragTranslation = .zero })
            .background(ScrollWheelReader { delta, location in
                camera.zoom(by: exp(delta * 0.08), anchoredAt: location, in: geometry.size)
            })
            .clipped()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Planned and flown flight chart")
            .accessibilityValue("\(flown.count) recorded samples, \(planned.count) planned points. \(firstAndLastLabel) Zoom \(String(format: "%.1f", camera.zoom)) times fit.")
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 8) {
                    Button { zoom(by: 0.5, in: geometry.size) } label: { Image(systemName: "minus.magnifyingglass") }
                        .accessibilityLabel("Zoom out").disabled(camera.zoom <= 0.5)
                    Button { zoom(by: 2, in: geometry.size) } label: { Image(systemName: "plus.magnifyingglass") }
                        .accessibilityLabel("Zoom in").disabled(camera.zoom >= 16)
                    Button("Fit Flight") { camera.fitFlight(); dragTranslation = .zero }
                }
                .buttonStyle(.bordered).padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(.top, 40).padding(.trailing, 16)
            }
            .onChange(of: geometry.size) { _, _ in camera.fitFlight(); dragTranslation = .zero }
        }
        .overlay(alignment: .bottomLeading) {
            HStack(spacing: 16) {
                if !completion.mission.plannedPoints.isEmpty { legend("Planned", color: .orange, dashed: true) }
                legend("Flown", color: flownColor, dashed: false)
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

    private struct Marker {
        let title: String
        let symbol: String
        let color: Color
        let position: CGPoint
    }

    private var markers: [Marker] {
        let first = completion.recording.first!.aircraftState.normalizedPosition
        let last = completion.aircraftState.normalizedPosition
        var result: [Marker] = []
        if first == last {
            result.append(Marker(title: "Start / Finish", symbol: "flag.checkered.circle.fill", color: flownColor, position: last))
        } else {
            result.append(Marker(title: "Start", symbol: "circle.fill", color: .green, position: first))
            result.append(Marker(title: "Finish", symbol: "flag.checkered.circle.fill", color: flownColor, position: last))
        }
        if let arrival = completion.mission.arrivalReference {
            result.append(Marker(title: arrival.name, symbol: "mappin.circle.fill", color: .orange, position: arrival.normalizedPosition))
        }
        return result
    }

    private func labelSize(for title: String) -> CGSize {
        let font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        let width = min(168, ceil((title as NSString).size(withAttributes: [.font: font]).width))
        let rect = (title as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                                  options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                  attributes: [.font: font])
        return CGSize(width: width + 12, height: ceil(rect.height) + 8)
    }

    private func isVisible(_ point: CGPoint, in size: CGSize) -> Bool {
        CGRect(origin: .zero, size: size).contains(point)
    }

    private func zoom(by factor: CGFloat, in size: CGSize) {
        camera.zoom(by: factor, anchoredAt: CGPoint(x: size.width / 2, y: size.height / 2), in: size)
    }

    private func legend(_ title: String, color: Color, dashed: Bool) -> some View {
        HStack(spacing: 6) {
            Path { path in path.move(to: .zero); path.addLine(to: CGPoint(x: 30, y: 0)) }
                .stroke(color, style: dashed ? plannedStroke : StrokeStyle(lineWidth: 3))
                .frame(width: 30, height: 1)
            Text(title)
        }
    }
}
