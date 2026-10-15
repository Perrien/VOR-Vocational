import Foundation
import SwiftUI

/// Briefing-local draft. Invalid text is retained until the player corrects it.
nonisolated struct MissionWindSetup: Equatable {
    enum Mode: String, CaseIterable { case calm = "Calm", steady = "Steady wind" }
    private(set) var mode: Mode = .calm
    private(set) var hasPopulatedSteadyWind = false
    var directionText = ""
    var speedText = ""

    var direction: Int? { wholeNumber(directionText, in: 0...359) }
    var speed: Int? { wholeNumber(speedText, in: 0...40) }

    var conditions: FlightConditions? {
        guard mode == .steady else { return .calm }
        guard let direction, let speed,
              let wind = SteadyWind(fromDegrees: direction, speedKnots: speed) else { return nil }
        return .steady(wind)
    }

    mutating func select(_ mode: Mode) {
        var generator = SystemRandomNumberGenerator()
        select(mode, using: &generator)
    }

    mutating func select<R: RandomNumberGenerator>(_ mode: Mode, using generator: inout R) {
        self.mode = mode
        if mode == .steady && !hasPopulatedSteadyWind { randomize(using: &generator) }
    }

    mutating func randomize() {
        var generator = SystemRandomNumberGenerator()
        randomize(using: &generator)
    }

    mutating func randomize<R: RandomNumberGenerator>(using generator: inout R) {
        directionText = String(format: "%03d", Int.random(in: 0...359, using: &generator))
        speedText = String(Int.random(in: 5...25, using: &generator))
        hasPopulatedSteadyWind = true
    }

    mutating func formatValidEntries() {
        if let direction { directionText = String(format: "%03d", direction) }
        if let speed { speedText = String(speed) }
    }

    private func wholeNumber(_ text: String, in range: ClosedRange<Int>) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.allSatisfy({ $0 >= "0" && $0 <= "9" }),
              let value = Int(trimmed), range.contains(value) else { return nil }
        return value
    }
}

struct MissionWindSetupView: View {
    @Binding var setup: MissionWindSetup
    @FocusState private var focusedField: Field?
    private enum Field { case direction, speed }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Flight conditions").font(.headline)
            Picker("Wind", selection: Binding(get: { setup.mode }, set: { setup.select($0) })) {
                ForEach(MissionWindSetup.Mode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if setup.mode == .steady {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Wind from (°)").font(.caption)
                        TextField("000–359", text: $setup.directionText)
                            .accessibilityLabel("Wind from")
                            .focused($focusedField, equals: .direction)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Speed (kt)").font(.caption)
                        TextField("0–40", text: $setup.speedText)
                            .accessibilityLabel("Wind speed in knots")
                            .focused($focusedField, equals: .speed)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .monospacedDigit()
                if setup.direction == nil {
                    Text("Enter whole degrees from 000–359°.").font(.caption).foregroundStyle(.red)
                }
                if setup.speed == nil {
                    Text("Enter whole knots from 0–40 kt.").font(.caption).foregroundStyle(.red)
                }
                Button("Randomize") { setup.randomize() }
                    .buttonStyle(.bordered)
                Text("Wind stays fixed throughout the flight.")
                    .font(.caption).foregroundStyle(ControlPalette.secondaryText)
            }
        }
        .onSubmit { setup.formatValidEntries() }
        .onChange(of: focusedField) { old, _ in
            if old != nil { setup.formatValidEntries() }
        }
    }
}
