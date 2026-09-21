import CoreGraphics
import Foundation
import Observation

/// The frequency, selected course, and tuning behavior of one physical NAV receiver.
struct NAVReceiver: Equatable {
    var wholeMHz: Int = 108
    var fineStep: Int = 0
    var obs: Int = 0
    /// Whether this receiver currently has an active tuned frequency. A failed
    /// out-of-range ident selection clears it, so stale reception cannot keep
    /// driving the indicator.
    var hasActiveFrequency = true

    var frequencyHundredths: Int {
        wholeMHz * 100 + fineStep * 5
    }

    var frequencyLabel: String {
        guard hasActiveFrequency else { return "---.--" }
        return String(format: "%.2f", Double(frequencyHundredths) / 100)
    }

    mutating func adjustWhole(by amount: Int) {
        wholeMHz = min(max(wholeMHz + amount, 108), 117)
        hasActiveFrequency = true
    }

    mutating func adjustFine(by amount: Int) {
        fineStep = (fineStep + amount % 20 + 20) % 20
        hasActiveFrequency = true
    }

    mutating func adjustOBS(by amount: Int) {
        obs = (obs + amount % 360 + 360) % 360
    }

    /// Sets the channel directly from a known station's frequency (e.g. a
    /// resolved ident lookup), bypassing the whole/fine knob adjustments.
    mutating func tune(toFrequencyHundredths frequencyHundredths: Int) {
        wholeMHz = frequencyHundredths / 100
        fineStep = (frequencyHundredths % 100) / 5
        hasActiveFrequency = true
    }

    /// Clears the displayed and active frequency without replacing it with a
    /// made-up channel. The last physical knob position is retained so a
    /// subsequent adjustment can retune the receiver.
    mutating func clearFrequency() {
        hasActiveFrequency = false
    }
}

/// Per-flight state shared by the reusable flight surface and its cockpit.
@Observable
final class FlightSession {
    var normalizedAircraftPosition: CGPoint
    /// The aircraft's current, physical direction of travel.
    var heading: Double = 0
    /// The heading selected with the heading knob. The aircraft turns toward
    /// this target at the simulation's bounded turn rate.
    var selectedHeading: Double = 0
    var speedKnots: Double = 260
    var isFlying = false
    var timeMultiplier: Double = 1
    /// Elapsed simulation time, including the selected playback multiplier.
    /// A mission completion records this value; it is not a score or ETA.
    var elapsedSimulatedSeconds: TimeInterval = 0
    var nav1 = NAVReceiver()
    var nav2 = NAVReceiver()

    var zoom: CGFloat = 1
    var pan: CGSize = .zero
    var showVORs = true
    var visibleVORServiceVolumes = Set(VORServiceVolume.allCases)
    var showAirports = true
    var showRadials = true
    var showGrid = false
    var showSightseeingRegions = false
    var showSightseeingRegionNames = true
    var gridSizeNM: Double = 50
    var selectedVORID: String?
    var cdiMax: Double = 10

    init(normalizedAirportPosition: CGPoint) {
        normalizedAircraftPosition = normalizedAirportPosition
    }

    func swapNAVReceivers() {
        swap(&nav1, &nav2)
    }
}

/// A Debug-only scene registry for the currently visible live-flight session.
@Observable
final class FlightDiagnosticsStore {
    var activeSession: FlightSession?
}
