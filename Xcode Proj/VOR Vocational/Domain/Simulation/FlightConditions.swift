import CoreGraphics
import Foundation

nonisolated struct SteadyWind: Equatable {
    let fromDegrees: Int
    let speedKnots: Int

    init?(fromDegrees: Int, speedKnots: Int) {
        guard (0...359).contains(fromDegrees), (0...40).contains(speedKnots) else { return nil }
        self.fromDegrees = fromDegrees
        self.speedKnots = speedKnots
    }
}

/// Locked at launch. A steady zero-knot selection retains its chosen mode.
nonisolated enum FlightConditions: Equatable {
    case calm
    case steady(SteadyWind)

    var label: String {
        switch self {
        case .calm: return "Calm"
        case .steady(let wind):
            return String(format: "Wind from %03d° at %d kt", wind.fromDegrees, wind.speedKnots)
        }
    }

    /// East-positive, south-positive velocity in NM per simulated second.
    var windVelocity: CGPoint {
        guard case .steady(let wind) = self else { return .zero }
        let radians = Double(wind.fromDegrees) * .pi / 180
        let speed = Double(wind.speedKnots) / 3_600
        return CGPoint(x: -sin(radians) * speed, y: cos(radians) * speed)
    }
}
