#if DEBUG
import SwiftUI

/// Static development fixtures, independent of the later moving-attempt engine.
struct PracticePreviewView: View {
    private enum Preset: String, CaseIterable, Identifiable {
        case markerDrag = "Marker drag"
        case coincidentSame = "Coincident / same heading"
        case coincidentDifferent = "Coincident / different headings"
        case tiny = "0.01 NM"
        case near = "1 NM"
        case wide = "100 NM"
        case edge = "Full-chart edge/corner"
        var id: Self { self }
    }

    @State private var preset = Preset.markerDrag
    @State private var session = FlightSession(normalizedAirportPosition: CGPoint(x: 0.5, y: 0.5))
    @State private var estimatePosition = CGPoint(x: 0.5, y: 0.5)
    @State private var estimatedHeading = 45.0
    @State private var actualHeading = 45.0
    @State private var showsArrow = true
    @State private var showsPanel = true
    @State private var chartSize = CGSize.zero
    @State private var fitRevision = 0

    private let configuration = FlightSurfaceConfiguration(
        showsAirportsByDefault: false, showsSightseeingRegionNamesByDefault: false,
        allowsAircraftSimulation: false, showsHeadingPresentation: false,
        showsFlightControls: false, showsAircraftMarker: false)

    private var isPlacement: Bool { preset == .markerDrag }
    private var cameraPolicy: ChartCameraPolicy { isPlacement ? .fullChart : .comparison }
    private var actualPosition: CGPoint {
        preset == .edge ? CGPoint(x: 1, y: 0) : CGPoint(x: 0.5, y: 0.5)
    }
    private var fitRequest: ChartFitRequest? {
        isPlacement ? nil : ChartFitRequest(positions: [estimatePosition, actualPosition], revision: fitRevision)
    }

    var body: some View {
        MapView(session: session, configuration: configuration,
                    receptionPosition: actualPosition,
                    sidePanelTitle: "Practice", isSidePanelPresented: $showsPanel,
                    flightStatusHeight: 44, cameraPolicy: cameraPolicy, fitRequest: fitRequest,
                    sidePanel: { inspector },
                    flightStatus: { cameraControls },
                    screenOverlay: { viewport in
                        Group {
                            if isPlacement {
                                DraggablePositionEstimateMarker(position: $estimatePosition,
                                    heading: showsArrow ? estimatedHeading : nil, viewport: viewport)
                            } else {
                                PracticeComparisonView(estimatePosition: estimatePosition,
                                    estimatedHeading: estimatedHeading, actualPosition: actualPosition,
                                    actualHeading: actualHeading, viewport: viewport)
                            }
                        }
                        .onAppear { chartSize = viewport.size }
                        .onChange(of: viewport.size) { _, size in chartSize = size }
                    })
            .id(preset)
            .overlay(alignment: .topLeading) {
                HStack {
                    Text("Practice Preview").font(.headline)
                    Picker("Preset", selection: $preset) {
                        ForEach(Preset.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .frame(width: 360)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(.leading, 16)
                .padding(.top, 40)
            }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { reset() }
        .onChange(of: preset) { reset() }
    }

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isPlacement ? "Marker placement" : "Frozen comparison").font(.title3.bold())
            Text(isPlacement
                ? "Drag the center, interior, arrow, or surrounding buffer. Background clicks keep the marker in place; background drags pan the chart."
                : "Both circle centers are exact. Dashed orange is Estimate; solid blue is Actual. Inspect close or coincident positions without a timed flight.")
                .font(.callout)
            if isPlacement {
                Toggle("Show heading arrow", isOn: $showsArrow)
            }
            headingControl("Estimate", value: $estimatedHeading)
            if !isPlacement { headingControl("Actual", value: $actualHeading) }
            Divider()
            if !isPlacement {
                Text(String(format: "Distance error: %.4f NM", VORNavigation.distanceNM(
                    fromNormalized: estimatePosition, toNormalized: actualPosition,
                    mapWidthNM: FlightWorld.widthNM, mapHeightNM: FlightWorld.heightNM)))
                Text(String(format: "Heading error: %.0f°", abs(VORNavigation.normalize180(estimatedHeading - actualHeading))))
            }
            Text("Zoom: \(session.zoom, specifier: "%.2f")×").monospacedDigit()
            Button("Reset preset", action: reset)
            Text("Development data only. The moving challenge is not connected yet.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .foregroundStyle(ControlPalette.primaryText)
    }

    private func headingControl(_ name: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(format: "%@ heading %03d°", name, Int(value.wrappedValue)))
                .font(.callout.monospacedDigit())
            Slider(value: value, in: 0...359, step: 1)
                .accessibilityLabel("\(name) heading")
        }
    }

    private var cameraControls: some View {
        HStack {
            Text(isPlacement ? "Drag target review" : "Comparison inspection").font(.caption)
            Spacer()
            PracticeComparisonControls(onZoomOut: { zoom(by: 0.8) }, onZoomIn: { zoom(by: 1.25) }, onFit: {
                if isPlacement { session.zoom = 1; session.pan = .zero }
                else { fitRevision += 1 }
            })
        }
        .padding(.horizontal, 16)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func zoom(by factor: CGFloat) {
        let viewport = ChartViewport(size: chartSize, crop: cameraPolicy.crop, zoom: session.zoom, pan: session.pan)
        let camera = viewport.zoomed(by: factor,
                                    anchoredAt: CGPoint(x: chartSize.width / 2, y: chartSize.height / 2),
                                    policy: cameraPolicy)
        session.zoom = camera.zoom
        session.pan = camera.pan
    }

    private func reset() {
        let fresh = FlightSession(normalizedAirportPosition: CGPoint(x: 0.5, y: 0.5))
        fresh.showAirports = false
        fresh.showRadials = false
        session = fresh
        estimatePosition = CGPoint(x: 0.5, y: 0.5)
        estimatedHeading = 45
        actualHeading = preset == .coincidentDifferent ? 225 : 45
        showsPanel = true
        switch preset {
        case .tiny, .near, .wide:
            let distance: CGFloat = preset == .tiny ? 0.01 : (preset == .near ? 1 : 100)
            estimatePosition.x += distance / FlightWorld.widthNM
        case .edge: estimatePosition = CGPoint(x: 0, y: 1)
        default: break
        }
        fitRevision += 1
    }
}
#endif
