import SwiftUI

/// Label placement can move annotations, but never either geographic symbol.
nonisolated enum PracticeComparisonLabelLayout {
    static func rectangles(estimate: CGPoint, actual: CGPoint, size: CGSize) -> [CGRect] {
        let bounds = CGRect(x: 8, y: 88, width: max(1, size.width - 16), height: max(1, size.height - 96))
        let labelSize = CGSize(width: 76, height: 26)
        let symbols = [estimate, actual].map { CGRect(x: $0.x - 44, y: $0.y - 44, width: 88, height: 88) }
        var occupied = symbols
        return [estimate, actual].enumerated().map { index, point in
            let above = CGPoint(x: point.x - labelSize.width / 2, y: point.y - 72)
            let below = CGPoint(x: point.x - labelSize.width / 2, y: point.y + 46)
            let origins = (index == 0 ? [above, below] : [below, above]) + [
                CGPoint(x: point.x - 124, y: point.y - 13),
                CGPoint(x: point.x + 48, y: point.y - 13),
                CGPoint(x: point.x - 124, y: point.y - 72),
                CGPoint(x: point.x + 48, y: point.y + 46)
            ]
            let candidates = origins.map { origin in
                CGRect(x: min(max(bounds.minX, origin.x), max(bounds.minX, bounds.maxX - labelSize.width)),
                       y: min(max(bounds.minY, origin.y), max(bounds.minY, bounds.maxY - labelSize.height)),
                       width: labelSize.width, height: labelSize.height)
            }
            func overlap(_ rect: CGRect) -> CGFloat {
                occupied.reduce(0) { sum, other in
                    let intersection = rect.insetBy(dx: -3, dy: -3).intersection(other)
                    return sum + (intersection.isNull ? 0 : intersection.width * intersection.height)
                }
            }
            // Retain candidate order when equally good, keeping coincident labels on opposite sides.
            let selected = candidates.dropFirst().reduce(candidates[0]) { best, next in
                overlap(next) < overlap(best) ? next : best
            }
            occupied.append(selected)
            return selected
        }
    }
}

/// Pure presentation of frozen values. The caller owns attempt state and fitting.
struct PracticeComparisonView: View {
    let estimatePosition: CGPoint
    let estimatedHeading: Double
    let actualPosition: CGPoint
    let actualHeading: Double
    let viewport: ChartViewport

    var body: some View {
        let estimate = viewport.point(for: estimatePosition)
        let actual = viewport.point(for: actualPosition)
        let labels = PracticeComparisonLabelLayout.rectangles(estimate: estimate, actual: actual, size: viewport.size)
        ZStack {
            Path { path in
                path.move(to: estimate)
                path.addLine(to: actual)
            }
            .stroke(.white.opacity(0.9), lineWidth: 4)
            Path { path in
                path.move(to: estimate)
                path.addLine(to: actual)
            }
            .stroke(.primary.opacity(0.65), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

            leader(from: estimate, to: labels[0], color: PositionEstimateMarker.estimateColor)
            leader(from: actual, to: labels[1], color: PositionEstimateMarker.actualColor)

            PositionEstimateMarker(heading: actualHeading, role: .actual).position(actual)
            PositionEstimateMarker(heading: estimatedHeading, dashed: true).position(estimate)
            label("Estimate", in: labels[0], color: PositionEstimateMarker.estimateColor)
            label("Actual", in: labels[1], color: PositionEstimateMarker.actualColor)
        }
        .frame(width: viewport.size.width, height: viewport.size.height)
        .allowsHitTesting(false)
    }

    private func leader(from point: CGPoint, to rect: CGRect, color: Color) -> some View {
        Path { path in
            path.move(to: point)
            path.addLine(to: CGPoint(x: min(max(point.x, rect.minX), rect.maxX),
                                     y: min(max(point.y, rect.minY), rect.maxY)))
        }
        .stroke(color.opacity(0.8), lineWidth: 1)
    }

    private func label(_ text: String, in rect: CGRect, color: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: rect.width, height: rect.height)
            .background(.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(color, lineWidth: 1))
            .position(x: rect.midX, y: rect.midY)
    }
}

struct PracticeComparisonControls: View {
    let onZoomOut: () -> Void
    let onZoomIn: () -> Void
    let onFit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onZoomOut) { Image(systemName: "minus.magnifyingglass") }
                .help("Zoom out around the chart center")
            Button(action: onZoomIn) { Image(systemName: "plus.magnifyingglass") }
                .help("Zoom in around the chart center")
            Button("Fit Comparison", action: onFit)
        }
        .buttonStyle(.bordered)
    }
}
