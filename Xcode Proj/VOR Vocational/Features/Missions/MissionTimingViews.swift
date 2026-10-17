import Foundation
import SwiftUI

/// Shared formatting for simulated durations and elapsed flight-time estimates.
nonisolated enum MissionTimingFormat {
    static func duration(_ seconds: TimeInterval,
                         rounding: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "Timing unavailable" }
        let wholeSeconds = seconds.rounded(rounding)
        // Keep these as Doubles so even a large finite schedule cannot trap in
        // an Int conversion. Presentation rounding never changes planning data.
        let hours = (wholeSeconds / 3_600).rounded(.down)
        let minutes = (wholeSeconds / 60).rounded(.down).truncatingRemainder(dividingBy: 60)
        let remainder = wholeSeconds.truncatingRemainder(dividingBy: 60)
        if hours >= 1 {
            return String(format: "%.0f:%02.0f:%02.0f", hours, minutes, remainder)
        }
        return String(format: "%.0f:%02.0f", minutes, remainder)
    }
}

/// Read-only original schedule, suitable for both briefing and live reference.
/// Its rows follow geometric leg order independently of NAV instructions.
struct MissionTimingScheduleView: View {
    let schedule: MissionTimingSchedule

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch schedule.availability {
            case .available(let legs):
                Text("Still-air schedule at \(schedule.planningAirspeedKnots.formatted()) kt")
                    .font(.headline)
                Text("Planned reach is elapsed flight time from start. Wind is not included.")
                    .font(.caption)
                    .foregroundStyle(ControlPalette.secondaryText)
                ForEach(legs) { leg in
                    scheduleRow(leg)
                }
            case .unavailable(let issue):
                Label("Timing unavailable", systemImage: "clock.badge.exclamationmark")
                    .font(.headline)
                Text(issue.reason)
                    .font(.caption)
                    .foregroundStyle(ControlPalette.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(ControlPalette.primaryText)
    }

    private func scheduleRow(_ leg: MissionTimingSchedule.Leg) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Leg \(leg.number) · \(leg.startLabel) → \(leg.endLabel)")
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text(String(format: "%.1f NM", leg.distanceNM))
                Spacer(minLength: 8)
                Text("Duration \(MissionTimingFormat.duration(leg.plannedDurationSeconds))")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(ControlPalette.secondaryText)
            Text("Planned reach \(MissionTimingFormat.duration(leg.plannedReachSeconds)) flight time")
                .font(.caption.monospacedDigit())
                .foregroundStyle(ControlPalette.secondaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}

#Preview("120 kt — 20 NM and 4 NM") {
    ScrollView {
        MissionTimingScheduleView(schedule: MissionTimingSchedule(legs: [
            .init(startLabel: "Departure", endLabel: "First fix", distanceNM: 20),
            .init(startLabel: "First fix", endLabel: "Destination", distanceNM: 4)
        ], planningAirspeedKnots: 120))
        .padding(24)
    }
    .frame(width: 374, height: 600)
}

#Preview("Repeated long labels — 120 kt") {
    ScrollView {
        MissionTimingScheduleView(schedule: MissionTimingSchedule(legs: [
            .init(startLabel: "Northern training departure airport",
                  endLabel: "Repeated long radial intersection reference", distanceNM: 20),
            .init(startLabel: "Repeated long radial intersection reference",
                  endLabel: "Northern training departure airport", distanceNM: 4),
            .init(startLabel: "Northern training departure airport",
                  endLabel: "Repeated long radial intersection reference", distanceNM: 20)
        ], planningAirspeedKnots: 120))
        .padding(24)
    }
    .frame(width: 340, height: 600)
}

#Preview("Invalid timing — flight remains available") {
    MissionTimingScheduleView(schedule: MissionTimingSchedule(legs: [
        .init(startLabel: "Departure", endLabel: "Destination", distanceNM: .nan)
    ], planningAirspeedKnots: 120))
    .padding(24)
    .frame(width: 340)
}
