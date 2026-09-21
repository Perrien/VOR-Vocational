import SwiftUI

/// A small persistent Chart button, meant for the map's upper-right corner.
/// Its popover owns exactly the player-facing chart layers: what a pilot
/// toggles while flying, as opposed to Flight Diagnostics' simulation truth.
struct ChartButton: View {
    @Binding var showVORs: Bool
    @Binding var visibleVORServiceVolumes: Set<VORServiceVolume>
    @Binding var showAirports: Bool
    @Binding var showRadials: Bool
    @Binding var showGrid: Bool
    @Binding var showSightseeingRegions: Bool
    @Binding var showSightseeingRegionNames: Bool
    @Binding var gridSizeNM: Double

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Label("Chart", systemImage: "map")
        }
        .buttonStyle(.glass)
        .popover(isPresented: $isPresented) {
            ChartPopoverContent(
                showVORs: $showVORs,
                visibleVORServiceVolumes: $visibleVORServiceVolumes,
                showAirports: $showAirports,
                showRadials: $showRadials,
                showGrid: $showGrid,
                showSightseeingRegions: $showSightseeingRegions,
                showSightseeingRegionNames: $showSightseeingRegionNames,
                gridSizeNM: $gridSizeNM
            )
        }
    }
}

/// The popover's contents: VOR visibility and its per-service-volume filters,
/// airports, radials, grid (with size), and sightseeing regions. Nothing
/// about zoom, CDI scale, navigation display, or Position Challenge belongs
/// here — those either aren't player-facing or live in Flight Diagnostics.
private struct ChartPopoverContent: View {
    @Binding var showVORs: Bool
    @Binding var visibleVORServiceVolumes: Set<VORServiceVolume>
    @Binding var showAirports: Bool
    @Binding var showRadials: Bool
    @Binding var showGrid: Bool
    @Binding var showSightseeingRegions: Bool
    @Binding var showSightseeingRegionNames: Bool
    @Binding var gridSizeNM: Double

    @State private var gridSizeText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chart")
                .font(.headline)

            Toggle("VORs", isOn: $showVORs)
                .toggleStyle(.checkbox)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(VORServiceVolume.allCases, id: \.self) { serviceVolume in
                    Toggle(serviceVolume.displayName,
                           isOn: Binding(
                            get: { visibleVORServiceVolumes.contains(serviceVolume) },
                            set: { isVisible in
                                if isVisible {
                                    visibleVORServiceVolumes.insert(serviceVolume)
                                } else {
                                    visibleVORServiceVolumes.remove(serviceVolume)
                                }
                            }
                        ))
                        .toggleStyle(.checkbox)
                }
            }
            .padding(.leading, 18)

            Toggle("Airports", isOn: $showAirports)
                .toggleStyle(.checkbox)
            Toggle("Radials", isOn: $showRadials)
                .toggleStyle(.checkbox)
            Toggle("Sightseeing names", isOn: $showSightseeingRegionNames)
                .toggleStyle(.checkbox)
            Toggle("Sightseeing regions", isOn: $showSightseeingRegions)
                .toggleStyle(.checkbox)

            HStack(spacing: 8) {
                Toggle("Grid", isOn: $showGrid)
                    .toggleStyle(.checkbox)

                TextField("50", text: $gridSizeText)
                    .textFieldStyle(.plain)
                    .font(.caption.monospacedDigit())
                    .frame(width: 42)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                    )

                Text("NM")
                    .font(.caption.monospacedDigit())
            }
        }
        .padding(16)
        .frame(width: 240, alignment: .leading)
        .onAppear {
            gridSizeText = formattedGridSize(gridSizeNM)
        }
        .onChange(of: gridSizeText) { _, newValue in
            let filtered = newValue.filter { $0.isNumber }
            if filtered != newValue {
                gridSizeText = filtered
            }
            if let size = Double(filtered), size > 0 {
                gridSizeNM = size
            }
        }
        .onSubmit {
            gridSizeText = formattedGridSize(gridSizeNM)
        }
    }

    private func formattedGridSize(_ size: Double) -> String {
        String(format: "%.0f", size)
    }
}
