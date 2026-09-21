import Foundation

/// The presentation and interaction policy a mode supplies to the reusable
/// flight surface. It deliberately describes the surface rather than mutable
/// per-flight state, so `MapView` does not need to know which mode owns it.
struct FlightSurfaceConfiguration: Equatable {
    /// The chart-layer preferences applied when this surface first appears.
    /// Players may still change them through the normal Chart controls.
    let showsAirportsByDefault: Bool
    let showsSightseeingRegionNamesByDefault: Bool
    let allowsAircraftSimulation: Bool
    let showsHeadingPresentation: Bool
    let showsFlightControls: Bool
    /// When false, the surface does not reveal or allow dragging the aircraft's
    /// exact chart position. Radios and simulation continue using that position.
    let showsAircraftMarker: Bool

    /// The unconstrained baseline used by Free Flight.
    static let freeFlight = FlightSurfaceConfiguration(
        showsAirportsByDefault: true,
        showsSightseeingRegionNamesByDefault: false,
        allowsAircraftSimulation: true,
        showsHeadingPresentation: true,
        showsFlightControls: true,
        showsAircraftMarker: true
    )

    /// Position Challenge uses the plane icon as a stationary guess marker.
    /// Airports and sightseeing names begin hidden but remain ordinary
    /// optional chart layers.
    static let positionChallenge = FlightSurfaceConfiguration(
        showsAirportsByDefault: false,
        showsSightseeingRegionNamesByDefault: false,
        allowsAircraftSimulation: false,
        showsHeadingPresentation: true,
        showsFlightControls: false,
        showsAircraftMarker: true
    )

    /// The first supplied mission uses the normal live cockpit while keeping
    /// the aircraft's true chart location hidden from the player.
    static let transportMission = FlightSurfaceConfiguration(
        showsAirportsByDefault: true,
        showsSightseeingRegionNamesByDefault: false,
        allowsAircraftSimulation: true,
        showsHeadingPresentation: true,
        showsFlightControls: true,
        showsAircraftMarker: false
    )
}
