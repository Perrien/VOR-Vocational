import SwiftUI

/// The shared list screen for Modes that only show named future entries
/// (S3): every row is non-selectable with a small "Coming soon" label (U3),
/// on a high-contrast reading panel over the blurred Myosia background (U6),
/// with the Home control (U2). Learn and Missions each instantiate this once.
struct ModeListView: View {
    let title: String
    let entries: [String]
    var onHome: () -> Void

    var body: some View {
        ZStack {
            backgroundMap
            panel
        }
        .overlay(alignment: .topLeading) {
            // Same clearance as FreeFlightView's Home control, so every
            // Mode list's control lands at the same height.
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
            Text(title)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(ControlPalette.primaryText)

            VStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                    if index > 0 {
                        Divider().opacity(0.5)
                    }
                    ComingSoonRow(name: entry)
                }
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

/// One non-selectable row for a named future entry (U3): no preview, no
/// selection response, just the name and a discreet "Coming soon" label.
private struct ComingSoonRow: View {
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
    ModeListView(title: "Learn",
                 entries: ["Position Fix", "Radial Intercept and Track"],
                 onHome: {})
        .frame(width: 1100, height: 760)
}
