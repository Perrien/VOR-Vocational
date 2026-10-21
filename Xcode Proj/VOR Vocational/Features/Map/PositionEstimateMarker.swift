import SwiftUI

/// Screen-point geometry; transparent interiors and thin strokes never reduce the hit target.
nonisolated struct PositionEstimateMarkerGeometry {
    enum Role: Equatable { case estimate, actual }
    let role: Role
    let showsArrow: Bool

    var radius: CGFloat { role == .actual ? 18 : 14 }
    var arrowTip: CGFloat { role == .actual ? 40 : 34 }
    var hitRadius: CGFloat { (showsArrow ? arrowTip : radius) + 12 }

    func contains(_ offset: CGPoint) -> Bool {
        hypot(offset.x, offset.y) <= hitRadius
    }

    func arrowPoints(heading: Double) -> [CGPoint] {
        guard showsArrow else { return [] }
        let angle = heading * .pi / 180
        func rotated(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * cos(angle) - y * sin(angle), y: x * sin(angle) + y * cos(angle))
        }
        return [rotated(0, -radius), rotated(0, -arrowTip),
                rotated(-4, -arrowTip + 8), rotated(4, -arrowTip + 8)]
    }
}

struct PositionEstimateMarker: View {
    var heading: Double? = nil
    var role: PositionEstimateMarkerGeometry.Role = .estimate
    var dashed = false

    private var geometry: PositionEstimateMarkerGeometry {
        .init(role: role, showsArrow: heading != nil)
    }

    static let estimateColor = Color(red: 0.85, green: 0.22, blue: 0.04)
    static let actualColor = Color(red: 0.04, green: 0.22, blue: 0.62)

    private var color: Color { role == .actual ? Self.actualColor : Self.estimateColor }

    var body: some View {
        let g = geometry
        let center = CGPoint(x: g.hitRadius, y: g.hitRadius)
        let path = markerPath(center: center)
        ZStack {
            Color.clear
            path.stroke(.white.opacity(0.95), style: stroke(width: 5))
            path.stroke(color, style: stroke(width: 2))
            Circle().fill(color)
                .frame(width: role == .actual ? 6 : 4, height: role == .actual ? 6 : 4)
        }
        .frame(width: 2 * g.hitRadius, height: 2 * g.hitRadius)
        .contentShape(Circle())
        .accessibilityLabel(role == .actual ? "Actual position and heading" : "Estimated position")
    }

    private func stroke(width: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round, dash: dashed ? [4, 3] : [])
    }

    private func markerPath(center: CGPoint) -> Path {
        let g = geometry
        var path = Path(ellipseIn: CGRect(x: center.x - g.radius, y: center.y - g.radius,
                                          width: g.radius * 2, height: g.radius * 2))
        for index in 0..<4 {
            let angle = Double(index) * .pi / 2
            path.move(to: CGPoint(x: center.x + cos(angle) * g.radius,
                                  y: center.y + sin(angle) * g.radius))
            path.addLine(to: CGPoint(x: center.x + cos(angle) * (g.radius - 5),
                                     y: center.y + sin(angle) * (g.radius - 5)))
        }
        if let heading {
            let points = g.arrowPoints(heading: heading).map { CGPoint(x: $0.x + center.x, y: $0.y + center.y) }
            path.move(to: points[0])
            path.addLine(to: points[1])
            path.move(to: points[2])
            path.addLine(to: points[1])
            path.addLine(to: points[3])
        }
        return path
    }
}

/// Used by the moving preview and later exercise. The stationary marker shares the same
/// view/hit geometry through MapView's built-in position binding.
struct DraggablePositionEstimateMarker: View {
    @Binding var position: CGPoint
    let heading: Double?
    let viewport: ChartViewport
    @State private var dragStart: CGPoint?

    var body: some View {
        PositionEstimateMarker(heading: heading)
            .position(viewport.point(for: position))
            .highPriorityGesture(
                DragGesture(coordinateSpace: .named(ChartViewport.coordinateSpace))
                    .onChanged { value in
                        if dragStart == nil { dragStart = position }
                        position = viewport.moving(dragStart ?? position, by: value.translation)
                    }
                    .onEnded { _ in dragStart = nil }
            )
    }
}
