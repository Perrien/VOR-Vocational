import SwiftUI
import AppKit

/// A flat map with an optional side panel, above the full-width NAV cockpit.
struct MapView<ChartOverlay: View, SidePanel: View, FlightStatus: View, ScreenOverlay: View>: View {
    @Bindable var session: FlightSession
    private let configuration: FlightSurfaceConfiguration

    /// Chart-space content positioned by a caller outside this view (e.g.
    /// Position Challenge's hidden-target reveal), given the same fitted
    /// `imageRect` this view already threads through `FlatMap.point(for:in:)`.
    /// Defaults to none, so Free Flight's rendering is unaffected.
    private let chartOverlay: (CGRect) -> ChartOverlay
    /// Screen-sized content uses the exact same projection as station symbols.
    private let screenOverlay: (ChartViewport) -> ScreenOverlay
    private let cameraPolicy: ChartCameraPolicy
    private let fitRequest: ChartFitRequest?

    /// Mode-owned content beside the chart. Its visibility changes only the
    /// chart's available space, keeping the cockpit and flight session intact.
    private let sidePanel: () -> SidePanel
    private let sidePanelTitle: String
    private let isSidePanelPresented: Binding<Bool>?
    private let sidePanelWidth: CGFloat = 340
    /// Caller-owned status between chart and cockpit. Empty in other modes.
    private let flightStatus: () -> FlightStatus
    private let flightStatusHeight: CGFloat

    /// Overrides what the NAV radios receive from, independent of the plane
    /// icon's own (draggable) position. Defaults to nil, so reception keeps
    /// reading `session.normalizedAircraftPosition` exactly as Free Flight
    /// always has. Position Challenge supplies the hidden target here, since
    /// its plane icon instead doubles as the player's freely-dragged guess.
    private let receptionPosition: CGPoint?

    init(session: FlightSession,
         configuration: FlightSurfaceConfiguration = .freeFlight,
         receptionPosition: CGPoint? = nil,
         sidePanelTitle: String = "Details",
         isSidePanelPresented: Binding<Bool>? = nil,
         flightStatusHeight: CGFloat = 0,
         cameraPolicy: ChartCameraPolicy = .standard,
         fitRequest: ChartFitRequest? = nil,
         @ViewBuilder sidePanel: @escaping () -> SidePanel = { EmptyView() },
         @ViewBuilder flightStatus: @escaping () -> FlightStatus = { EmptyView() },
         @ViewBuilder screenOverlay: @escaping (ChartViewport) -> ScreenOverlay = { _ in EmptyView() },
         @ViewBuilder chartOverlay: @escaping (CGRect) -> ChartOverlay = { _ in EmptyView() }) {
        _session = Bindable(session)
        self.configuration = configuration
        self.receptionPosition = receptionPosition
        self.sidePanelTitle = sidePanelTitle
        self.isSidePanelPresented = isSidePanelPresented
        self.sidePanel = sidePanel
        self.flightStatusHeight = flightStatusHeight
        self.flightStatus = flightStatus
        self.chartOverlay = chartOverlay
        self.screenOverlay = screenOverlay
        self.cameraPolicy = cameraPolicy
        self.fitRequest = fitRequest
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

    @State private var panStart: CGSize?

    private let compassRoseMinZoom: CGFloat = 2

    var body: some View {
        GeometryReader { geometry in
            let surfaceWidth = geometry.size.width
            let cockpitHeight = CockpitLayout.height(forWidth: surfaceWidth)
            let showsSidePanel = isSidePanelPresented?.wrappedValue == true
            let mapSize = CGSize(width: max(0, surfaceWidth - (showsSidePanel ? sidePanelWidth + 1 : 0)),
                                 height: max(0, geometry.size.height - cockpitHeight - flightStatusHeight))
            // The cropped map image is aspect-fit inside the map area, so
            // everything on the map is positioned relative to this fitted rect.
            let imageRect = FlatMap.fittedRect(in: mapSize, crop: cameraPolicy.crop)
            let planePos = point(for: session.normalizedAircraftPosition, in: imageRect)
            let nav1Reading = receiverReading(for: session.nav1)
            let nav2Reading = receiverReading(for: session.nav2)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    mapArea(mapSize: mapSize, imageRect: imageRect, planePos: planePos)

                    if showsSidePanel {
                        Divider()
                        ScrollView {
                            sidePanel()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                        }
                        // Keep the instructions below the persistent corner
                        // controls, even when the panel content is scrolled.
                        .padding(.top, 80)
                        .frame(width: sidePanelWidth, height: mapSize.height)
                        .background(Color(nsColor: .windowBackgroundColor))
                    }
                }
                .frame(height: mapSize.height)
                .overlay(alignment: .topTrailing) {
                    // The window's title bar sits on top of our
                    // ignoresSafeArea() content, so this needs more
                    // top clearance than a plain corner inset to stay
                    // fully clear of it.
                    HStack(spacing: 10) {
                        ChartButton(showVORs: $session.showVORs,
                                    visibleVORServiceVolumes: $session.visibleVORServiceVolumes,
                                    showAirports: $session.showAirports,
                                    showRadials: $session.showRadials,
                                    showGrid: $session.showGrid,
                                    showSightseeingRegions: $session.showSightseeingRegions,
                                    showSightseeingRegionNames: $session.showSightseeingRegionNames,
                                    gridSizeNM: $session.gridSizeNM)

                        if let isSidePanelPresented {
                            Button {
                                isSidePanelPresented.wrappedValue.toggle()
                            } label: {
                                Label("\(showsSidePanel ? "Hide" : "Show") \(sidePanelTitle)",
                                      systemImage: "sidebar.right")
                            }
                            .buttonStyle(.glass)
                            .help("\(showsSidePanel ? "Hide" : "Show") the \(sidePanelTitle.lowercased()) panel")
                        }
                    }
                    .padding(.top, 40)
                    .padding(.trailing, 16)
                }

                if flightStatusHeight > 0 {
                    flightStatus()
                        .frame(width: surfaceWidth, height: flightStatusHeight)
                }

                CockpitPanel(mapWidth: surfaceWidth, onSwap: { session.swapNAVReceivers() }) {
                    if configuration.showsHeadingPresentation {
                        PlaneControlView(heading: session.heading,
                                         selectedHeading: $session.selectedHeading,
                                         speedKnots: $session.speedKnots,
                                         isFlying: $session.isFlying,
                                         timeMultiplier: $session.timeMultiplier,
                                         showsFlightControls: configuration.showsFlightControls)
                            .disabled(session.completion != nil || session.simulationError != nil)
                    }
                } nav1: {
                    NavRadioView(
                        name: "NAV1",
                        receiver: $session.nav1,
                        stations: stations,
                        reading: nav1Reading.cdiReading,
                        normalizedAircraftPosition: receptionPosition ?? session.normalizedAircraftPosition,
                        mapWidthNM: FlatMap.widthNM,
                        mapHeightNM: FlatMap.heightNM
                    )
                    // Both radios have local ident-entry state. Give each a
                    // stable identity so SwiftUI never reuses one receiver's
                    // pending text while rendering the other receiver.
                    .id("nav1-radio")
                } nav2: {
                    NavRadioView(
                        name: "NAV2",
                        receiver: $session.nav2,
                        stations: stations,
                        reading: nav2Reading.cdiReading,
                        normalizedAircraftPosition: receptionPosition ?? session.normalizedAircraftPosition,
                        mapWidthNM: FlatMap.widthNM,
                        mapHeightNM: FlatMap.heightNM
                    )
                    .id("nav2-radio")
                }
            }
            // Re-clamp the pan whenever the zoom changes (e.g. via scroll) so
            // the map never drifts off the visible area.
            .onChange(of: session.zoom) {
                session.pan = clampedPan(session.pan, zoom: session.zoom, mapSize: mapSize)
            }
            .onChange(of: mapSize) {
                fitOrClamp(in: mapSize)
            }
            .onChange(of: fitRequest) {
                fitOrClamp(in: mapSize)
            }
            .onAppear {
                fitOrClamp(in: mapSize)
                session.showAirports = configuration.showsAirportsByDefault
                session.showSightseeingRegionNames = configuration.showsSightseeingRegionNamesByDefault
            }
        }
        .ignoresSafeArea()
    }

    /// The zoomable, pannable map. Only the artwork (and the caller's chart
    /// overlay, drawn in the same image-relative coordinates) scales with the
    /// camera; the markers and plane keep a constant screen size and are
    /// positioned by applying the same zoom/pan transform to their map
    /// coordinates (`screenPoint`).
    private func mapArea(mapSize: CGSize, imageRect: CGRect, planePos: CGPoint) -> some View {
        let viewport = viewport(in: mapSize)
        return ZStack {
            ZStack {
                FlatMap(imageRect: imageRect, crop: cameraPolicy.crop)
                    .frame(width: mapSize.width, height: mapSize.height)
                chartOverlay(imageRect)
            }
            .scaleEffect(session.zoom)
            .offset(session.pan)

            if session.showGrid {
                HexGridOverlay(hexHeightNM: session.gridSizeNM,
                               imageRect: imageRect,
                               mapSize: mapSize,
                               zoom: session.zoom,
                               pan: session.pan,
                               mapWidthNM: FlatMap.widthNM,
                               crop: cameraPolicy.crop)
            }

            if session.showSightseeingRegions {
                SightseeingCheckpointsOverlay(regions: sightseeingRegions,
                                              imageRect: imageRect,
                                              mapSize: mapSize,
                                              zoom: session.zoom,
                                              pan: session.pan,
                                              mapWidthNM: FlatMap.widthNM,
                                              crop: cameraPolicy.crop)
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

            if session.showSightseeingRegionNames {
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
            }

            if configuration.showsAircraftMarker {
                Group {
                    switch configuration.aircraftMarkerStyle {
                    case .aircraft: PlaneIcon(heading: session.heading)
                    case .positionEstimate: PositionEstimateMarker()
                    }
                }
                    .position(screenPoint(planePos, mapSize: mapSize))
                    // The plane's own drag wins over panning when the drag starts on it.
                    .highPriorityGesture(planeDrag(planePos: planePos, imageRect: imageRect))
            }

            screenOverlay(viewport)
                .frame(width: mapSize.width, height: mapSize.height)

            if configuration.allowsAircraftSimulation {
                FlightTimerView(session: session)
                    .id(ObjectIdentifier(session))
            }
        }
        .frame(width: mapSize.width, height: mapSize.height)
        .clipped()
        .contentShape(Rectangle())
        .gesture(panGesture(mapSize: mapSize))
        .coordinateSpace(name: mapSpace)
        .background(
            ScrollWheelReader { deltaY, location in
                applyZoomDelta(deltaY, anchoredAt: location, mapSize: mapSize)
            }
        )
    }

    private let mapSpace = ChartViewport.coordinateSpace

    /// The chart's horizontal scale, shared by reception math and flight movement.
    private func pixelsPerNM(in imageRect: CGRect) -> CGFloat {
        FlatMap.pixelsPerNM(in: imageRect, mapWidthNM: FlatMap.widthNM, crop: cameraPolicy.crop)
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
        viewport(in: mapSize).screenPoint(forMapPoint: p)
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
                    in: imageRect,
                    crop: cameraPolicy.crop
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
        cameraPolicy.clampedPan(proposed, zoom: zoom, size: mapSize)
    }

    /// Applies a scroll-wheel delta to the zoom, keeping the chart point under
    /// the pointer fixed in place. Positive delta (scroll up) zooms in.
    private func applyZoomDelta(_ deltaY: CGFloat, anchoredAt location: CGPoint, mapSize: CGSize) {
        // Preserve the original behavior for a large downward scroll: reach
        // the minimum rather than dropping an event with a nonpositive factor.
        let factor = max(cameraPolicy.zoomRange.lowerBound / session.zoom, 1 + deltaY * 0.08)
        let camera = viewport(in: mapSize).zoomed(by: factor, anchoredAt: location, policy: cameraPolicy)
        session.pan = camera.pan
        session.zoom = camera.zoom
    }

    private func viewport(in size: CGSize) -> ChartViewport {
        ChartViewport(size: size, crop: cameraPolicy.crop, zoom: session.zoom, pan: session.pan)
    }

    private func fitOrClamp(in size: CGSize) {
        if let fitRequest, let camera = viewport(in: size).fitting(fitRequest, policy: cameraPolicy) {
            session.zoom = camera.zoom
            session.pan = camera.pan
        } else {
            session.pan = clampedPan(session.pan, zoom: session.zoom, mapSize: size)
        }
    }

    private func receiverReading(for receiver: NAVReceiver) -> ReceiverReading {
        guard receiver.hasActiveFrequency else {
            return ReceiverReading(station: nil, cdiReading: .off)
        }

        return VORNavigation.receiverReading(
            frequencyHundredths: receiver.frequencyHundredths,
            obs: receiver.obs,
            normalizedAircraftPosition: receptionPosition ?? session.normalizedAircraftPosition,
            stations: stations,
            mapWidthNM: FlatMap.widthNM,
            mapHeightNM: FlatMap.heightNM,
            cdiMax: session.cdiMax
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
        FlatMap.point(for: relativePosition, in: rect, crop: cameraPolicy.crop)
    }

}

// MARK: - Cockpit

/// The cockpit's shared scale: its bays shrink together to 0.80× at the
/// enforced 1100×760 window minimum and grow together back to their natural
/// 1.00× size as the window widens, rather than reflowing into a narrower
/// arrangement below that size or growing without bound above it.
private enum CockpitLayout {
    static let baseWidth: CGFloat = 1075
    static let baseHeight: CGFloat = 350

    static func scale(forWidth width: CGFloat) -> CGFloat {
        min(max(width / baseWidth, 0.80), 1.00)
    }

    static func height(forWidth width: CGFloat) -> CGFloat {
        baseHeight * scale(forWidth: width)
    }
}

/// One continuous dark cockpit panel with three equal bays — Heading, NAV1,
/// NAV2 — separated by subtle dividers, so the cockpit reads as one
/// instrument panel rather than three separate dashboard cards.
private struct CockpitPanel<Heading: View, Nav1: View, Nav2: View>: View {
    let mapWidth: CGFloat
    let onSwap: () -> Void
    let heading: Heading
    let nav1: Nav1
    let nav2: Nav2

    init(mapWidth: CGFloat,
         onSwap: @escaping () -> Void,
         @ViewBuilder heading: () -> Heading,
         @ViewBuilder nav1: () -> Nav1,
         @ViewBuilder nav2: () -> Nav2) {
        self.mapWidth = mapWidth
        self.onSwap = onSwap
        self.heading = heading()
        self.nav1 = nav1()
        self.nav2 = nav2()
    }

    private var scale: CGFloat { CockpitLayout.scale(forWidth: mapWidth) }

    var body: some View {
        HStack(spacing: 0) {
            heading.frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider().overlay(ControlPalette.cockpitDivider)
            nav1.frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider().overlay(ControlPalette.cockpitDivider)
            swapControl
            Divider().overlay(ControlPalette.cockpitDivider)
            nav2.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(16)
        .frame(width: CockpitLayout.baseWidth, height: CockpitLayout.baseHeight)
        .background(ControlPalette.cockpitBackground)
        .scaleEffect(scale)
        .frame(width: mapWidth, height: CockpitLayout.baseHeight * scale)
    }

    /// The dedicated NAV1 ↔ NAV2 control: swaps complete receiver values only,
    /// with no other side effect.
    private var swapControl: some View {
        Button(action: onSwap) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(ControlPalette.cockpitText)
                .frame(width: 28, height: 28)
                .background(ControlPalette.cockpitFieldBackground, in: Circle())
                .overlay(Circle().stroke(ControlPalette.cockpitFieldBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .help("Swap NAV1 and NAV2 frequencies and OBS")
    }
}

/// Delivers monotonic timing only. The session owns all simulated movement.
private struct FlightTimerView: View {
    let session: FlightSession

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task(id: session.isFlying) { await runFlightLoop() }
    }

    private func runFlightLoop() async {
        guard session.isFlying else { return }
        let clock = ContinuousClock()
        var lastUpdate = clock.now
        while !Task.isCancelled && session.isFlying {
            do { try await clock.sleep(for: .milliseconds(16)) }
            catch { return }
            guard !Task.isCancelled && session.isFlying else { return }
            let now = clock.now
            let duration = lastUpdate.duration(to: now).components
            lastUpdate = now
            session.advance(wallElapsed: Double(duration.seconds) + Double(duration.attoseconds) / 1e18)
        }
    }
}

/// Bridges macOS mouse scroll-wheel events into SwiftUI. There is no first-party
/// modifier for scroll-wheel input on a plain view, so we install a local event
/// monitor and report the vertical delta when the pointer is over this view.
struct ScrollWheelReader: NSViewRepresentable {
    /// Called with the vertical scroll delta (positive = scroll up) and the
    /// pointer position in this view's top-left-origin coordinate space.
    var onScroll: (CGFloat, CGPoint) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = MonitorView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? MonitorView)?.onScroll = onScroll
    }

    final class MonitorView: NSView {
        var onScroll: ((CGFloat, CGPoint) -> Void)?
        private var monitor: Any?

        override var isFlipped: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard monitor == nil, window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, let window = self.window, event.window == window else { return event }
                // Only handle scrolls that land over the map area.
                let frame = self.convert(self.bounds, to: nil)
                guard frame.contains(event.locationInWindow) else { return event }
                let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY * 0.02 : event.deltaY
                self.onScroll?(delta, self.convert(event.locationInWindow, from: nil))
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
