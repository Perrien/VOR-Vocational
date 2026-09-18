//
//  ContentView.swift
//  VOR Vocational
//
//  Created by Analyst on 9/8/26.
//

import SwiftUI

/// The Modes `ContentView` can show. Screens flatly replace one another (U1)
/// rather than pushing onto a navigation stack.
enum AppDestination: Hashable {
    case home, learn, practice, missions, freeFlight
}

struct ContentView: View {
    @State private var destination: AppDestination = .home

    var body: some View {
        switch destination {
        case .home:
            HomeView(onSelect: { destination = $0 })
        case .freeFlight:
            FreeFlightView(onHome: { destination = .home })
        case .learn, .practice, .missions:
            // Learn, Practice, and Missions screens land in Part 2's later tasks.
            EmptyView()
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 1100, height: 760)
}
