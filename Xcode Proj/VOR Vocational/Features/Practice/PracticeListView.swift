import SwiftUI

/// Practice's catalog (S2): Position Challenge is the one actionable row,
/// with a clear Start affordance (U7); any other Practice entry would be a
/// non-selectable "Coming soon" row styled like Learn and Missions' shared
/// rows (U3), but none are named yet, so the list holds just Position
/// Challenge today. Selecting it shows `PositionChallengeView` in place.
struct PracticeListView: View {
    var onHome: () -> Void

    @State private var isChallengeActive = false

    var body: some View {
        if isChallengeActive {
            PositionChallengeView(onHome: onHome)
        } else {
            catalog
        }
    }

    private var catalog: some View {
        ZStack {
            backgroundMap
            panel
        }
        .overlay(alignment: .topLeading) {
            HomeControl(action: onHome)
                .padding(.top, 40)
                .padding(.leading, 16)
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
            Text("Practice")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(ControlPalette.primaryText)

            VStack(spacing: 0) {
                PositionChallengeRow { isChallengeActive = true }
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

/// Practice's one functional row: selecting it starts Position Challenge.
/// No description line, matching S5's "no repeated descriptions" rule for
/// every Mode list.
private struct PositionChallengeRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text("Position Challenge")
                    .font(.body.weight(.medium))
                    .foregroundStyle(ControlPalette.primaryText)
                Spacer()
                Text("Start")
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

#Preview {
    PracticeListView(onHome: {})
        .frame(width: 1100, height: 760)
}
