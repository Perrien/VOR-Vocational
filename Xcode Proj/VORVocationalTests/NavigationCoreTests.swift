import XCTest
import CoreGraphics
import Foundation
@testable import VOR_Vocational

final class NavigationCoreTests: XCTestCase {
    func testAngleNormalization() {
        XCTAssertEqual(VORNavigation.normalize180(0), 0)
        XCTAssertEqual(VORNavigation.normalize180(360), 0)
        XCTAssertEqual(VORNavigation.normalize180(190), -170)
        XCTAssertEqual(VORNavigation.normalize180(-190), 170)
        XCTAssertEqual(VORNavigation.normalize180(540), 180)
        XCTAssertEqual(VORNavigation.normalize180(-540), -180)
    }

    func testCDIOnSelectedNorthSouthLine() {
        let fromReading = VORNavigation.cdiReading(
            planePosition: CGPoint(x: 0, y: -10),
            stationPosition: .zero,
            obs: 0,
            cdiMax: 10
        )
        let toReading = VORNavigation.cdiReading(
            planePosition: CGPoint(x: 0, y: 10),
            stationPosition: .zero,
            obs: 0,
            cdiMax: 10
        )

        assertReading(fromReading, flag: .from, deflection: 0)
        assertReading(toReading, flag: .to, deflection: 0)
    }

    func testCDINeedleDirection() {
        let rightOfCourse = VORNavigation.cdiReading(
            planePosition: CGPoint(x: 10, y: -10),
            stationPosition: .zero,
            obs: 0,
            cdiMax: 10
        )
        let leftOfCourse = VORNavigation.cdiReading(
            planePosition: CGPoint(x: -10, y: -10),
            stationPosition: .zero,
            obs: 0,
            cdiMax: 10
        )

        assertReading(rightOfCourse, flag: .from, deflection: -1)
        assertReading(leftOfCourse, flag: .from, deflection: 1)
    }

    func testMapDistance() {
        let pixelDistance = VORNavigation.distanceNM(
            from: .zero,
            to: CGPoint(x: 30, y: 40),
            pixelsPerNM: 10
        )
        let invalidScale = VORNavigation.distanceNM(
            from: .zero,
            to: CGPoint(x: 30, y: 40),
            pixelsPerNM: 0
        )
        let normalizedDistance = VORNavigation.distanceNM(
            fromNormalized: .zero,
            toNormalized: CGPoint(x: 0.06, y: 0.08),
            mapWidthNM: 500,
            mapHeightNM: 500
        )

        XCTAssertEqual(pixelDistance, 5, accuracy: 0.000_001)
        XCTAssertTrue(invalidScale.isInfinite)
        XCTAssertEqual(normalizedDistance, 50, accuracy: 0.000_001)
    }

    func testStationLookup() {
        let station = makeStation(identifier: "CTR")

        XCTAssertEqual(VORNavigation.station(withIdent: " ctr ", in: [station])?.identifier, "CTR")
        XCTAssertNil(VORNavigation.station(withIdent: "", in: [station]))
    }

    func testNAVReceiverWholeMHzClamps() {
        var receiver = NAVReceiver()
        receiver.adjustWhole(by: -1)
        XCTAssertEqual(receiver.wholeMHz, 108)

        receiver.adjustWhole(by: 20)
        XCTAssertEqual(receiver.wholeMHz, 117)
    }

    func testNAVReceiverFineStepWrapsWithoutCarry() {
        var receiver = NAVReceiver(wholeMHz: 116, fineStep: 19)
        receiver.adjustFine(by: 1)
        XCTAssertEqual(receiver.wholeMHz, 116)
        XCTAssertEqual(receiver.fineStep, 0)

        receiver.adjustFine(by: -1)
        XCTAssertEqual(receiver.wholeMHz, 116)
        XCTAssertEqual(receiver.fineStep, 19)
    }

    func testNAVReceiverFormatsFrequency() {
        let receiver = NAVReceiver(wholeMHz: 116, fineStep: 16)
        XCTAssertEqual(receiver.frequencyHundredths, 11680)
        XCTAssertEqual(receiver.frequencyLabel, "116.80")
    }

    func testStationLookupByFrequency() {
        let station = makeStation(identifier: "CTR")
        XCTAssertEqual(
            VORNavigation.station(withFrequencyHundredths: 11680, in: [station])?.identifier,
            "CTR"
        )
        XCTAssertNil(VORNavigation.station(withFrequencyHundredths: 10800, in: [station]))
    }

    func testFrequencyReceiverReadingRespectsRange() {
        let station = makeStation(identifier: "CTR")
        let inRange = VORNavigation.receiverReading(
            frequencyHundredths: 11680,
            obs: 0,
            normalizedAircraftPosition: CGPoint(x: 0.5, y: 0.6),
            stations: [station],
            mapWidthNM: 500,
            mapHeightNM: 500,
            cdiMax: 10
        )
        let outOfRange = VORNavigation.receiverReading(
            frequencyHundredths: 11680,
            obs: 0,
            normalizedAircraftPosition: .zero,
            stations: [station],
            mapWidthNM: 500,
            mapHeightNM: 500,
            cdiMax: 10
        )

        XCTAssertEqual(inRange.station?.identifier, "CTR")
        XCTAssertNil(outOfRange.station)
        assertReading(outOfRange.cdiReading, flag: .off, deflection: 0)
    }

    func testKnobTunedReceiverReceptionRespectsRange() {
        let station = makeStation(identifier: "CTR")
        var receiver = NAVReceiver()
        receiver.adjustWhole(by: 8)
        receiver.adjustFine(by: 16)
        XCTAssertEqual(receiver.frequencyHundredths, 11680)

        let inRange = VORNavigation.receiverReading(
            frequencyHundredths: receiver.frequencyHundredths,
            obs: receiver.obs,
            normalizedAircraftPosition: CGPoint(x: 0.5, y: 0.6),
            stations: [station],
            mapWidthNM: 500,
            mapHeightNM: 500,
            cdiMax: 10
        )
        let outOfRange = VORNavigation.receiverReading(
            frequencyHundredths: receiver.frequencyHundredths,
            obs: receiver.obs,
            normalizedAircraftPosition: .zero,
            stations: [station],
            mapWidthNM: 500,
            mapHeightNM: 500,
            cdiMax: 10
        )

        XCTAssertEqual(inRange.station?.identifier, "CTR")
        XCTAssertNil(outOfRange.station)
        assertReading(outOfRange.cdiReading, flag: .off, deflection: 0)
    }

    @MainActor
    func testFreshFlightSessionDefaults() {
        let position = CGPoint(x: 0.5067, y: 0.6889)
        let session = FlightSession(normalizedAirportPosition: position)

        assertPoint(session.normalizedAircraftPosition, equals: position)
        XCTAssertEqual(session.heading, 0)
        XCTAssertEqual(session.speedKnots, 260)
        XCTAssertFalse(session.isFlying)
        XCTAssertEqual(session.timeMultiplier, 1)
        XCTAssertEqual(session.elapsedSimulatedSeconds, 0)
        XCTAssertEqual(session.nav1, NAVReceiver())
        XCTAssertEqual(session.nav2, NAVReceiver())
        XCTAssertEqual(session.zoom, 1)
        XCTAssertEqual(session.pan, .zero)
        XCTAssertTrue(session.showVORs)
        XCTAssertEqual(session.visibleVORServiceVolumes, Set(VORServiceVolume.allCases))
        XCTAssertTrue(session.showAirports)
        XCTAssertTrue(session.showRadials)
        XCTAssertFalse(session.showGrid)
        XCTAssertFalse(session.showSightseeingRegions)
        XCTAssertTrue(session.showSightseeingRegionNames)
        XCTAssertEqual(session.gridSizeNM, 50)
    }

    @MainActor
    func testFlightSurfaceConfigurationPresets() {
        XCTAssertEqual(
            .freeFlight,
            FlightSurfaceConfiguration(
                showsAirportsByDefault: true,
                showsSightseeingRegionNamesByDefault: true,
                allowsAircraftSimulation: true,
                showsHeadingPresentation: true,
                showsFlightControls: true,
                showsAircraftMarker: true
            )
        )
        XCTAssertEqual(
            .positionChallenge,
            FlightSurfaceConfiguration(
                showsAirportsByDefault: false,
                showsSightseeingRegionNamesByDefault: false,
                allowsAircraftSimulation: false,
                showsHeadingPresentation: true,
                showsFlightControls: false,
                showsAircraftMarker: true
            )
        )
        XCTAssertEqual(
            .transportMission,
            FlightSurfaceConfiguration(
                showsAirportsByDefault: true,
                showsSightseeingRegionNamesByDefault: false,
                allowsAircraftSimulation: true,
                showsHeadingPresentation: true,
                showsFlightControls: true,
                showsAircraftMarker: false
            )
        )
    }

    @MainActor
    func testNAVReceiverSwap() {
        let session = FlightSession(normalizedAirportPosition: .zero)
        session.nav1 = NAVReceiver(wholeMHz: 116, fineStep: 16, obs: 45)
        session.nav2 = NAVReceiver(wholeMHz: 110, fineStep: 3, obs: 270)
        let position = session.normalizedAircraftPosition
        let heading = session.heading

        session.swapNAVReceivers()

        XCTAssertEqual(session.nav1, NAVReceiver(wholeMHz: 110, fineStep: 3, obs: 270))
        XCTAssertEqual(session.nav2, NAVReceiver(wholeMHz: 116, fineStep: 16, obs: 45))
        assertPoint(session.normalizedAircraftPosition, equals: position)
        XCTAssertEqual(session.heading, heading)
    }

    func testFlightAdvance() {
        let north = FlightPhysics.advance(
            position: CGPoint(x: 50, y: 50),
            heading: 0,
            speedKnots: 120,
            elapsed: 30,
            pixelsPerNM: 10,
            bounds: CGSize(width: 100, height: 100)
        )
        let east = FlightPhysics.advance(
            position: CGPoint(x: 50, y: 50),
            heading: 90,
            speedKnots: 120,
            elapsed: 30,
            pixelsPerNM: 10,
            bounds: CGSize(width: 100, height: 100)
        )
        let clamped = FlightPhysics.advance(
            position: CGPoint(x: 95, y: 95),
            heading: 90,
            speedKnots: 120,
            elapsed: 30,
            pixelsPerNM: 10,
            bounds: CGSize(width: 100, height: 100)
        )
        let stoppedBySpeed = FlightPhysics.advance(
            position: CGPoint(x: 50, y: 50),
            heading: 90,
            speedKnots: 0,
            elapsed: 30,
            pixelsPerNM: 10,
            bounds: CGSize(width: 100, height: 100)
        )
        let stoppedByScale = FlightPhysics.advance(
            position: CGPoint(x: 50, y: 50),
            heading: 90,
            speedKnots: 120,
            elapsed: 30,
            pixelsPerNM: 0,
            bounds: CGSize(width: 100, height: 100)
        )

        assertPoint(north, equals: CGPoint(x: 50, y: 40))
        assertPoint(east, equals: CGPoint(x: 60, y: 50))
        assertPoint(clamped, equals: CGPoint(x: 100, y: 95))
        assertPoint(stoppedBySpeed, equals: CGPoint(x: 50, y: 50))
        assertPoint(stoppedByScale, equals: CGPoint(x: 50, y: 50))
    }

    func testPositionChallenge() {
        let guess = CGPoint.zero
        let target = CGPoint(x: 30, y: 40)
        let result = PositionChallenge.score(
            guess: guess,
            target: target,
            pixelsPerNM: 10
        )
        let fallback = PositionChallenge.randomTarget(
            stations: [],
            mapWidthNM: 500,
            mapHeightNM: 500,
            maxAttempts: 0
        )
        let insetTarget = PositionChallenge.randomTarget(
            stations: [],
            mapWidthNM: 500,
            mapHeightNM: 500,
            minInRangeStations: 0,
            inset: 0.1,
            maxAttempts: 1
        )

        assertPoint(result.guess, equals: guess)
        assertPoint(result.target, equals: target)
        XCTAssertEqual(result.errorNM, 5, accuracy: 0.000_001)
        assertPoint(fallback, equals: CGPoint(x: 0.5, y: 0.5))
        XCTAssertGreaterThanOrEqual(insetTarget.x, 0.1)
        XCTAssertLessThanOrEqual(insetTarget.x, 0.9)
        XCTAssertGreaterThanOrEqual(insetTarget.y, 0.1)
        XCTAssertLessThanOrEqual(insetTarget.y, 0.9)
    }

    func testServiceVolumes() {
        XCTAssertEqual(VORServiceVolume.high.rangeNM, 100)
        XCTAssertEqual(VORServiceVolume.low.rangeNM, 40)
        XCTAssertEqual(VORServiceVolume.terminal.rangeNM, 25)
    }

    func testFlightPlanDecodesTaggedPointsAndTerminalReference() throws {
        let data = Data("""
        {
          "id": "example",
          "name": "Example plan",
          "origin": { "kind": "airport", "icao": "GPEX" },
          "waypoints": [
            { "kind": "vor", "stationID": "example-vor" },
            {
              "kind": "intersection",
              "radials": [
                { "stationID": "example-vor", "radialDegrees": 90 },
                { "stationID": "other-vor", "radialDegrees": 180 }
              ]
            }
          ],
          "destination": { "kind": "airport", "icao": "GPDX" },
          "terminalReference": { "stationID": "other-vor", "radialDegrees": 180 }
        }
        """.utf8)

        let plan = try JSONDecoder().decode(FlightPlan.self, from: data)

        XCTAssertEqual(plan.id, "example")
        XCTAssertEqual(plan.origin, .airport(icao: "GPEX"))
        XCTAssertEqual(plan.waypoints[0], .vor(stationID: "example-vor"))
        XCTAssertEqual(
            plan.waypoints[1],
            .intersection(radials: [
                RadialReference(stationID: "example-vor", radialDegrees: 90),
                RadialReference(stationID: "other-vor", radialDegrees: 180),
            ])
        )
        XCTAssertEqual(plan.terminalReference, RadialReference(stationID: "other-vor", radialDegrees: 180))
    }

    func testFlightPlanResolverDerivesAirportToVORGuidance() throws {
        let airport = makeAirport(icao: "GPEX", x: 0.2, y: 0.5)
        let station = makeStation(identifier: "EAS", x: 0.4, y: 0.5)
        let plan = FlightPlan(
            id: "eastbound",
            name: "Eastbound",
            origin: .airport(icao: "GPEX"),
            waypoints: [],
            destination: .vor(stationID: "EAS"),
            terminalReference: nil
        )

        let resolved = try FlightPlanResolver.resolve(
            plan,
            airports: [airport],
            stations: [station],
            mapWidthNM: 500,
            mapHeightNM: 500,
            cruiseSpeedKnots: 100
        )

        XCTAssertEqual(resolved.legs.count, 1)
        XCTAssertEqual(resolved.legs[0].distanceNM, 100, accuracy: 0.000_001)
        XCTAssertEqual(resolved.legs[0].guidance?.stationIdent, "EAS")
        XCTAssertEqual(resolved.legs[0].guidance?.obsDegrees, 90)
        XCTAssertEqual(resolved.legs[0].guidance?.flag, .to)
        XCTAssertEqual(resolved.stillAirEstimate.durationSeconds, 3_600, accuracy: 0.000_001)
    }

    func testFlightPlanResolverDerivesVORIntersectionGuidance() throws {
        let first = makeStation(identifier: "ONE", x: 0.2, y: 0.2)
        let second = makeStation(identifier: "TWO", x: 0.6, y: 0.6)
        let intersection = PlanPoint.intersection(radials: [
            RadialReference(stationID: "ONE", radialDegrees: 90),
            RadialReference(stationID: "TWO", radialDegrees: 0),
        ])
        let plan = FlightPlan(
            id: "intersection",
            name: "Intersection",
            origin: .vor(stationID: "ONE"),
            waypoints: [intersection],
            destination: .vor(stationID: "TWO"),
            terminalReference: nil
        )

        let resolved = try FlightPlanResolver.resolve(
            plan,
            airports: [],
            stations: [first, second],
            mapWidthNM: 200,
            mapHeightNM: 200,
            cruiseSpeedKnots: 100
        )

        assertPoint(resolved.points[1].normalizedPosition, equals: CGPoint(x: 0.6, y: 0.2))
        XCTAssertEqual(resolved.legs[0].guidance?.stationIdent, "ONE")
        XCTAssertEqual(resolved.legs[0].guidance?.obsDegrees, 90)
        XCTAssertEqual(resolved.legs[0].guidance?.flag, .from)
        XCTAssertEqual(resolved.legs[1].guidance?.stationIdent, "TWO")
        XCTAssertEqual(resolved.legs[1].guidance?.obsDegrees, 180)
        XCTAssertEqual(resolved.legs[1].guidance?.flag, .to)
    }

    func testFlightPlanResolverRejectsInvalidAuthoring() {
        let station = makeStation(identifier: "ONE", x: 0.2, y: 0.2)
        let invalidIntersection = FlightPlan(
            id: "invalid",
            name: "Invalid",
            origin: .vor(stationID: "ONE"),
            waypoints: [.intersection(radials: [
                RadialReference(stationID: "ONE", radialDegrees: 90),
                RadialReference(stationID: "ONE", radialDegrees: 180),
            ])],
            destination: .vor(stationID: "ONE"),
            terminalReference: nil
        )

        XCTAssertThrowsError(
            try FlightPlanResolver.resolve(
                invalidIntersection,
                airports: [],
                stations: [station],
                mapWidthNM: 500,
                mapHeightNM: 500,
                cruiseSpeedKnots: 100
            )
        ) { error in
            XCTAssertEqual(error as? FlightPlanResolver.ValidationError,
                           .duplicateIntersectionStations("ONE"))
        }

        let unknownAirport = FlightPlan(
            id: "unknown-airport",
            name: "Unknown airport",
            origin: .airport(icao: "GPXX"),
            waypoints: [],
            destination: .vor(stationID: "ONE"),
            terminalReference: nil
        )
        XCTAssertThrowsError(
            try FlightPlanResolver.resolve(
                unknownAirport,
                airports: [],
                stations: [station],
                mapWidthNM: 500,
                mapHeightNM: 500,
                cruiseSpeedKnots: 100
            )
        ) { error in
            XCTAssertEqual(error as? FlightPlanResolver.ValidationError, .unknownAirport("GPXX"))
        }
    }

    func testSilverkeepToMidlandPlanLoadsAndResolves() throws {
        let plan = try FlightPlanCatalog.load(named: "SilverkeepToMidland")
        let resolved = try FlightPlanResolver.resolve(
            plan,
            airports: Airport.myosia,
            stations: VORStation.myosia,
            mapWidthNM: 500,
            mapHeightNM: 500 / (1748.0 / 1254.0),
            cruiseSpeedKnots: 260
        )

        XCTAssertEqual(plan.id, "silverkeep-to-midland")
        XCTAssertEqual(resolved.points.count, 6)
        XCTAssertEqual(resolved.legs.count, 5)
        assertPoint(resolved.points[2].normalizedPosition,
                    equals: CGPoint(x: 0.4211612647, y: 0.6804788797),
                    accuracy: 0.000_001)
        assertPoint(resolved.points[4].normalizedPosition,
                    equals: CGPoint(x: 0.5064072813, y: 0.6892128515),
                    accuracy: 0.000_001)
        XCTAssertEqual(resolved.totalDistanceNM, 99.18027355, accuracy: 0.000_001)
        XCTAssertEqual(resolved.stillAirEstimate.durationSeconds, 1_373.2653260866, accuracy: 0.000_001)

        assertGuidance(resolved.legs[0].guidance,
                       ident: "MSB", frequencyMHz: 117.15, obsDegrees: 103, flag: .to)
        assertGuidance(resolved.legs[1].guidance,
                       ident: "MSB", frequencyMHz: 117.15, obsDegrees: 154, flag: .from)
        assertGuidance(resolved.legs[2].guidance,
                       ident: "MFD", frequencyMHz: 116.25, obsDegrees: 106, flag: .to)
        assertGuidance(resolved.legs[3].guidance,
                       ident: "MFD", frequencyMHz: 116.25, obsDegrees: 78, flag: .from)
        XCTAssertNil(resolved.legs[4].guidance)
        assertGuidance(resolved.terminalReference,
                       ident: "ELS", frequencyMHz: 112, obsDegrees: 353, flag: .from)
    }

    func testSilverkeepToMidlandBriefingSeparatesTerminalReference() throws {
        let plan = try FlightPlanCatalog.load(named: "SilverkeepToMidland")
        let resolved = try FlightPlanResolver.resolve(
            plan,
            airports: Airport.myosia,
            stations: VORStation.myosia,
            mapWidthNM: 500,
            mapHeightNM: 500 / (1748.0 / 1254.0),
            cruiseSpeedKnots: 260
        )

        let briefing = FlightPlanBriefing(resolvedPlan: resolved)

        XCTAssertEqual(briefing.planName, "Silverkeep to Midland")
        XCTAssertEqual(briefing.originName, "Silverkeep Strip")
        XCTAssertEqual(briefing.destinationName, "Midland Cityport")
        XCTAssertEqual(briefing.totalDistanceNM, 99.18027355, accuracy: 0.000_001)
        XCTAssertEqual(briefing.stillAirEstimate.durationSeconds, 1_373.2653260866, accuracy: 0.000_001)
        XCTAssertEqual(briefing.steps.map(\.kind), [.leg, .leg, .leg, .leg, .terminalReference])

        XCTAssertEqual(briefing.steps[0].title, "Silverkeep Strip to Mossbarrow")
        XCTAssertEqual(briefing.steps[0].distanceNM ?? .nan,
                       resolved.legs[0].distanceNM,
                       accuracy: 0.000_001)
        assertGuidance(briefing.steps[0].guidance,
                       ident: "MSB", frequencyMHz: 117.15, obsDegrees: 103, flag: .to)
        XCTAssertEqual(briefing.steps[1].title, "Mossbarrow to VOR radial intersection")
        assertGuidance(briefing.steps[1].guidance,
                       ident: "MSB", frequencyMHz: 117.15, obsDegrees: 154, flag: .from)
        XCTAssertEqual(briefing.steps[2].title, "VOR radial intersection to Marrowfield")
        assertGuidance(briefing.steps[2].guidance,
                       ident: "MFD", frequencyMHz: 116.25, obsDegrees: 106, flag: .to)
        XCTAssertEqual(briefing.steps[3].title, "Marrowfield to VOR radial intersection")
        assertGuidance(briefing.steps[3].guidance,
                       ident: "MFD", frequencyMHz: 116.25, obsDegrees: 78, flag: .from)

        let terminalStep = briefing.steps[4]
        XCTAssertEqual(terminalStep.title, "Final position reference near Midland Cityport")
        XCTAssertNil(terminalStep.distanceNM)
        assertGuidance(terminalStep.guidance,
                       ident: "ELS", frequencyMHz: 112, obsDegrees: 353, flag: .from)
    }

    func testMissionFlightProgressRequiresExplicitAdvance() {
        var progress = MissionFlightProgress(instructionCount: 5)

        XCTAssertEqual(progress.activeInstructionIndex, 0)
        XCTAssertEqual(progress.activeInstructionNumber, 1)
        XCTAssertTrue(progress.canAdvance)

        for expectedIndex in 1...4 {
            XCTAssertTrue(progress.advanceInstruction())
            XCTAssertEqual(progress.activeInstructionIndex, expectedIndex)
            XCTAssertEqual(progress.activeInstructionNumber, expectedIndex + 1)
        }

        XCTAssertFalse(progress.canAdvance)
        XCTAssertFalse(progress.advanceInstruction())
        XCTAssertEqual(progress.activeInstructionIndex, 4)
    }

    func testMissionFlightCompletionMeasuresRawDistanceFromDestination() throws {
        let plan = try FlightPlanCatalog.load(named: "SilverkeepToMidland")
        let resolved = try FlightPlanResolver.resolve(
            plan,
            airports: Airport.myosia,
            stations: VORStation.myosia,
            mapWidthNM: FlatMap.widthNM,
            mapHeightNM: FlatMap.heightNM,
            cruiseSpeedKnots: 260
        )
        let destination = try XCTUnwrap(resolved.points.last)

        let atDestination = MissionFlightCompletion(
            resolvedPlan: resolved,
            aircraftPosition: destination.normalizedPosition,
            simulatedElapsedSeconds: 321,
            mapWidthNM: FlatMap.widthNM,
            mapHeightNM: FlatMap.heightNM
        )
        let fiftyNMWest = MissionFlightCompletion(
            resolvedPlan: resolved,
            aircraftPosition: CGPoint(x: destination.normalizedPosition.x - 0.1,
                                      y: destination.normalizedPosition.y),
            simulatedElapsedSeconds: 654,
            mapWidthNM: FlatMap.widthNM,
            mapHeightNM: FlatMap.heightNM
        )

        XCTAssertEqual(atDestination.simulatedElapsedSeconds, 321)
        XCTAssertEqual(atDestination.distanceFromDestinationNM, 0, accuracy: 0.000_001)
        XCTAssertEqual(fiftyNMWest.simulatedElapsedSeconds, 654)
        XCTAssertEqual(fiftyNMWest.distanceFromDestinationNM, 50, accuracy: 0.000_001)
    }

    func testFlightPlanCatalogNamesMissingBundleResource() {
        XCTAssertThrowsError(try FlightPlanCatalog.load(named: "NoSuchPlan")) { error in
            XCTAssertEqual(error as? FlightPlanCatalog.CatalogError, .resourceNotFound("NoSuchPlan"))
        }
    }

    private func makeStation(identifier: String, x: Double = 0.5, y: Double = 0.5) -> VORStation {
        VORStation(
            id: identifier,
            name: "Test Station",
            identifier: identifier,
            frequency: 116.8,
            location: VORStation.Location(x: x, y: y),
            type: .vor,
            serviceVolume: .high,
            elevationFT: 100,
            dme: false
        )
    }

    private func makeAirport(icao: String, x: Double, y: Double) -> Airport {
        Airport(name: "Test Airport", icao: icao, size: .small, x: x, y: y)
    }

    private func assertReading(
        _ reading: CDIReading,
        flag expectedFlag: CDIReading.Flag,
        deflection expectedDeflection: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        switch (reading.flag, expectedFlag) {
        case (.to, .to), (.from, .from), (.off, .off):
            break
        default:
            XCTFail("Unexpected CDI flag", file: file, line: line)
        }
        XCTAssertEqual(reading.deflection, expectedDeflection, accuracy: 0.000_001, file: file, line: line)
    }

    private func assertPoint(
        _ point: CGPoint,
        equals expected: CGPoint,
        accuracy: CGFloat = 0.000_001,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(point.x, expected.x, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(point.y, expected.y, accuracy: accuracy, file: file, line: line)
    }

    private func assertGuidance(
        _ guidance: VORGuidance?,
        ident: String,
        frequencyMHz: Double,
        obsDegrees: Int,
        flag: VORGuidance.Flag,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let guidance else {
            XCTFail("Expected VOR guidance for \(ident)", file: file, line: line)
            return
        }
        XCTAssertEqual(guidance.stationIdent, ident, file: file, line: line)
        XCTAssertEqual(guidance.frequencyMHz, frequencyMHz, accuracy: 0.000_001, file: file, line: line)
        XCTAssertEqual(guidance.obsDegrees, obsDegrees, file: file, line: line)
        XCTAssertEqual(guidance.flag, flag, file: file, line: line)
    }
}
