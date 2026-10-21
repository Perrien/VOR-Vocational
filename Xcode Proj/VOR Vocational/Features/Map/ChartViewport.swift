import CoreGraphics
import Foundation

/// Presentation only: coordinates always refer to the unchanged full source chart.
nonisolated struct ChartCameraPolicy: Equatable {
    let crop: CGRect
    let zoomRange: ClosedRange<CGFloat>
    let panPadding: CGFloat

    static let standard = Self(crop: FlatMap.sourceCrop, zoomRange: 1...6, panPadding: 0)
    static let fullChart = Self(crop: CGRect(x: 0, y: 0, width: 1, height: 1),
                               zoomRange: 1...6, panPadding: 0)
    static let comparison = Self(crop: fullChart.crop, zoomRange: 0.25...16_384, panPadding: 160)

    func clampedPan(_ proposed: CGSize, zoom: CGFloat, size: CGSize) -> CGSize {
        let xLimit = max(0, size.width * (zoom - 1) / 2) + panPadding
        let yLimit = max(0, size.height * (zoom - 1) / 2) + panPadding
        return CGSize(width: min(max(proposed.width, -xLimit), xLimit),
                      height: min(max(proposed.height, -yLimit), yLimit))
    }
}

nonisolated struct ChartFitRequest: Equatable {
    let positions: [CGPoint]
    var revision = 0
    var minimumSpanNM: CGFloat = 0.05
    var padding: CGFloat = 80
    var topClearance: CGFloat = 80

    func centerBounds(in size: CGSize) -> CGRect {
        CGRect(x: padding, y: topClearance + padding,
               width: max(1, size.width - 2 * padding),
               height: max(1, size.height - topClearance - 2 * padding))
    }
}

/// The single forward/inverse transform used by chart symbols, dragging and fitting.
nonisolated struct ChartViewport {
    struct Camera: Equatable {
        var zoom: CGFloat = 1
        var pan: CGSize = .zero
    }

    static let coordinateSpace = "mapArea"
    let size: CGSize
    let crop: CGRect
    let camera: Camera
    let imageRect: CGRect

    init(size: CGSize, crop: CGRect = FlatMap.sourceCrop, zoom: CGFloat = 1, pan: CGSize = .zero) {
        self.size = size
        self.crop = crop
        camera = Camera(zoom: zoom, pan: pan)
        imageRect = FlatMap.fittedRect(in: size, crop: crop)
    }

    var pointsPerNM: CGFloat {
        FlatMap.pixelsPerNM(in: imageRect, mapWidthNM: FlightWorld.widthNM, crop: crop) * camera.zoom
    }

    func screenPoint(forMapPoint point: CGPoint) -> CGPoint {
        CGPoint(x: (point.x - size.width / 2) * camera.zoom + size.width / 2 + camera.pan.width,
                y: (point.y - size.height / 2) * camera.zoom + size.height / 2 + camera.pan.height)
    }

    func point(for position: CGPoint) -> CGPoint {
        screenPoint(forMapPoint: FlatMap.point(for: position, in: imageRect, crop: crop))
    }

    func position(at point: CGPoint) -> CGPoint? {
        guard camera.zoom > 0 else { return nil }
        let mapPoint = CGPoint(x: (point.x - size.width / 2 - camera.pan.width) / camera.zoom + size.width / 2,
                               y: (point.y - size.height / 2 - camera.pan.height) / camera.zoom + size.height / 2)
        return FlatMap.sourcePosition(for: mapPoint, in: imageRect, crop: crop)
    }

    /// Translation preserves the pointer's grab offset, including on the arrow/buffer.
    func moving(_ position: CGPoint, by translation: CGSize) -> CGPoint {
        guard imageRect.width > 0, imageRect.height > 0, camera.zoom > 0 else { return position }
        return CGPoint(x: min(crop.maxX, max(crop.minX,
                            position.x + translation.width * crop.width / (imageRect.width * camera.zoom))),
                       y: min(crop.maxY, max(crop.minY,
                            position.y + translation.height * crop.height / (imageRect.height * camera.zoom))))
    }

    func zoomed(by factor: CGFloat, anchoredAt anchor: CGPoint, policy: ChartCameraPolicy) -> Camera {
        guard factor.isFinite, factor > 0, camera.zoom > 0 else { return camera }
        let zoom = min(policy.zoomRange.upperBound, max(policy.zoomRange.lowerBound, camera.zoom * factor))
        let ratio = zoom / camera.zoom
        let pan = CGSize(width: camera.pan.width * ratio + (anchor.x - size.width / 2) * (1 - ratio),
                         height: camera.pan.height * ratio + (anchor.y - size.height / 2) * (1 - ratio))
        return Camera(zoom: zoom, pan: policy.clampedPan(pan, zoom: zoom, size: size))
    }

    func fitting(_ request: ChartFitRequest, policy: ChartCameraPolicy) -> Camera? {
        guard !request.positions.isEmpty, size.width > 0, size.height > 0,
              request.minimumSpanNM.isFinite, request.minimumSpanNM > 0,
              request.positions.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return nil }
        let points = request.positions.map { FlatMap.point(for: $0, in: imageRect, crop: crop) }
        let minX = points.map(\.x).min()!, maxX = points.map(\.x).max()!
        let minY = points.map(\.y).min()!, maxY = points.map(\.y).max()!
        let bounds = request.centerBounds(in: size)
        let minimumSpan = request.minimumSpanNM
            * FlatMap.pixelsPerNM(in: imageRect, mapWidthNM: FlightWorld.widthNM, crop: crop)
        let fittedZoom = min(bounds.width / max(minimumSpan, maxX - minX),
                             bounds.height / max(minimumSpan, maxY - minY))
        let zoom = min(policy.zoomRange.upperBound, max(policy.zoomRange.lowerBound, fittedZoom))
        let pan = CGSize(width: bounds.midX - size.width / 2 - ((minX + maxX) / 2 - size.width / 2) * zoom,
                         height: bounds.midY - size.height / 2 - ((minY + maxY) / 2 - size.height / 2) * zoom)
        return Camera(zoom: zoom, pan: policy.clampedPan(pan, zoom: zoom, size: size))
    }
}
