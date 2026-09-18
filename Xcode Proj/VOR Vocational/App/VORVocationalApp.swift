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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(diagnosticsStore)
                .frame(minWidth: 1100, minHeight: 760)
        }
    }
}
