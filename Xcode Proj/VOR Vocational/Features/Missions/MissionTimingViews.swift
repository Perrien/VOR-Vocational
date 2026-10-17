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
            MissionStepTimingView(leg: leg)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
    }
}

/// Presentation joins only explicit associations. Repeated names, checkbox
/// order, or equal array counts never establish a timing relationship.
nonisolated struct MissionInstructionItem: Equatable, Identifiable {
    nonisolated enum ID: Hashable { case instruction(Int), leg(Int) }
    let id: ID
    let instructionIndex: Int?
    let timingLeg: MissionTimingSchedule.Leg?

    static func items(instructions: [MissionInstruction], schedule: MissionTimingSchedule?) -> [Self] {
        let legs = schedule?.legs ?? []
        var usedLegs: Set<Int> = []
        var items = instructions.enumerated().map { index, instruction in
            let leg: MissionTimingSchedule.Leg?
            if let legIndex = instruction.timingLegIndex, legs.indices.contains(legIndex),
               usedLegs.insert(legIndex).inserted {
                leg = legs[legIndex]
            } else { leg = nil }
            return Self(id: .instruction(index), instructionIndex: index, timingLeg: leg)
        }
        // Geometry without associated guidance still needs timing controls,
        // but must not invent a NAV instruction or checklist entry.
        items += legs.filter { !usedLegs.contains($0.index) }.map {
            Self(id: .leg($0.index), instructionIndex: nil, timingLeg: $0)
        }
        return items
    }
}

/// One shared list for preflight and live flight. Each card brings guidance,
/// planning values, and (in flight) its timing action/estimate together.
struct MissionInstructionListView: View {
    let instructions: [MissionInstruction]
    let schedule: MissionTimingSchedule?
    var display: MissionLegTiming.Display? = nil
    var selectedLegIndex: Int? = nil
    var actionsAreEnabled = true
    var onStartLeg: ((Int) -> Void)? = nil
    var completion: ((Int) -> Binding<Bool>)? = nil

    var body: some View {
        ForEach(MissionInstructionItem.items(instructions: instructions, schedule: schedule)) { item in
            VStack(alignment: .leading, spacing: 8) {
                if let index = item.instructionIndex {
                    let instruction = instructions[index]
                    if let completion {
                        Toggle(isOn: completion(index)) {
                            instructionTitle(instruction, number: index + 1)
                        }
                        .toggleStyle(.checkbox)
                    } else {
                        instructionTitle(instruction, number: index + 1)
                    }
                    if let guidance = instruction.guidance {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Tune \(guidance.stationIdent) \(String(format: "%.2f", guidance.frequencyMHz))")
                            Text("Set OBS \(String(format: "%03d", guidance.obsDegrees))° · Confirm \(guidance.flag.rawValue)")
                                .fontWeight(.semibold)
                        }
                        .font(.caption.monospacedDigit())
                    }
                    if let detail = instruction.detail {
                        Text(detail).font(.caption).foregroundStyle(ControlPalette.secondaryText)
                    }
                    if item.timingLeg != nil, let detail = instruction.timingDetail {
                        Text(detail).font(.caption).foregroundStyle(ControlPalette.secondaryText)
                    }
                } else if let leg = item.timingLeg {
                    Text("Leg \(leg.number) · \(leg.startLabel) → \(leg.endLabel)")
                        .font(.subheadline.weight(.semibold))
                }
                if let leg = item.timingLeg {
                    MissionStepTimingView(leg: leg, display: display,
                        isSelected: selectedLegIndex == leg.index, actionsAreEnabled: actionsAreEnabled,
                        onStartLeg: onStartLeg)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(item.timingLeg != nil && item.timingLeg?.index == display?.currentLeg?.index
                            ? ControlPalette.accent.opacity(0.6) : Color.clear, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .accessibilityElement(children: .contain)
        }
    }

    private func instructionTitle(_ instruction: MissionInstruction, number: Int) -> some View {
        Text("\(number). \(instruction.title)")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(ControlPalette.primaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct MissionStepTimingView: View {
    let leg: MissionTimingSchedule.Leg
    var display: MissionLegTiming.Display? = nil
    var isSelected = false
    var actionsAreEnabled = true
    var onStartLeg: ((Int) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(String(format: "%.1f NM", leg.distanceNM)) · Planned duration \(MissionTimingFormat.duration(leg.plannedDurationSeconds))")
            Text("Planned reach \(MissionTimingFormat.duration(leg.plannedReachSeconds)) flight time")
                .foregroundStyle(ControlPalette.secondaryText)
            if let display, display.currentLeg?.index == leg.index {
                Text(display.current.label)
                    .fontWeight(.semibold)
                    .foregroundStyle(display.current.isApproaching ? Color.orange : ControlPalette.accent)
                if let reach = display.current.reachLabel { Text(reach) }
            } else if let display, display.nextLeg?.index == leg.index, let duration = display.nextDuration {
                Text("Next at current airspeed: \(duration.label)")
                    .foregroundStyle(ControlPalette.accent)
            }
            if let onStartLeg {
                Button(isSelected ? "Restart from now" : "Start this leg") { onStartLeg(leg.index) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!actionsAreEnabled)
                    .accessibilityLabel("\(isSelected ? "Restart" : "Start") timing leg \(leg.number)")
                    .padding(.top, 3)
            }
        }
        .font(.caption.monospacedDigit())
    }
}

private extension MissionLegTiming.CurrentEstimate {
    var label: String {
        switch self {
        case .notStarted: return "Not started"
        case .selectLeg: return "Select a leg to begin timing"
        case .remaining(let seconds, _):
            return "Estimated remaining \(MissionTimingFormat.duration(seconds, rounding: .up))"
        case .pastEstimate(let seconds, _):
            return "Past still-air estimate: \(MissionTimingFormat.duration(seconds, rounding: .down))"
        case .zeroAirspeed: return "Unavailable at 0 kt"
        case .unavailable: return "Timing unavailable"
        }
    }

    var isApproaching: Bool {
        if case .remaining(let seconds, _) = self { return seconds <= 60 }
        return false
    }

    var reachLabel: String? {
        switch self {
        case .remaining(_, let reach), .pastEstimate(_, let reach):
            return "Updated reach \(MissionTimingFormat.duration(reach)) elapsed flight time"
        default: return nil
        }
    }
}

private extension MissionLegTiming.DurationEstimate {
    var label: String {
        switch self {
        case .available(let seconds): return MissionTimingFormat.duration(seconds, rounding: .up)
        case .zeroAirspeed: return "Unavailable at 0 kt"
        case .unavailable: return "Timing unavailable"
        }
    }

    var stripLabel: String {
        if case .available = self { return "Full duration \(label) at current airspeed" }
        return label
    }
}

struct MissionTimingPanel: View {
    @Bindable var session: FlightSession

    var body: some View {
        if let timing = session.legTiming, let display = session.timingDisplay {
            VStack(alignment: .leading, spacing: 10) {
                switch timing.schedule.availability {
                case .available:
                    HStack(alignment: .firstTextBaseline) {
                        Text("Still-air plan · \(timing.schedule.planningAirspeedKnots.formatted()) kt")
                            .font(.caption.weight(.semibold))
                        Spacer(minLength: 4)
                        Button("Undo timing start") { session.undoMissionLegStart() }
                            .buttonStyle(.bordered).controlSize(.small)
                            .disabled(!timing.canUndo || !session.canAdjustMissionTiming)
                    }
                    if display.current == .selectLeg {
                        Text(display.current.label).font(.caption)
                    }
                case .unavailable(let issue):
                    Text("Timing unavailable").font(.subheadline.weight(.semibold))
                    Text(issue.reason).font(.caption).foregroundStyle(ControlPalette.secondaryText)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .help("Planned reach is elapsed flight time. Still-air estimates assume the selected leg is flown correctly and do not confirm arrival.")
        }
    }
}

/// Always present for supplied timing, even when the mission panel is hidden.
struct MissionTimingStrip: View {
    let display: MissionLegTiming.Display

    var body: some View {
        HStack(spacing: 16) {
            Label("Still-air", systemImage: "clock")
                .font(.caption.weight(.semibold))
            VStack(alignment: .leading, spacing: 2) {
                if let leg = display.currentLeg {
                    Text("Leg \(leg.number) · \(leg.endLabel)")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .help("Leg \(leg.number) · \(leg.startLabel) → \(leg.endLabel)")
                }
                Text(display.current.label)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(display.current.isApproaching ? Color.orange : ControlPalette.primaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let next = display.nextLeg, let duration = display.nextDuration {
                Divider().padding(.vertical, 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next: leg \(next.number) · \(next.endLabel)")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .help("Leg \(next.number) · \(next.startLabel) → \(next.endLabel)")
                    Text(duration.stripLabel)
                        .font(.subheadline.monospacedDigit())
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(display.current.isApproaching ? Color.orange.opacity(0.1) : Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .top) { Divider() }
        .help("Still-air estimates use airspeed and your timing starts. They do not confirm actual progress.")
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
