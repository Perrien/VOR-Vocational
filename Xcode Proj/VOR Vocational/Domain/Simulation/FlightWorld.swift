import CoreGraphics

/// Physical calibration of the full Myosia source chart, independent of its viewport.
nonisolated enum FlightWorld {
    static let sourceAspect = 1748.0 / 1254.0
    static let widthNM = 500.0
    static let heightNM = widthNM / sourceAspect

    static func nauticalMiles(for position: CGPoint) -> CGPoint {
        CGPoint(x: position.x * widthNM, y: position.y * heightNM)
    }

    static func normalizedPosition(for nauticalMiles: CGPoint) -> CGPoint {
        CGPoint(x: nauticalMiles.x / widthNM, y: nauticalMiles.y / heightNM)
    }
}

/// Aircraft truth at one instant. Heading is the nose direction, not ground track.
nonisolated struct FlightAircraftState: Equatable {
    let normalizedPosition: CGPoint
    let heading: Double
    let speedKnots: Double

    init(normalizedPosition: CGPoint, heading: Double = 0, speedKnots: Double = 260) {
        precondition(normalizedPosition.x.isFinite && normalizedPosition.y.isFinite)
        precondition(heading.isFinite && speedKnots.isFinite && speedKnots >= 0)
        self.normalizedPosition = normalizedPosition
        self.heading = FlightPhysics.normalizedHeading(heading)
        self.speedKnots = speedKnots
    }
}
