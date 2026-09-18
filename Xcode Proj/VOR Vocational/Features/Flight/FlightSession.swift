import CoreGraphics
import Foundation
import Observation

/// The frequency, selected course, and tuning behavior of one physical NAV receiver.
struct NAVReceiver: Equatable {
    var wholeMHz: Int = 108
    var fineStep: Int = 0
    var obs: Int = 0

    var frequencyHundredths: Int {
        wholeMHz * 100 + fineStep * 5
    }

    var frequencyLabel: String {
        String(format: "%.2f", Double(frequencyHundredths) / 100)
    }

    mutating func adjustWhole(by amount: Int) {
        wholeMHz = min(max(wholeMHz + amount, 108), 117)
    }

    mutating func adjustFine(by amount: Int) {
        fineStep = (fineStep + amount % 20 + 20) % 20
    }

    mutating func adjustOBS(by amount: Int) {
        obs = (obs + amount % 360 + 360) % 360
    }

    /// Sets the channel directly from a known station's frequency (e.g. a
    /// resolved ident lookup), bypassing the whole/fine knob adjustments.
    mutating func tune(toFrequencyHundredths frequencyHundredths: Int) {
        wholeMHz = frequencyHundredths / 100
        fineStep = (frequencyHundredths % 100) / 5
    }
}

/// Per-flight state shared by the reusable flight surface and its cockpit.
@Observable
final class FlightSession {
    var normalizedAircraftPosition: CGPoint
    var heading: Double = 0
    var speedKnots: Double = 260
    var isFlying = false
    var timeMultiplier: Double = 1
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

/// A Debug-only scene registry for the currently visible Free Flight session.
@Observable
final class FlightDiagnosticsStore {
    var activeSession: FlightSession?
}
