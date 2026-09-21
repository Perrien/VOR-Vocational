import Foundation

/// The presentation and interaction policy a mode supplies to the reusable
/// flight surface. It deliberately describes the surface rather than mutable
/// per-flight state, so `MapView` does not need to know which mode owns it.
struct FlightSurfaceConfiguration: Equatable {
    /// The airport-layer preference applied when this surface first appears.
    /// Players may still change it through the normal Chart controls.
    let showsAirportsByDefault: Bool
    let allowsAircraftSimulation: Bool
    let showsHeadingPresentation: Bool
    let showsFlightControls: Bool

    /// The unconstrained baseline used by Free Flight.
    static let freeFlight = FlightSurfaceConfiguration(
        showsAirportsByDefault: true,
        allowsAircraftSimulation: true,
        showsHeadingPresentation: true,
        showsFlightControls: true
    )

    /// Position Challenge uses the plane icon as a stationary guess marker.
    /// Airports begin hidden but remain an ordinary optional chart layer.
    static let positionChallenge = FlightSurfaceConfiguration(
        showsAirportsByDefault: false,
        allowsAircraftSimulation: false,
        showsHeadingPresentation: true,
        showsFlightControls: false
    )
}
