import SwiftUI

/// The app's root screen: a blurred Myosia map behind a two-by-two grid of
/// Mode cards (S1, U4, U5). Selecting a card routes `ContentView` to that
/// Mode. Home has no Home control of its own — it is the root.
struct HomeView: View {
    var onSelect: (AppDestination) -> Void

    private let columns = [GridItem(.flexible(), spacing: 24),
                            GridItem(.flexible(), spacing: 24)]

    var body: some View {
        ZStack {
            backgroundMap

            LazyVGrid(columns: columns, spacing: 24) {
                ModeCard(title: "Learn",
                         description: "Study VOR navigation concepts one skill at a time.",
                         systemImage: "book.closed.fill") { onSelect(.learn) }
                ModeCard(title: "Practice",
                         description: "Drill a single navigation skill until it clicks.",
                         systemImage: "scope") { onSelect(.practice) }
                ModeCard(title: "Free Flight",
                         description: "Fly Myosia with the full cockpit and no set objective.",
                         systemImage: "airplane") { onSelect(.freeFlight) }
                ModeCard(title: "Missions",
                         description: "Fly scripted, scored flights against a briefing.",
                         systemImage: "flag.checkered") { onSelect(.missions) }
            }
            .padding(48)
            .frame(maxWidth: 820)
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
}

/// One Home Mode card: label, one descriptive phrase (S5), and an SF Symbol
/// artwork cue (U5).
private struct ModeCard: View {
    let title: String
    let description: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: systemImage)
                    .font(.system(size: 36))
                    .frame(width: 56)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title2.weight(.semibold))
                    Text(description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.glass)
    }
}

/// The persistent Home control shown on every Mode list and on Free Flight
/// (U2): a small, clear Liquid Glass button that expands slightly on hover.
struct HomeControl: View {
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Label("Home", systemImage: "house.fill")
        }
        .buttonStyle(.glass)
        .scaleEffect(isHovering ? 1.08 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
    }
}

#Preview {
    HomeView(onSelect: { _ in })
        .frame(width: 1100, height: 760)
}
