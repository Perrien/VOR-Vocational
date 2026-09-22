import SwiftUI

/// Missions' catalog: Transport is the one briefing the player can inspect;
/// the remaining future missions retain the normal unavailable treatment.
struct MissionsListView: View {
    var onHome: () -> Void

    @State private var isShowingTransportBriefing = false

    var body: some View {
        if isShowingTransportBriefing {
            TransportBriefingView(onMissions: { isShowingTransportBriefing = false },
                                  onHome: onHome)
        } else {
            catalog
        }
    }

    private var catalog: some View {
        GeometryReader { _ in
            ZStack {
                backgroundMap
                panel
            }
            .overlay(alignment: .topLeading) {
                HomeControl(action: onHome)
                    .padding(.top, 40)
                    .padding(.leading, 16)
            }
        }
        .ignoresSafeArea()
    }

    private var backgroundMap: some View {
        Image("MyosiaMap")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .blur(radius: 20)
            .overlay(Color.black.opacity(0.28))
            .ignoresSafeArea()
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Missions")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(ControlPalette.primaryText)

            VStack(spacing: 0) {
                TransportMissionRow { isShowingTransportBriefing = true }
                Divider().opacity(0.5)
                UnavailableMissionRow(name: "Sightseeing")
                Divider().opacity(0.5)
                UnavailableMissionRow(name: "Nav Failure")
                Divider().opacity(0.5)
                UnavailableMissionRow(name: "Off-course Recovery")
                Divider().opacity(0.5)
                UnavailableMissionRow(name: "One NAV Down")
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(32)
        .frame(maxWidth: 560)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.94),
                    in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.primary.opacity(0.08)))
    }
}

private struct TransportMissionRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text("Transport")
                    .font(.body.weight(.medium))
                    .foregroundStyle(ControlPalette.primaryText)
                Spacer()
                Text("Briefing")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(ControlPalette.accent, in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct UnavailableMissionRow: View {
    let name: String

    var body: some View {
        HStack {
            Text(name)
                .font(.body.weight(.medium))
                .foregroundStyle(ControlPalette.primaryText)
            Spacer()
            Text("Coming soon")
                .font(.caption)
                .foregroundStyle(ControlPalette.secondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview {
    MissionsListView(onHome: {})
        .frame(width: 1100, height: 760)
}
