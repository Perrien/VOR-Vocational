import CoreGraphics
import Foundation

/// A physical projection of the full source chart, independent of the live crop.
nonisolated struct MissionChartProjection {
    let size: CGSize
    let centerNM: CGPoint
    let pointsPerNM: CGFloat
    private let screenCenter: CGPoint

    init(positions: [CGPoint], size: CGSize, padding: CGFloat = 64, fitRect: CGRect? = nil) {
        let points = positions.map { FlightWorld.nauticalMiles(for: $0) }
        let minX = points.map(\.x).min() ?? 0
        let maxX = points.map(\.x).max() ?? 0
        let minY = points.map(\.y).min() ?? 0
        let maxY = points.map(\.y).max() ?? 0
        let rect = fitRect ?? CGRect(origin: .zero, size: size).insetBy(dx: padding, dy: padding)
        self.size = size
        centerNM = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        screenCenter = CGPoint(x: rect.midX, y: rect.midY)
        // A stationary flight still has a useful, finite neighbourhood to inspect.
        pointsPerNM = min(max(1, rect.width) / max(10, maxX - minX),
                          max(1, rect.height) / max(10, maxY - minY))
    }

    private init(size: CGSize, centerNM: CGPoint, screenCenter: CGPoint, pointsPerNM: CGFloat) {
        self.size = size
        self.centerNM = centerNM
        self.screenCenter = screenCenter
        self.pointsPerNM = pointsPerNM
    }

    func point(for position: CGPoint) -> CGPoint {
        let nm = FlightWorld.nauticalMiles(for: position)
        return CGPoint(x: screenCenter.x + (nm.x - centerNM.x) * pointsPerNM,
                       y: screenCenter.y + (nm.y - centerNM.y) * pointsPerNM)
    }

    func position(at point: CGPoint) -> CGPoint {
        FlightWorld.normalizedPosition(for: CGPoint(
            x: centerNM.x + (point.x - screenCenter.x) / pointsPerNM,
            y: centerNM.y + (point.y - screenCenter.y) / pointsPerNM))
    }

    func applying(_ camera: MissionDebriefCamera) -> Self {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        return Self(size: size, centerNM: centerNM,
                    screenCenter: CGPoint(x: center.x + (screenCenter.x - center.x) * camera.zoom + camera.pan.width,
                                          y: center.y + (screenCenter.y - center.y) * camera.zoom + camera.pan.height),
                    pointsPerNM: pointsPerNM * camera.zoom)
    }

    var sourceImageRect: CGRect {
        CGRect(origin: point(for: .zero),
               size: CGSize(width: FlightWorld.widthNM * pointsPerNM,
                            height: FlightWorld.heightNM * pointsPerNM))
    }
}

/// Screen-local inspection state. It never holds or modifies flight data.
nonisolated struct MissionDebriefCamera: Equatable {
    private(set) var zoom: CGFloat = 1
    private(set) var pan: CGSize = .zero

    mutating func fitFlight() { self = Self() }

    mutating func move(by translation: CGSize) {
        pan.width += translation.width
        pan.height += translation.height
    }

    mutating func zoom(by factor: CGFloat, anchoredAt location: CGPoint, in size: CGSize) {
        guard factor.isFinite, factor > 0 else { return }
        let newZoom = min(16, max(0.5, zoom * factor))
        let ratio = newZoom / zoom
        pan = CGSize(width: pan.width * ratio + (location.x - size.width / 2) * (1 - ratio),
                     height: pan.height * ratio + (location.y - size.height / 2) * (1 - ratio))
        zoom = newZoom
    }
}

/// Declutters screen-sized symbols and labels without moving any route geometry.
/// A displaced symbol is connected to its exact chart anchor by a leader line.
nonisolated enum MissionDebriefMarkerLayout {
    struct Input {
        let anchor: CGPoint
        let labelSize: CGSize
    }

    struct Placement {
        let symbolCenter: CGPoint
        let labelRect: CGRect
    }

    static func place(_ markers: [Input], in bounds: CGRect, avoiding reserved: [CGRect] = []) -> [Placement] {
        func clamped(_ origin: CGPoint, size: CGSize) -> CGPoint {
            CGPoint(x: min(max(origin.x, bounds.minX), max(bounds.minX, bounds.maxX - size.width)),
                    y: min(max(origin.y, bounds.minY), max(bounds.minY, bounds.maxY - size.height)))
        }
        var centers: [CGPoint] = []
        for marker in markers {
            let offsets: [CGPoint] = [.zero, CGPoint(x: 28, y: 0), CGPoint(x: -28, y: 0),
                                      CGPoint(x: 0, y: 28), CGPoint(x: 0, y: -28), CGPoint(x: 28, y: 28)]
            let candidates = offsets.map { offset in
                let origin = clamped(CGPoint(x: marker.anchor.x + offset.x - 10,
                                             y: marker.anchor.y + offset.y - 10), size: CGSize(width: 20, height: 20))
                return CGPoint(x: origin.x + 10, y: origin.y + 10)
            }
            centers.append(candidates.first { candidate in
                centers.allSatisfy { hypot($0.x - candidate.x, $0.y - candidate.y) >= 24 }
            } ?? candidates[0])
        }
        let symbols = centers.map { CGRect(x: $0.x - 12, y: $0.y - 12, width: 24, height: 24) }
        var occupied = reserved + symbols
        return zip(markers, centers).map { marker, center in
            let size = marker.labelSize
            var origins = [CGPoint(x: center.x - size.width / 2, y: center.y + 16),
                           CGPoint(x: center.x - size.width / 2, y: center.y - 16 - size.height),
                           CGPoint(x: center.x + 16, y: center.y - size.height / 2),
                           CGPoint(x: center.x - 16 - size.width, y: center.y - size.height / 2)]
            // Nearby rows handle coincident arrival/finish and tightly clustered starts.
            for row in 1...4 {
                for direction: CGFloat in [-1, 1] {
                    origins.append(CGPoint(x: center.x - size.width / 2,
                                           y: center.y + direction * CGFloat(row) * (size.height + 8)))
                }
            }
            let candidates = origins.map { CGRect(origin: clamped($0, size: size), size: size) }
            func overlap(_ rect: CGRect) -> CGFloat {
                occupied.reduce(0) { total, other in
                    let intersection = rect.insetBy(dx: -4, dy: -4).intersection(other)
                    return total + (intersection.isNull ? 0 : intersection.width * intersection.height)
                }
            }
            let rect = candidates.min { overlap($0) < overlap($1) }!
            occupied.append(rect)
            return Placement(symbolCenter: center, labelRect: rect)
        }
    }
}
