import SwiftUI
import AppKit

/// A flat map with VOR stations and a draggable plane, plus NAV radios below it.
struct MapView: View {
    @Bindable var session: FlightSession

    init(session: FlightSession) {
        _session = Bindable(session)
    }

    // The fixed VOR beacons on the land of Myosia.
    private let stations: [VORStation] = VORStation.myosia
    // The fixed list of airports loaded once.
    private let airports: [Airport] = Airport.loadFromBundle()
    // The fixed list of named sightseeing regions loaded once.
    private let sightseeingRegions: [SightseeingRegion] = SightseeingRegion.myosia

    // The plane's position when the current drag began, used to compute the
    // running offset while dragging.
    @State private var dragStartPosition: CGPoint?

    // Both NAV radios use the same presentation selected in the map panel.
    @State private var navigationInstrumentStyle: NavigationInstrumentStyle = .cdi

    @State private var panStart: CGSize?

    private let panelHeight: CGFloat = 350
    private let controlPanelWidth: CGFloat = 240
    private let minZoom: CGFloat = 1
    private let maxZoom: CGFloat = 6
    /// The source map is authored at 500 NM across.
    private let mapWidthNM: Double = 500
    /// The map's real-world height, derived from the artwork's own aspect
    /// ratio so north-south distances use the same NM-per-pixel scale as
    /// east-west ones.
    private var mapHeightNM: Double { mapWidthNM / Double(FlatMap.sourceMapAspect) }
    private let compassRoseMinZoom: CGFloat = 2

    var body: some View {
        GeometryReader { geometry in
            let mapSize = CGSize(width: max(0, geometry.size.width - controlPanelWidth),
                                 height: max(0, geometry.size.height - panelHeight))
            // The cropped map image is aspect-fit inside the map area, so
            // everything on the map is positioned relative to this fitted rect.
            let imageRect = FlatMap.fittedRect(in: mapSize)
            let planePos = FlatMap.point(for: session.normalizedAircraftPosition, in: imageRect)
            let nav1Reading = receiverReading(for: session.nav1)
            let nav2Reading = receiverReading(for: session.nav2)

            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    mapArea(mapSize: mapSize, imageRect: imageRect, planePos: planePos)

                    HStack(spacing: 16) {
                        PlaneControlView(heading: $session.heading,
                                         speedKnots: $session.speedKnots,
                                         isFlying: $session.isFlying,
                                         timeMultiplier: $session.timeMultiplier,
                                         isChallengeActive: false)

                        NavRadioView(
                            name: "NAV1",
                            ident: receivedIdentBinding(for: .nav1),
                            obs: obsBinding(for: .nav1),
                            heading: session.heading,
                            instrumentStyle: navigationInstrumentStyle,
                            tunedStation: nav1Reading.station,
                            reading: { obs in receiverReading(for: session.nav1, obs: obs).cdiReading }
                        )
                        NavRadioView(
                            name: "NAV2",
                            ident: receivedIdentBinding(for: .nav2),
                            obs: obsBinding(for: .nav2),
                            heading: session.heading,
                            instrumentStyle: navigationInstrumentStyle,
                            tunedStation: nav2Reading.station,
                            reading: { obs in receiverReading(for: session.nav2, obs: obs).cdiReading }
                        )
                    }
                    .padding(16)
                    .frame(height: panelHeight)
                    .frame(maxWidth: .infinity)
                    .background(ControlPalette.panelBackground)
                }

                MapControlPanel(zoom: $session.zoom, showVORs: $session.showVORs,
                                visibleVORServiceVolumes: $session.visibleVORServiceVolumes,
                                showAirports: $session.showAirports, showRadials: $session.showRadials,
                                showGrid: $session.showGrid, showSightseeingRegions: $session.showSightseeingRegions,
                                gridSizeNM: $session.gridSizeNM,
                                cdiMax: $session.cdiMax,
                                navigationInstrumentStyle: $navigationInstrumentStyle,
                                zoomRange: minZoom...maxZoom)
                    .frame(width: controlPanelWidth)
            }
            // Re-clamp the pan whenever the zoom changes (e.g. via the slider) so
            // the map never drifts off the visible area.
            .onChange(of: session.zoom) {
                session.pan = clampedPan(session.pan, zoom: session.zoom, mapSize: mapSize)
            }
            .onAppear {
                session.pan = clampedPan(session.pan, zoom: session.zoom, mapSize: mapSize)
            }
        }
        .ignoresSafeArea()
    }

    /// The zoomable, pannable map. Only the artwork scales with the camera; the
    /// markers and plane keep a constant screen size and are positioned by applying
    /// the same zoom/pan transform to their map coordinates (`screenPoint`).
    private func mapArea(mapSize: CGSize, imageRect: CGRect, planePos: CGPoint) -> some View {
        ZStack {
            // Map artwork: this is the only layer that scales with zoom.
            FlatMap(imageRect: imageRect)
                .frame(width: mapSize.width, height: mapSize.height)
                .scaleEffect(session.zoom)
                .offset(session.pan)

            if session.showGrid {
                HexGridOverlay(hexHeightNM: session.gridSizeNM,
                               imageRect: imageRect,
                               mapSize: mapSize,
                               zoom: session.zoom,
                               pan: session.pan,
                               mapWidthNM: mapWidthNM)
            }

            if session.showSightseeingRegions {
                SightseeingCheckpointsOverlay(regions: sightseeingRegions,
                                              imageRect: imageRect,
                                              mapSize: mapSize,
                                              zoom: session.zoom,
                                              pan: session.pan,
                                              mapWidthNM: mapWidthNM)
            }

            // Radial lines from tuned stations, drawn beneath the station symbols.
            if session.showRadials {
                RadialsOverlay(radials: tunedRadials(imageRect: imageRect, mapSize: mapSize),
                               length: max(mapSize.width, mapSize.height) * 3)
                    .allowsHitTesting(false)
            }

            // Marker layer: constant size, manually transformed to track the map.
            if session.showVORs {
                ForEach(stations) { station in
                    if session.visibleVORServiceVolumes.contains(station.serviceVolume) {
                        let stationPoint = point(for: station, in: imageRect)
                        let screenStationPoint = screenPoint(stationPoint, mapSize: mapSize)
                        let showsCompassRose = session.selectedVORID == station.id && session.zoom >= compassRoseMinZoom

                        if session.selectedVORID == station.id {
                            VORServiceRangeRing(radius: serviceRangeRadius(for: station, imageRect: imageRect) * session.zoom)
                                .position(screenStationPoint)
                        }

                        if showsCompassRose {
                            CompassRoseView()
                                .position(screenStationPoint)
                        }

                        VORStationView(station: station, isSelected: session.selectedVORID == station.id)
                            .position(screenStationPoint)
                            .onTapGesture {
                                session.selectedVORID = session.selectedVORID == station.id ? nil : station.id
                            }
                        }
                    }
            }

            if session.showAirports {
                ForEach(airports) { airport in
                    AirportMarkerView(airport: airport)
                        .position(screenPoint(point(for: CGPoint(x: airport.x, y: airport.y), in: imageRect),
                                              mapSize: mapSize))
                }
            }

            // Landmark names stay visible even when checkpoint tolerances are hidden.
            ForEach(sightseeingRegions) { region in
                Text(region.name)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.62), in: Capsule())
                    .shadow(color: .black.opacity(0.7), radius: 2)
                    .position(screenPoint(point(for: region.labelPosition, in: imageRect),
                                          mapSize: mapSize))
                    .allowsHitTesting(false)
            }

            PlaneIcon(heading: session.heading)
                .position(screenPoint(planePos, mapSize: mapSize))
                // The plane's own drag wins over panning when the drag starts on it.
                .highPriorityGesture(planeDrag(planePos: planePos, imageRect: imageRect))

            FlightTimerView(normalizedAircraftPosition: $session.normalizedAircraftPosition,
                            heading: $session.heading,
                            speedKnots: $session.speedKnots,
                            isFlying: $session.isFlying,
                            timeMultiplier: $session.timeMultiplier,
                            mapBounds: imageRect,
                            pixelsPerNM: pixelsPerNM(in: imageRect))
        }
        .frame(width: mapSize.width, height: mapSize.height)
        .clipped()
        .contentShape(Rectangle())
        .gesture(panGesture(mapSize: mapSize))
        .coordinateSpace(name: mapSpace)
        .background(
            ScrollWheelReader { deltaY in
                applyZoomDelta(deltaY, mapSize: mapSize)
            }
        )
    }

    private let mapSpace = "mapArea"

    /// The chart's horizontal scale, shared by reception math and flight movement.
    private func pixelsPerNM(in imageRect: CGRect) -> CGFloat {
        FlatMap.pixelsPerNM(in: imageRect, mapWidthNM: mapWidthNM)
    }

    /// The radials to draw for the currently received radios, in screen space.
    private func tunedRadials(imageRect: CGRect, mapSize: CGSize) -> [Radial] {
        var result: [Radial] = []
        for receiver in [session.nav1, session.nav2] {
            if let station = receiverReading(for: receiver).station {
                let origin = screenPoint(point(for: station, in: imageRect), mapSize: mapSize)
                result.append(Radial(origin: origin, courseDegrees: Double(receiver.obs)))
            }
        }
        return result
    }

    /// Maps a point in unscaled map space to its on-screen position under the
    /// current camera, matching `.scaleEffect(zoom).offset(pan)` about the center.
    private func screenPoint(_ p: CGPoint, mapSize: CGSize) -> CGPoint {
        let cx = mapSize.width / 2, cy = mapSize.height / 2
        return CGPoint(
            x: (p.x - cx) * session.zoom + cx + session.pan.width,
            y: (p.y - cy) * session.zoom + cy + session.pan.height
        )
    }

    /// Dragging the plane moves it around the map. Translation arrives in the
    /// unscaled map space, so we divide by `zoom` to convert to map coordinates.
    private func planeDrag(planePos: CGPoint, imageRect: CGRect) -> some Gesture {
        DragGesture(coordinateSpace: .named(mapSpace))
            .onChanged { value in
                let start = dragStartPosition ?? planePos
                if dragStartPosition == nil { dragStartPosition = start }
                let proposed = CGPoint(
                    x: start.x + value.translation.width / session.zoom,
                    y: start.y + value.translation.height / session.zoom
                )
                if let normalizedPosition = FlatMap.sourcePosition(
                    for: clamp(proposed, in: imageRect),
                    in: imageRect
                ) {
                    session.normalizedAircraftPosition = normalizedPosition
                }
            }
            .onEnded { _ in dragStartPosition = nil }
    }

    /// Dragging the map background pans it (only meaningful when zoomed in).
    private func panGesture(mapSize: CGSize) -> some Gesture {
        DragGesture(coordinateSpace: .named(mapSpace))
            .onChanged { value in
                let start = panStart ?? session.pan
                if panStart == nil { panStart = start }
                let proposed = CGSize(width: start.width + value.translation.width,
                                      height: start.height + value.translation.height)
                session.pan = clampedPan(proposed, zoom: session.zoom, mapSize: mapSize)
            }
            .onEnded { _ in panStart = nil }
    }

    /// Keeps the plane's center within the visible cropped map.
    private func clamp(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, rect.minX), rect.maxX),
            y: min(max(point.y, rect.minY), rect.maxY)
        )
    }

    /// Limits the pan offset so the scaled map always covers the map area —
    /// you can never drag empty space into view. At zoom 1 the only valid pan is zero.
    private func clampedPan(_ proposed: CGSize, zoom: CGFloat, mapSize: CGSize) -> CGSize {
        let maxX = max(0, mapSize.width * (zoom - 1) / 2)
        let maxY = max(0, mapSize.height * (zoom - 1) / 2)
        return CGSize(width: min(max(proposed.width, -maxX), maxX),
                      height: min(max(proposed.height, -maxY), maxY))
    }

    /// Applies a scroll-wheel delta to the zoom, centered on the map. Positive
    /// delta (scroll up) zooms in. Pan is re-clamped by `onChange(of: zoom)`.
    private func applyZoomDelta(_ deltaY: CGFloat, mapSize: CGSize) {
        let factor = 1 + deltaY * 0.08
        session.zoom = min(max(session.zoom * factor, minZoom), maxZoom)
    }

    private enum Receiver { case nav1, nav2 }

    private func receiverReading(for receiver: NAVReceiver, obs: Double? = nil) -> ReceiverReading {
        VORNavigation.receiverReading(
            frequencyHundredths: receiver.frequencyHundredths,
            obs: Int((obs ?? Double(receiver.obs)).rounded()),
            normalizedAircraftPosition: session.normalizedAircraftPosition,
            stations: stations,
            mapWidthNM: mapWidthNM,
            mapHeightNM: mapHeightNM,
            cdiMax: session.cdiMax
        )
    }

    private func obsBinding(for receiver: Receiver) -> Binding<Double> {
        Binding(
            get: { Double(receiver == .nav1 ? session.nav1.obs : session.nav2.obs) },
            set: { newValue in
                let value = Int(newValue.rounded()).quotientAndRemainder(dividingBy: 360).remainder
                if receiver == .nav1 {
                    session.nav1.obs = value < 0 ? value + 360 : value
                } else {
                    session.nav2.obs = value < 0 ? value + 360 : value
                }
            }
        )
    }

    /// The legacy radio view remains until T4 adds frequency knobs. Its
    /// identifier display derives from reception and never stores an ident.
    private func receivedIdentBinding(for receiver: Receiver) -> Binding<String> {
        Binding(
            get: {
                let navReceiver = receiver == .nav1 ? session.nav1 : session.nav2
                return receiverReading(for: navReceiver).station?.ident ?? ""
            },
            set: { _ in }
        )
    }

    /// Converts a station's service volume into an unscaled map-space radius.
    private func serviceRangeRadius(for station: VORStation, imageRect: CGRect) -> CGFloat {
        CGFloat(station.rangeNM) * pixelsPerNM(in: imageRect)
    }

    /// The screen position of a station within the fitted map image.
    private func point(for station: VORStation, in rect: CGRect) -> CGPoint {
        point(for: station.relativePosition, in: rect)
    }

    /// Converts a normalized map-image coordinate to unscaled map space.
    private func point(for relativePosition: CGPoint, in rect: CGRect) -> CGPoint {
        FlatMap.point(for: relativePosition, in: rect)
    }

}

/// Advances the plane while flight is enabled. The bindings keep the loop tied
/// to the latest heading and speed even while the controls are being edited.
private struct FlightTimerView: View {
    @Binding var normalizedAircraftPosition: CGPoint
    @Binding var heading: Double
    @Binding var speedKnots: Double
    @Binding var isFlying: Bool
    @Binding var timeMultiplier: Double

    let mapBounds: CGRect
    let pixelsPerNM: CGFloat

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task(id: isFlying) {
                await runFlightLoop()
            }
    }

    private func runFlightLoop() async {
        guard isFlying else { return }

        var lastUpdate = Date()
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 16_000_000)
            guard !Task.isCancelled else { return }

            let now = Date()
            let elapsed = min(max(now.timeIntervalSince(lastUpdate), 0), 0.1)
            lastUpdate = now
            advancePlane(by: elapsed)
        }
    }

    private func advancePlane(by elapsed: TimeInterval) {
        let currentPosition = FlatMap.point(for: normalizedAircraftPosition, in: mapBounds)
        let localPosition = CGPoint(x: currentPosition.x - mapBounds.minX,
                                    y: currentPosition.y - mapBounds.minY)
        let nextLocalPosition = FlightPhysics.advance(position: localPosition, heading: heading,
                                                       speedKnots: speedKnots,
                                                       elapsed: elapsed * timeMultiplier,
                                                       pixelsPerNM: pixelsPerNM,
                                                       bounds: mapBounds.size)
        guard let nextNormalizedPosition = FlatMap.sourcePosition(
            for: CGPoint(x: nextLocalPosition.x + mapBounds.minX,
                         y: nextLocalPosition.y + mapBounds.minY),
            in: mapBounds
        ) else { return }
        normalizedAircraftPosition = nextNormalizedPosition
    }
}

// MARK: - Map control panel

/// The right-hand panel for controlling the map view: zoom and layer visibility.
struct MapControlPanel: View {
    @Binding var zoom: CGFloat
    @Binding var showVORs: Bool
    @Binding var visibleVORServiceVolumes: Set<VORServiceVolume>
    @Binding var showAirports: Bool
    @Binding var showRadials: Bool
    @Binding var showGrid: Bool
    @Binding var showSightseeingRegions: Bool
    @Binding var gridSizeNM: Double
    @Binding var cdiMax: Double
    @Binding var navigationInstrumentStyle: NavigationInstrumentStyle
    let zoomRange: ClosedRange<CGFloat>

    @State private var gridSizeText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Map")
                .font(.headline)
                .foregroundStyle(ControlPalette.accent)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Zoom")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ControlPalette.primaryText)
                    Spacer()
                    Text(String(format: "%.1f×", zoom))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(ControlPalette.primaryText)
                }
                Slider(value: $zoom, in: zoomRange)
                    .tint(ControlPalette.accent)
            }

            CDIMaxField(value: $cdiMax)

            VStack(alignment: .leading, spacing: 8) {
                Text("Navigation display")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ControlPalette.primaryText)
                Picker("Navigation display", selection: $navigationInstrumentStyle) {
                    ForEach(NavigationInstrumentStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }

            Divider().overlay(ControlPalette.divider)

            VStack(alignment: .leading, spacing: 8) {
                Text("Layers")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ControlPalette.secondaryText)
                Toggle("VORs", isOn: $showVORs)
                    .toggleStyle(.checkbox)
                    .foregroundStyle(ControlPalette.primaryText)
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
                            .foregroundStyle(ControlPalette.primaryText)
                    }
                }
                .padding(.leading, 18)
                Toggle("Airports", isOn: $showAirports)
                    .toggleStyle(.checkbox)
                    .foregroundStyle(ControlPalette.primaryText)
                Toggle("Sightseeing regions", isOn: $showSightseeingRegions)
                    .toggleStyle(.checkbox)
                    .foregroundStyle(ControlPalette.primaryText)
                Toggle("Radials", isOn: $showRadials)
                    .toggleStyle(.checkbox)
                    .foregroundStyle(ControlPalette.primaryText)
                HStack(spacing: 8) {
                    Toggle("Grid", isOn: $showGrid)
                        .toggleStyle(.checkbox)
                        .foregroundStyle(ControlPalette.primaryText)

                    TextField("50", text: $gridSizeText)
                        .textFieldStyle(.plain)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(ControlPalette.primaryText)
                        .frame(width: 42)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(ControlPalette.fieldBackground, in: RoundedRectangle(cornerRadius: 5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(ControlPalette.fieldBorder, lineWidth: 1)
                        )

                    Text("NM")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(ControlPalette.primaryText)
                }
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ControlPalette.panelBackground)
        .tint(ControlPalette.accent)
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

/// Bridges macOS mouse scroll-wheel events into SwiftUI. There is no first-party
/// modifier for scroll-wheel input on a plain view, so we install a local event
/// monitor and report the vertical delta when the pointer is over this view.
struct ScrollWheelReader: NSViewRepresentable {
    /// Called with the vertical scroll delta (positive = scroll up).
    var onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = MonitorView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? MonitorView)?.onScroll = onScroll
    }

    final class MonitorView: NSView {
        var onScroll: ((CGFloat) -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard monitor == nil, window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, let window = self.window, event.window == window else { return event }
                // Only handle scrolls that land over the map area.
                let frame = self.convert(self.bounds, to: nil)
                guard frame.contains(event.locationInWindow) else { return event }
                let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY * 0.02 : event.deltaY
                self.onScroll?(delta)
                return nil
            }
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }
}

#Preview {
    MapView(session: FlightSession(normalizedAirportPosition: .zero))
        .frame(width: 1100, height: 760)
}
