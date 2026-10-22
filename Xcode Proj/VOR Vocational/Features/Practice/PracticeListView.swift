import SwiftUI

/// Each exercise replaces the catalog. Returning removes its local state,
/// so opening the moving exercise again always presents a fresh ready screen.
struct PracticeListView: View {
    var onHome: () -> Void

    private enum Exercise { case position, positionAndHeading }
    @State private var selectedExercise: Exercise?

    var body: some View {
        switch selectedExercise {
        case .position:
            PositionChallengeView(onHome: onHome)
        case .positionAndHeading:
            MovingPositionChallengeView(onPractice: { selectedExercise = nil }, onHome: onHome)
        case nil:
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
            Text("Practice")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(ControlPalette.primaryText)

            VStack(spacing: 0) {
                PracticeExerciseRow(title: "Position Challenge") { selectedExercise = .position }
                Divider()
                PracticeExerciseRow(title: "Position & Heading Challenge") { selectedExercise = .positionAndHeading }
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

/// Matches the other mode catalogs' title and Start affordance.
private struct PracticeExerciseRow: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
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
