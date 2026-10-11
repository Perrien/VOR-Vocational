import SwiftUI

/// The app's root screen: a quiet sectional-chart background behind a title
/// treatment and a two-by-two grid of Mode cards. Selecting a card routes
/// `ContentView` to that Mode. Home has no Home control of its own — it is
/// the root.
struct HomeView: View {
    var onSelect: (AppDestination) -> Void

    private let columns = [GridItem(.flexible(), spacing: 24),
                            GridItem(.flexible(), spacing: 24)]
    private let titleLeadingInset: CGFloat = 64
    private let titleTopInset: CGFloat = 56
    private let modeGridTopInset: CGFloat = 192

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundMap

                LazyVGrid(columns: columns, spacing: 24) {
                    ModeCard(title: "Learn",
                             description: "Build the picture",
                             artwork: "HomeModeLearnArtwork") { onSelect(.learn) }
                    ModeCard(title: "Practice",
                             description: "Hone the skills",
                             artwork: "HomeModePracticeArtwork") { onSelect(.practice) }
                    ModeCard(title: "Missions",
                             description: "Fly the brief",
                             artwork: "HomeModeMissionsArtwork") { onSelect(.missions) }
                    ModeCard(title: "Free Flight",
                             description: "Explore Myosia",
                             artwork: "HomeModeFreeFlightArtwork") { onSelect(.freeFlight) }
                }
                .padding(.top, modeGridTopInset)
                .padding(.horizontal, 48)
                .padding(.bottom, 48)
                .frame(maxWidth: 820, maxHeight: .infinity, alignment: .top)
            }
            // Give the ZStack the window's exact dimensions so the title's
            // origin never follows the aspect-filled background or card grid.
            .frame(width: geometry.size.width, height: geometry.size.height)
            .overlay(alignment: .topLeading) {
                titleTreatment
                    .padding(.top, titleTopInset)
                    .padding(.leading, titleLeadingInset)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }

    private var backgroundMap: some View {
        Image("HomeChartBackground")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .overlay(Color.white.opacity(0.05))
            .ignoresSafeArea()
    }

    private var titleTreatment: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("VOR Vocational")
                .font(.system(size: 52, weight: .bold, design: .serif))
                .foregroundStyle(Color(red: 0.05, green: 0.13, blue: 0.17))

            Text("Learn the art of radio navigation")
                .font(.system(size: 22, weight: .medium, design: .serif))
                .italic()
                .foregroundStyle(Color(red: 0.11, green: 0.22, blue: 0.27))
        }
        .shadow(color: .white.opacity(0.45), radius: 1, y: 1)
        .background(alignment: .leading) {
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.94, green: 0.91, blue: 0.80).opacity(0.72), location: 0),
                    .init(color: Color(red: 0.94, green: 0.91, blue: 0.80).opacity(0.30), location: 0.56),
                    .init(color: Color(red: 0.94, green: 0.91, blue: 0.80).opacity(0), location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 620, height: 132)
            .blur(radius: 10)
            .offset(x: -24)
        }
        .accessibilityElement(children: .combine)
    }
}

/// One Home Mode card: title and description labels over a purpose-made
/// illustration. The entire artwork-backed surface remains one large Button.
private struct ModeCard: View {
    let title: String
    let description: String
    let artwork: String
    let action: () -> Void

    @State private var isHovering = false

    private let cornerRadius: CGFloat = 20

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .top) {
                Image(artwork)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.93, blue: 0.85).opacity(0.88),
                        Color(red: 0.96, green: 0.93, blue: 0.85).opacity(0.38),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .center
                )

                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 34, weight: .bold, design: .serif))
                    Text(description)
                        .font(.system(size: 18, weight: .medium, design: .serif))
                        .italic()
                }
                .foregroundStyle(Color(red: 0.05, green: 0.13, blue: 0.17))
                .padding(.top, 18)
            }
            .frame(maxWidth: .infinity, minHeight: 210)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color(red: 0.05, green: 0.13, blue: 0.17), lineWidth: 2)
                    .padding(1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius - 4)
                    .stroke(Color.white.opacity(0.60), lineWidth: 1)
                    .padding(6)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.015 : 1)
        .shadow(color: .black.opacity(isHovering ? 0.34 : 0.22), radius: isHovering ? 12 : 7, y: isHovering ? 6 : 3)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
        .accessibilityLabel("\(title). \(description).")
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
