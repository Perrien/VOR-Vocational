//
//  VORVocationalApp.swift
//  VOR Vocational
//
//  Created by Analyst on 9/8/26.
//

import SwiftUI

@main
struct VORVocationalApp: App {
    @State private var diagnosticsStore = FlightDiagnosticsStore()

    #if DEBUG
    @Environment(\.openWindow) private var openWindow
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(diagnosticsStore)
                .frame(minWidth: 1100, minHeight: 760)
        }
        #if DEBUG
        .commands {
            CommandMenu("Debug") {
                Button("Flight Diagnostics") {
                    openWindow(id: "flight-diagnostics")
                }
            }
        }
        #endif

        #if DEBUG
        Window("Flight Diagnostics", id: "flight-diagnostics") {
            FlightDiagnosticsView()
                .environment(diagnosticsStore)
        }
        #endif
    }
}
