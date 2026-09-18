import SwiftUI

/// Missions' catalog (S4): every entry is a named future Mission, none
/// functional yet. Reuses `ModeListView`'s shared row treatment.
struct MissionsListView: View {
    var onHome: () -> Void

    private static let entries = [
        "Transport",
        "Sightseeing",
        "Nav Failure",
        "Off-course Recovery",
        "One NAV Down",
    ]

    var body: some View {
        ModeListView(title: "Missions", entries: Self.entries, onHome: onHome)
    }
}

#Preview {
    MissionsListView(onHome: {})
        .frame(width: 1100, height: 760)
}
