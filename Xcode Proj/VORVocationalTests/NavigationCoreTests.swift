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

    func testNAVReceiverClearingFrequencyDisablesItsReadoutUntilRetuned() {
        var receiver = NAVReceiver(wholeMHz: 116, fineStep: 16)

        receiver.clearFrequency()

        XCTAssertFalse(receiver.hasActiveFrequency)
        XCTAssertEqual(receiver.frequencyLabel, "---.--")

        receiver.tune(toFrequencyHundredths: 11450)

        XCTAssertTrue(receiver.hasActiveFrequency)
        XCTAssertEqual(receiver.frequencyLabel, "114.50")
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
        XCTAssertEqual(session.selectedHeading, 0)
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
        XCTAssertFalse(session.showSightseeingRegionNames)
        XCTAssertEqual(session.gridSizeNM, 50)
    }

    @MainActor
    func testFlightSurfaceConfigurationPresets() {
        XCTAssertEqual(
            .freeFlight,
            FlightSurfaceConfiguration(
                showsAirportsByDefault: true,
                showsSightseeingRegionNamesByDefault: false,
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

    func testFlightTurnMovesTowardSelectedHeadingAtBoundedRate() {
        XCTAssertEqual(
            FlightPhysics.turn(heading: 0, toward: 90, elapsed: 2),
            6,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            FlightPhysics.turn(heading: 358, toward: 2, elapsed: 1),
            1,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            FlightPhysics.turn(heading: 2, toward: 358, elapsed: 1),
            359,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            FlightPhysics.turn(heading: 350, toward: 2, elapsed: 10),
            2,
            accuracy: 0.000_001
        )
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

    func testTransportTimingIncludesEveryGeometricLegAndPreservesInstructions() throws {
        let resolved = try FlightPlanResolver.resolve(
            FlightPlanCatalog.load(named: "SilverkeepToMidland"),
            airports: Airport.myosia, stations: VORStation.myosia,
            mapWidthNM: 500, mapHeightNM: 500 / (1748.0 / 1254.0), cruiseSpeedKnots: 260)
        let briefing = FlightPlanBriefing(resolvedPlan: resolved)
        let mission = MissionFlightDefinition(resolvedPlan: resolved)
        let schedule = try XCTUnwrap(mission.timingSchedule)
        let legs = try XCTUnwrap(schedule.legs)

        XCTAssertEqual(schedule, briefing.timingSchedule)
        XCTAssertEqual(schedule.planningAirspeedKnots, mission.initialState.speedKnots)
        XCTAssertEqual(schedule.startupPolicy, .firstLegOnFirstPlay)
        XCTAssertEqual(legs.count, 5)
        XCTAssertEqual(legs.map(\.id), [0, 1, 2, 3, 4])
        XCTAssertEqual(legs.map(\.distanceNM), resolved.legs.map(\.distanceNM))
        XCTAssertEqual(legs.reduce(0) { $0 + $1.distanceNM }, 99.18027355, accuracy: 0.000_001)
        let durationSum = legs.reduce(0) { $0 + $1.plannedDurationSeconds }
        XCTAssertEqual(durationSum, 1_373.2653260866, accuracy: 0.000_001)
        XCTAssertEqual(try XCTUnwrap(legs.last).plannedReachSeconds, durationSum, accuracy: 0.000_001)
        XCTAssertEqual(legs[4].startLabel, resolved.points[4].name)
        XCTAssertEqual(legs[4].endLabel, "Midland Cityport")
        XCTAssertNil(resolved.legs[4].guidance)
        XCTAssertEqual(briefing.steps.map(\.kind), [.leg, .leg, .leg, .leg, .terminalReference])
        XCTAssertEqual(mission.instructions.map(\.guidance), briefing.steps.map { Optional($0.guidance) })
        XCTAssertNil(briefing.steps[4].distanceNM)
        assertGuidance(mission.instructions[4].guidance,
                       ident: "ELS", frequencyMHz: 112, obsDegrees: 353, flag: .from)
    }

    func testIndependentTimingScheduleUsesUnroundedDurationsAndOrdinalIdentity() throws {
        let schedule = MissionTimingSchedule(legs: [
            .init(startLabel: "Repeated fix", endLabel: "Repeated fix", distanceNM: 20),
            .init(startLabel: "Repeated fix", endLabel: "Repeated fix", distanceNM: 4),
            .init(startLabel: "Repeated fix", endLabel: "Repeated fix", distanceNM: 0.02),
            .init(startLabel: "Repeated fix", endLabel: "Repeated fix", distanceNM: 0.02)
        ], planningAirspeedKnots: 120)
        let legs = try XCTUnwrap(schedule.legs)
        XCTAssertEqual(schedule.startupPolicy, .manual)
        XCTAssertEqual(legs.map(\.number), [1, 2, 3, 4])
        XCTAssertEqual(Set(legs.map(\.id)).count, 4)
        for (leg, duration) in zip(legs, [600.0, 120, 0.6, 0.6]) {
            XCTAssertEqual(leg.plannedDurationSeconds, duration, accuracy: 0.000_001)
        }
        for (leg, reach) in zip(legs, [600.0, 720, 720.6, 721.2]) {
            XCTAssertEqual(leg.plannedReachSeconds, reach, accuracy: 0.000_001)
        }
        XCTAssertEqual(MissionTimingFormat.duration(legs[3].plannedReachSeconds), "12:01")
        // Tiny positive distances remain valid; timing adds no resolver threshold.
        let tiny = MissionTimingSchedule(legs: [
            .init(startLabel: "A", endLabel: "B", distanceNM: 0.000_000_1)
        ], planningAirspeedKnots: 120)
        XCTAssertGreaterThan(try XCTUnwrap(tiny.legs?.first).plannedDurationSeconds, 0)
    }

    func testTransportInstructionsPresentTimingOnceWithoutInventingReferenceDistance() throws {
        let resolved = try FlightPlanResolver.resolve(
            FlightPlanCatalog.load(named: "SilverkeepToMidland"),
            airports: Airport.myosia, stations: VORStation.myosia,
            mapWidthNM: 500, mapHeightNM: 500 / (1748.0 / 1254.0), cruiseSpeedKnots: 260)
        let briefing = FlightPlanBriefing(resolvedPlan: resolved)
        let mission = MissionFlightDefinition(resolvedPlan: resolved)
        XCTAssertEqual(briefing.instructions, mission.instructions)
        XCTAssertEqual(mission.instructions.map(\.timingLegIndex), [0, 1, 2, 3, 4])
        let items = MissionInstructionItem.items(instructions: mission.instructions, schedule: mission.timingSchedule)
        XCTAssertEqual(items.count, 5)
        XCTAssertEqual(items.compactMap(\.instructionIndex), [0, 1, 2, 3, 4])
        XCTAssertEqual(items.compactMap { $0.timingLeg?.index }, [0, 1, 2, 3, 4])
        XCTAssertNil(briefing.steps[4].distanceNM)
        XCTAssertEqual(briefing.steps[4].kind, .terminalReference)
        XCTAssertNotNil(mission.instructions[4].timingDetail)
        XCTAssertEqual(items[4].timingLeg?.endLabel, "Midland Cityport")
        XCTAssertEqual(try XCTUnwrap(items[4].timingLeg).distanceNM, resolved.legs[4].distanceNM, accuracy: 1e-6)
        assertGuidance(mission.instructions[4].guidance,
                       ident: "ELS", frequencyMHz: 112, obsDegrees: 353, flag: .from)
    }

    func testInstructionTimingAssociationsDoNotInferPairsOrDuplicateLegs() throws {
        let schedule = MissionTimingSchedule(legs: [
            .init(startLabel: "Same label", endLabel: "Same label", distanceNM: 20),
            .init(startLabel: "Same label", endLabel: "Same label", distanceNM: 4),
            .init(startLabel: "Same label", endLabel: "Same label", distanceNM: 2)
        ], planningAirspeedKnots: 120)
        let unassociated = (0..<3).map { _ in MissionInstruction(title: "Same label") }
        let separate = MissionInstructionItem.items(instructions: unassociated, schedule: schedule)
        XCTAssertEqual(separate.count, 6) // Equal counts/names provide no association.
        XCTAssertTrue(separate.prefix(3).allSatisfy { $0.timingLeg == nil })
        let instructions = [
            MissionInstruction(title: "A non-travel setup instruction"),
            MissionInstruction(title: "An explicit later-leg instruction", timingLegIndex: 2),
            MissionInstruction(title: "Another cue for the same leg", timingLegIndex: 2),
            MissionInstruction(title: "Invalid association", timingLegIndex: -1),
            MissionInstruction(title: "Out-of-range association", timingLegIndex: 99)
        ]
        let items = MissionInstructionItem.items(instructions: instructions, schedule: schedule)
        XCTAssertEqual(items.compactMap(\.instructionIndex), Array(0..<5))
        XCTAssertEqual(items.compactMap { $0.timingLeg?.index }, [2, 0, 1])
        XCTAssertNil(items[2].timingLeg)
        XCTAssertEqual(items.filter { $0.instructionIndex == nil }.count, 2)
        XCTAssertEqual(Set(items.map(\.id)).count, items.count)
    }

    func testCombinedInstructionsPreserveUntimedAndUnavailableMissions() {
        let instructions = [MissionInstruction(title: "Setup"),
                            MissionInstruction(title: "Navigate", timingLegIndex: 0)]
        for schedule in [nil, MissionTimingSchedule(legs: [], planningAirspeedKnots: 120)] {
            let items = MissionInstructionItem.items(instructions: instructions, schedule: schedule)
            XCTAssertEqual(items.count, 2)
            XCTAssertEqual(items.compactMap(\.instructionIndex), [0, 1])
            XCTAssertTrue(items.allSatisfy { $0.timingLeg == nil })
        }
    }

    func testCombinedInstructionsRetainAnUnguidedFinalLegWithoutAddingACheckbox() throws {
        let supplied = try FlightPlanCatalog.load(named: "SilverkeepToMidland")
        let withoutReference = FlightPlan(id: "in-memory-no-reference", name: "No terminal reference",
            origin: supplied.origin, waypoints: supplied.waypoints, destination: supplied.destination,
            terminalReference: nil)
        let resolved = try FlightPlanResolver.resolve(withoutReference,
            airports: Airport.myosia, stations: VORStation.myosia,
            mapWidthNM: 500, mapHeightNM: 500 / (1748.0 / 1254.0), cruiseSpeedKnots: 260)
        let mission = MissionFlightDefinition(resolvedPlan: resolved)
        let items = MissionInstructionItem.items(instructions: mission.instructions, schedule: mission.timingSchedule)
        XCTAssertEqual(mission.instructions.count, 4)
        XCTAssertEqual(items.count, 5)
        XCTAssertEqual(items.compactMap(\.instructionIndex), [0, 1, 2, 3])
        XCTAssertNil(items.last?.instructionIndex)
        XCTAssertEqual(items.last?.timingLeg?.index, 4)
        XCTAssertEqual(items.last?.timingLeg?.endLabel, "Midland Cityport")
    }

    func testInMemoryRouteAt120KnotsHasTimingWithoutTerminalReference() throws {
        let plan = FlightPlan(id: "twenty-nm", name: "Synthetic route", origin: .airport(icao: "GNEW"),
                              waypoints: [], destination: .vor(stationID: "NEW"), terminalReference: nil)
        let resolved = try FlightPlanResolver.resolve(plan,
            airports: [makeAirport(icao: "GNEW", x: 0.2, y: 0.5)],
            stations: [makeStation(identifier: "NEW", x: 0.24, y: 0.5)],
            mapWidthNM: 500, mapHeightNM: 500, cruiseSpeedKnots: 120)
        let briefing = FlightPlanBriefing(resolvedPlan: resolved)
        let mission = MissionFlightDefinition(resolvedPlan: resolved)
        let leg = try XCTUnwrap(mission.timingSchedule?.legs?.first)
        XCTAssertEqual(leg.distanceNM, 20, accuracy: 0.000_001)
        XCTAssertEqual(leg.plannedDurationSeconds, 600, accuracy: 0.000_001)
        XCTAssertEqual(leg.plannedReachSeconds, 600, accuracy: 0.000_001)
        XCTAssertEqual(briefing.steps.map(\.kind), [.leg])
        XCTAssertEqual(mission.timingSchedule, briefing.timingSchedule)
        XCTAssertEqual(mission.initialState.speedKnots, 120)
    }

    func testTimingValidationNeverPublishesPartialOrInvalidSchedule() {
        let valid = MissionTimingSchedule.LegInput(startLabel: "A", endLabel: "B", distanceNM: 20)
        XCTAssertEqual(MissionTimingSchedule(legs: [], planningAirspeedKnots: 120).availability,
                       .unavailable(.emptyLegs))
        for speed in [0, -1, Double.nan, .infinity, -.infinity] {
            let schedule = MissionTimingSchedule(legs: [valid], planningAirspeedKnots: speed)
            XCTAssertEqual(schedule.availability, .unavailable(.invalidPlanningAirspeed))
            XCTAssertNil(schedule.legs)
        }
        for distance in [0, -1, Double.nan, .infinity, -.infinity] {
            let schedule = MissionTimingSchedule(legs: [valid,
                .init(startLabel: "B", endLabel: "C", distanceNM: distance)
            ], planningAirspeedKnots: 120)
            XCTAssertEqual(schedule.availability, .unavailable(.invalidDistance(legNumber: 2)))
            XCTAssertNil(schedule.legs)
        }
        let overflow = MissionTimingSchedule(legs: [
            .init(startLabel: "A", endLabel: "B", distanceNM: .greatestFiniteMagnitude)
        ], planningAirspeedKnots: 1)
        XCTAssertEqual(overflow.availability, .unavailable(.invalidDuration(legNumber: 1)))
        let underflow = MissionTimingSchedule(legs: [
            .init(startLabel: "A", endLabel: "B", distanceNM: .leastNonzeroMagnitude)
        ], planningAirspeedKnots: .greatestFiniteMagnitude)
        XCTAssertEqual(underflow.availability, .unavailable(.invalidDuration(legNumber: 1)))
        let cumulativeOverflow = MissionTimingSchedule(legs: [
            .init(startLabel: "A", endLabel: "B", distanceNM: 1e308),
            .init(startLabel: "B", endLabel: "C", distanceNM: 1e308)
        ], planningAirspeedKnots: 3_600)
        XCTAssertEqual(cumulativeOverflow.availability, .unavailable(.nonFiniteCumulativeTime(legNumber: 2)))
        XCTAssertNil(cumulativeOverflow.legs)
    }

    @MainActor
    func testAbsentAndInvalidTimingDoNotPreventOrdinaryMissionFlight() throws {
        let initial = FlightAircraftState(normalizedPosition: CGPoint(x: 0.5, y: 0.5), speedKnots: 120)
        let points = [MissionChartPoint(name: "A", normalizedPosition: CGPoint(x: 0.2, y: 0.5)),
                      MissionChartPoint(name: "B", normalizedPosition: CGPoint(x: 0.3, y: 0.5))]
        let instructions = [MissionInstruction(title: "Find a fix")]
        let absent = MissionFlightDefinition(id: "absent", title: "Absent timing", initialState: initial,
                                            plannedPoints: points, instructions: instructions)
        let invalid = MissionFlightDefinition(id: "invalid", title: "Invalid timing", initialState: initial,
            plannedPoints: points, instructions: instructions,
            timingSchedule: MissionTimingSchedule(legs: [], planningAirspeedKnots: 120))
        XCTAssertNil(absent.timingSchedule)
        XCTAssertEqual(invalid.timingSchedule?.availability, .unavailable(.emptyLegs))
        let a = FlightSession(mission: absent, conditions: .calm)
        let b = FlightSession(mission: invalid, conditions: .calm)
        for session in [a, b] {
            session.isFlying = true
            session.advance(wallElapsed: 60)
            XCTAssertNil(session.simulationError)
        }
        XCTAssertEqual(a.aircraftState, b.aircraftState)
        XCTAssertEqual(a.recording, b.recording)
        let completion = try XCTUnwrap(b.completeMission())
        XCTAssertEqual(completion.simulatedElapsedSeconds, 60)
        XCTAssertEqual(completion.mission.instructions, instructions)
        XCTAssertEqual(completion.mission.timingSchedule, invalid.timingSchedule)
    }

    @MainActor
    func testPlanningScheduleStaysFixedAcrossWindAndCockpitSpeedChanges() throws {
        let resolved = try FlightPlanResolver.resolve(
            FlightPlanCatalog.load(named: "SilverkeepToMidland"),
            airports: Airport.myosia, stations: VORStation.myosia,
            mapWidthNM: 500, mapHeightNM: 500 / (1748.0 / 1254.0), cruiseSpeedKnots: 260)
        let mission = MissionFlightDefinition(resolvedPlan: resolved)
        let original = try XCTUnwrap(mission.timingSchedule)
        var draft = MissionWindSetup()
        let calm = try XCTUnwrap(draft.conditions)
        draft.select(.steady)
        draft.directionText = "270"
        draft.speedText = "25"
        let windy = try XCTUnwrap(draft.conditions)
        XCTAssertNotEqual(calm, windy)
        for conditions in [calm, windy] {
            let session = FlightSession(mission: mission, conditions: conditions)
            session.speedKnots = 120
            session.isFlying = true
            session.advance(wallElapsed: 60)
            XCTAssertEqual(session.mission?.timingSchedule, original)
            XCTAssertEqual(session.freshMissionSession().mission?.timingSchedule, original)
        }
        draft.select(.calm)
        XCTAssertEqual(draft.conditions, calm)
        XCTAssertEqual(FlightPlanBriefing(resolvedPlan: resolved).timingSchedule, original)
    }

    func testTimingFormattingRoundsOnlyForPresentation() {
        XCTAssertEqual(MissionTimingFormat.duration(59.49), "0:59")
        XCTAssertEqual(MissionTimingFormat.duration(59.5), "1:00")
        XCTAssertEqual(MissionTimingFormat.duration(3_599.5), "1:00:00")
        XCTAssertEqual(MissionTimingFormat.duration(3_661), "1:01:01")
        XCTAssertEqual(MissionTimingFormat.duration(0.01, rounding: .up), "0:01")
        XCTAssertEqual(MissionTimingFormat.duration(59.99, rounding: .down), "0:59")
        XCTAssertEqual(MissionTimingFormat.duration(0), "0:00")
        for invalid in [Double.nan, .infinity, -.infinity, -1] {
            XCTAssertEqual(MissionTimingFormat.duration(invalid), "Timing unavailable")
        }
        XCTAssertFalse(MissionTimingFormat.duration(.greatestFiniteMagnitude).isEmpty)
    }

    @MainActor
    func testLiveTimingUsesPiecewiseAirspeedAndRetainsExactExpiry() throws {
        let session = FlightSession(mission: makeTimingMission(), conditions: .calm)
        let schedule = session.mission?.timingSchedule
        XCTAssertEqual(session.timingDisplay?.current, .notStarted)
        XCTAssertNil(session.legTiming?.selectedContext)
        XCTAssertEqual(session.timingDisplay?.nextDuration, .available(120))
        session.isFlying = true
        session.advance(wallElapsed: 300)
        session.speedKnots = 240
        XCTAssertEqual(session.legTiming?.selectedContext?.estimatedDistanceNM, 10)
        XCTAssertEqual(session.timingDisplay?.current, .remaining(seconds: 150, reachSeconds: 450))
        XCTAssertEqual(session.timingDisplay?.nextDuration, .available(60))
        session.isFlying = false
        let paused = session.timingDisplay
        session.advance(wallElapsed: 10_000)
        XCTAssertEqual(session.timingDisplay, paused)
        session.isFlying = true
        XCTAssertEqual(session.legTiming?.selectedContext?.startedAtSeconds, 0)
        session.advance(wallElapsed: 150)
        XCTAssertEqual(session.legTiming?.selectedContext?.expirySeconds, 450)
        session.advance(wallElapsed: 45)
        XCTAssertEqual(session.timingDisplay?.current, .pastEstimate(seconds: 45, reachSeconds: 450))
        session.speedKnots = 30
        XCTAssertEqual(session.timingDisplay?.current, .pastEstimate(seconds: 45, reachSeconds: 450))
        XCTAssertEqual(session.mission?.timingSchedule, schedule)

        let fractional = FlightSession(mission: makeTimingMission(distances: [0.071]), conditions: .calm)
        fractional.isFlying = true
        fractional.advance(wallElapsed: 10)
        XCTAssertEqual(try XCTUnwrap(fractional.legTiming?.selectedContext?.expirySeconds), 2.13, accuracy: 1e-6)
        guard case .pastEstimate(let past, let reach) = fractional.timingDisplay?.current else {
            return XCTFail("Expected exact past-estimate event")
        }
        XCTAssertEqual(reach, 2.13, accuracy: 1e-6)
        XCTAssertEqual(past, 7.87, accuracy: 1e-6)
    }

    @MainActor
    func testTimingStartupPrecedencePausedSelectionAndOneLevelUndo() {
        let session = FlightSession(mission: makeTimingMission(), conditions: .calm)
        session.startMissionLeg(at: 1)
        XCTAssertEqual(session.legTiming?.selectedContext?.legIndex, 1)
        XCTAssertNil(session.timingDisplay?.nextLeg)
        session.advance(wallElapsed: 50)
        XCTAssertEqual(session.legTiming?.selectedContext?.estimatedDistanceNM, 0)
        session.undoMissionLegStart()
        XCTAssertNil(session.legTiming?.selectedContext)
        XCTAssertEqual(session.legTiming?.canUndo, false)
        session.isFlying = true
        XCTAssertEqual(session.legTiming?.selectedContext?.legIndex, 0)
        XCTAssertEqual(session.legTiming?.canUndo, false)
        session.isFlying = false
        session.startMissionLeg(at: 1)
        session.isFlying = true
        XCTAssertEqual(session.legTiming?.selectedContext?.legIndex, 1)
        session.advance(wallElapsed: 30)
        session.startMissionLeg(at: 1) // Restart from now.
        XCTAssertEqual(session.legTiming?.selectedContext?.startedAtSeconds, 30)
        XCTAssertEqual(session.legTiming?.selectedContext?.estimatedDistanceNM, 0)
        session.undoMissionLegStart()
        XCTAssertEqual(session.legTiming?.selectedContext?.startedAtSeconds, 0)
        XCTAssertEqual(session.legTiming?.selectedContext?.estimatedDistanceNM, 1)
        session.undoMissionLegStart()
        XCTAssertEqual(session.legTiming?.selectedContext?.legIndex, 1)
        session.startMissionLeg(at: -1)
        session.startMissionLeg(at: 2)
        XCTAssertEqual(session.legTiming?.canUndo, false)

        let explicitFirst = FlightSession(mission: makeTimingMission(), conditions: .calm)
        explicitFirst.startMissionLeg(at: 1)
        explicitFirst.isFlying = true
        XCTAssertEqual(explicitFirst.legTiming?.selectedContext?.legIndex, 1)
        explicitFirst.undoMissionLegStart()
        explicitFirst.isFlying = false
        explicitFirst.isFlying = true
        XCTAssertNil(explicitFirst.legTiming?.selectedContext)
        XCTAssertEqual(explicitFirst.timingDisplay?.current, .selectLeg)

        let manual = FlightSession(mission: makeTimingMission(policy: .manual), conditions: .calm)
        manual.isFlying = true
        manual.advance(wallElapsed: 45)
        XCTAssertEqual(manual.timingDisplay?.current, .selectLeg)
        XCTAssertNil(manual.timingDisplay?.nextLeg)
        manual.isFlying = false
        manual.startMissionLeg(at: 1)
        XCTAssertEqual(manual.legTiming?.selectedContext?.startedAtSeconds, 45)
        XCTAssertEqual(manual.timingDisplay?.current, .remaining(seconds: 120, reachSeconds: 165))
    }

    @MainActor
    func testUndoAdvancesSavedContextAcrossSpeedChangesAndExpiry() throws {
        let session = FlightSession(mission: makeTimingMission(distances: [20, 5]), conditions: .calm)
        session.isFlying = true
        session.advance(wallElapsed: 300)
        session.startMissionLeg(at: 1)
        session.speedKnots = 240
        session.advance(wallElapsed: 60)
        session.undoMissionLegStart()
        XCTAssertEqual(session.legTiming?.selectedContext?.estimatedDistanceNM, 14)
        XCTAssertEqual(session.timingDisplay?.current, .remaining(seconds: 90, reachSeconds: 450))
        XCTAssertEqual(session.legTiming?.canUndo, false)
        session.startMissionLeg(at: 1)
        session.advance(wallElapsed: 135)
        session.undoMissionLegStart()
        XCTAssertEqual(session.timingDisplay?.current, .pastEstimate(seconds: 45, reachSeconds: 450))
        XCTAssertEqual(session.legTiming?.selectedContext?.legIndex, 0)
        // A later manual start replaces the only saved context.
        session.startMissionLeg(at: 1)
        session.startMissionLeg(at: 1)
        session.advance(wallElapsed: 5)
        session.undoMissionLegStart()
        XCTAssertEqual(session.legTiming?.selectedContext?.legIndex, 1)
        XCTAssertEqual(try XCTUnwrap(session.legTiming?.selectedContext?.estimatedDistanceNM), 1.0 / 3, accuracy: 1e-6)
    }

    @MainActor
    func testZeroAirspeedPreservesProgressAndPastEstimateKeepsCounting() throws {
        let wind = FlightConditions.steady(try XCTUnwrap(SteadyWind(fromDegrees: 270, speedKnots: 20)))
        let session = FlightSession(mission: makeTimingMission(), conditions: wind)
        session.isFlying = true
        session.advance(wallElapsed: 300)
        session.speedKnots = 0
        let position = session.normalizedAircraftPosition
        session.advance(wallElapsed: 60)
        XCTAssertNotEqual(session.normalizedAircraftPosition, position)
        XCTAssertEqual(session.legTiming?.selectedContext?.estimatedDistanceNM, 10)
        XCTAssertEqual(session.timingDisplay?.current, .zeroAirspeed)
        XCTAssertEqual(session.timingDisplay?.nextDuration, .zeroAirspeed)
        session.speedKnots = 240
        XCTAssertEqual(session.timingDisplay?.current, .remaining(seconds: 150, reachSeconds: 510))
        session.advance(wallElapsed: 150)
        session.speedKnots = 0
        session.advance(wallElapsed: 45)
        XCTAssertEqual(session.timingDisplay?.current, .pastEstimate(seconds: 45, reachSeconds: 510))
        session.isFlying = false
        session.advance(wallElapsed: 45)
        XCTAssertEqual(session.timingDisplay?.current, .pastEstimate(seconds: 45, reachSeconds: 510))
    }

    @MainActor
    func testTimingUnavailableInputsDoNotInventProgressOrChangeSessionGuards() throws {
        let session = FlightSession(mission: makeTimingMission(), conditions: .calm)
        session.isFlying = true
        for invalid in [Double.nan, .infinity, -.infinity, -1] {
            session.speedKnots = invalid
            XCTAssertEqual(session.timingDisplay?.current, .unavailable)
            XCTAssertEqual(session.timingDisplay?.nextDuration, .unavailable)
            session.advance(wallElapsed: 30)
            XCTAssertEqual(session.elapsedSimulatedSeconds, 0)
            XCTAssertEqual(session.legTiming?.selectedContext?.estimatedDistanceNM, 0)
            XCTAssertEqual(session.recording?.samples.count, 1)
        }
        session.speedKnots = .leastNonzeroMagnitude
        XCTAssertEqual(session.timingDisplay?.current, .unavailable) // Derived time overflows.
        session.speedKnots = 120
        XCTAssertEqual(session.timingDisplay?.current, .remaining(seconds: 600, reachSeconds: 600))
        let invalidTiming = MissionTimingSchedule(legs: [], planningAirspeedKnots: 120)
        let definition = MissionFlightDefinition(id: "invalid-timing", title: "Still flyable",
            initialState: makeTimingMission().initialState, timingSchedule: invalidTiming)
        let invalid = FlightSession(mission: definition, conditions: .calm)
        invalid.startMissionLeg(at: 0)
        invalid.isFlying = true
        invalid.advance(wallElapsed: 10)
        XCTAssertEqual(invalid.timingDisplay?.current, .unavailable)
        XCTAssertNil(invalid.legTiming?.selectedContext)
        XCTAssertEqual(invalid.elapsedSimulatedSeconds, 10)
        XCTAssertNotNil(invalid.completeMission())
        let absent = FlightSession(mission: MissionFlightDefinition(id: "absent", title: "No schedule",
            initialState: definition.initialState), conditions: .calm)
        absent.startMissionLeg(at: 0)
        XCTAssertNil(absent.legTiming)
        XCTAssertNil(absent.timingDisplay)
    }

    @MainActor
    func testTimingStopsOnCompletionFailureAndLeavingAndRetryResets() throws {
        let mission = makeTimingMission()
        let beforePlay = FlightSession(mission: mission, conditions: .calm)
        beforePlay.completeMission()
        beforePlay.startMissionLeg(at: 1)
        beforePlay.isFlying = true
        XCTAssertFalse(beforePlay.isFlying)
        XCTAssertNil(beforePlay.legTiming?.selectedContext)
        XCTAssertEqual(beforePlay.legTiming?.hasHandledFirstPlay, false)

        let session = FlightSession(mission: mission, conditions: .calm)
        session.isFlying = true
        session.advance(wallElapsed: 50)
        session.startMissionLeg(at: 1)
        session.completeMission()
        let completedTiming = session.legTiming
        session.undoMissionLegStart()
        session.startMissionLeg(at: 0)
        session.advance(wallElapsed: 50)
        XCTAssertEqual(session.legTiming, completedTiming)
        let retry = session.freshMissionSession()
        XCTAssertNil(retry.legTiming?.selectedContext)
        XCTAssertEqual(retry.legTiming?.canUndo, false)
        XCTAssertEqual(retry.legTiming?.hasHandledFirstPlay, false)
        XCTAssertEqual(retry.timingDisplay?.current, .notStarted)
        XCTAssertEqual(retry.mission?.timingSchedule, mission.timingSchedule)
        retry.isFlying = true
        retry.advance(wallElapsed: 10)
        retry.leaveMission()
        let leftTiming = retry.legTiming
        retry.isFlying = true
        retry.startMissionLeg(at: 1)
        retry.advance(wallElapsed: 50)
        XCTAssertFalse(retry.isFlying)
        XCTAssertFalse(retry.canAdjustMissionTiming)
        XCTAssertEqual(retry.legTiming, leftTiming)
        XCTAssertEqual(retry.elapsedSimulatedSeconds, 10)

        let badStart = FlightAircraftState(normalizedPosition: CGPoint(x: 1.1, y: 0.5), speedKnots: 120)
        let failure = FlightSession(mission: makeTimingMission(initial: badStart), conditions: .calm)
        failure.isFlying = true
        failure.advance(wallElapsed: 10)
        let failedTiming = failure.legTiming
        XCTAssertNotNil(failure.simulationError)
        failure.startMissionLeg(at: 1)
        failure.undoMissionLegStart()
        XCTAssertEqual(failure.legTiming, failedTiming)
        XCTAssertEqual(failure.elapsedSimulatedSeconds, 0)
    }

    @MainActor
    func testTimingOnlyAdvancesThroughAcceptedStraightAndCurvedChartExit() throws {
        for curve in [false, true] {
            let initial = FlightAircraftState(normalizedPosition: curve
                ? CGPoint(x: 0.5, y: (1 / Double.pi) / FlightWorld.heightNM) : CGPoint(x: 0.999, y: 0.5),
                heading: curve ? 0 : 90, speedKnots: 120)
            let session = FlightSession(mission: makeTimingMission(initial: initial), conditions: .calm)
            session.selectedHeading = curve ? 180 : 90
            session.isFlying = true
            session.timeMultiplier = 30
            session.advance(wallElapsed: 20)
            let expectedTime = curve ? 10.0 : 15.0
            XCTAssertEqual(session.completion?.ending, .leftChart)
            XCTAssertEqual(session.elapsedSimulatedSeconds, expectedTime, accuracy: 1e-6)
            XCTAssertEqual(try XCTUnwrap(session.legTiming?.selectedContext?.estimatedDistanceNM),
                           120 * expectedTime / 3_600, accuracy: 1e-6)
            XCTAssertNil(session.legTiming?.selectedContext?.expirySeconds)
            let saved = session.legTiming
            session.advance(wallElapsed: 1_000)
            XCTAssertEqual(session.legTiming, saved)
        }
    }

    @MainActor
    func testTimingIsIndependentOfWindHeadingPositionAndChecklist() throws {
        let windy = FlightConditions.steady(try XCTUnwrap(SteadyWind(fromDegrees: 270, speedKnots: 25)))
        let a = FlightSession(mission: makeTimingMission(), conditions: .calm)
        let b = FlightSession(mission: makeTimingMission(initial: FlightAircraftState(
            normalizedPosition: CGPoint(x: 0.3, y: 0.4), heading: 210, speedKnots: 120)), conditions: windy)
        for session in [a, b] {
            session.isFlying = true
            session.advance(wallElapsed: 300)
            session.speedKnots = 240
            session.advance(wallElapsed: 60)
        }
        XCTAssertNotEqual(a.aircraftState, b.aircraftState)
        XCTAssertEqual(a.timingDisplay, b.timingDisplay)

        let control = FlightSession(mission: makeTimingMission(), conditions: .calm)
        let edited = FlightSession(mission: makeTimingMission(), conditions: .calm)
        var checklist = MissionFlightProgress(instructionCount: 2)
        for index in 0..<20 {
            edited.startMissionLeg(at: index % 2)
            if index % 3 == 0 { edited.undoMissionLegStart() }
            checklist.setInstructionComplete(index % 2 == 0, at: index % 2)
            for session in [control, edited] {
                session.selectedHeading = Double(index * 17)
                session.speedKnots = index % 2 == 0 ? 120 : 240
                session.timeMultiplier = 5
                session.isFlying = true
                session.advance(wallElapsed: 2)
            }
            XCTAssertEqual(edited.aircraftState, control.aircraftState)
            XCTAssertEqual(edited.nav1, control.nav1)
            XCTAssertEqual(edited.nav2, control.nav2)
            XCTAssertEqual(edited.timeMultiplier, control.timeMultiplier)
            XCTAssertEqual(edited.selectedHeading, control.selectedHeading)
            XCTAssertEqual(edited.elapsedSimulatedSeconds, control.elapsedSimulatedSeconds)
            XCTAssertEqual(edited.recording, control.recording)
        }
        XCTAssertEqual(edited.completeMission(), control.completeMission())
    }

    @MainActor
    func testOneHourTimingAccuracyAcrossPlaybackAndSpeedPartitions() throws {
        let shortDistance = 37.123
        var expectedDistance = 0.0
        var expectedExpiry: Double?
        for phase in 0..<60 {
            let speed = [120.0, 240, 0, 180][phase % 4]
            let travel = speed * 60 / 3_600
            if expectedExpiry == nil, expectedDistance + travel >= shortDistance {
                expectedExpiry = Double(phase * 60) + (shortDistance - expectedDistance) / speed * 3_600
            }
            expectedDistance += travel
        }
        for distance in [1_000, shortDistance] {
            var referencePosition: CGPoint?
            for multiplier in [1.0, 5, 10, 30] {
                for irregular in [false, true] {
                    let session = FlightSession(mission: makeTimingMission(distances: [distance, 4]), conditions: .calm)
                    session.timeMultiplier = multiplier
                    session.isFlying = true
                    var tick = 0
                    for phase in 0..<60 {
                        session.speedKnots = [120.0, 240, 0, 180][phase % 4]
                        session.selectedHeading = Double([90, 180, 270, 0][phase % 4])
                        let targetTime = Double((phase + 1) * 60)
                        while session.elapsedSimulatedSeconds < targetTime {
                            let wallStep = irregular ? [0.016, 0.041, 0.003, 0.23, 0.09][tick % 5] : 0.125
                            let simulated = min(targetTime - session.elapsedSimulatedSeconds, wallStep * multiplier)
                            session.advance(wallElapsed: simulated / multiplier)
                            tick += 1
                            guard session.isFlying else { return XCTFail("Unexpected flight ending") }
                        }
                    }
                    let context = try XCTUnwrap(session.legTiming?.selectedContext)
                    XCTAssertEqual(session.elapsedSimulatedSeconds, 3_600, accuracy: 1e-6)
                    XCTAssertEqual(session.recording?.samples.map(\.simulatedSeconds), (0...3_600).map(Double.init))
                    if distance == 1_000 {
                        XCTAssertEqual(context.estimatedDistanceNM, expectedDistance, accuracy: 1e-6)
                        guard case .remaining(let remaining, let reach) = session.timingDisplay?.current else {
                            return XCTFail("Expected remaining estimate")
                        }
                        let expectedRemaining = (distance - expectedDistance) / 180 * 3_600
                        XCTAssertEqual(remaining, expectedRemaining, accuracy: 1e-6)
                        XCTAssertEqual(reach, 3_600 + expectedRemaining, accuracy: 1e-6)
                    } else {
                        XCTAssertEqual(try XCTUnwrap(context.expirySeconds), try XCTUnwrap(expectedExpiry), accuracy: 1e-6)
                    }
                    if let referencePosition {
                        XCTAssertLessThanOrEqual(VORNavigation.distanceNM(fromNormalized: session.normalizedAircraftPosition,
                            toNormalized: referencePosition, mapWidthNM: FlightWorld.widthNM,
                            mapHeightNM: FlightWorld.heightNM), 1e-6)
                    } else { referencePosition = session.normalizedAircraftPosition }
                }
            }
        }
    }

    func testMissionFlightChecklistAllowsIndependentCompletionAndReopening() {
        var progress = MissionFlightProgress(instructionCount: 5)

        XCTAssertTrue(progress.completedInstructionIndices.isEmpty)

        // Mark the final reference first, then an earlier step. Neither edit
        // implicitly completes any of the intervening instructions.
        progress.setInstructionComplete(true, at: 4)
        progress.setInstructionComplete(true, at: 1)
        progress.setInstructionComplete(true, at: 1)
        XCTAssertEqual(progress.completedInstructionIndices, [1, 4])
        XCTAssertFalse(progress.isInstructionComplete(at: 0))
        XCTAssertTrue(progress.isInstructionComplete(at: 4))

        // Revisiting an earlier step preserves the other completed steps.
        progress.setInstructionComplete(false, at: 1)
        XCTAssertEqual(progress.completedInstructionIndices, [4])
        XCTAssertFalse(progress.isInstructionComplete(at: 1))

        for index in 0..<progress.instructionCount {
            progress.setInstructionComplete(true, at: index)
        }
        XCTAssertEqual(progress.completedInstructionIndices.count, 5)
        progress.setInstructionComplete(false, at: 0)
        XCTAssertEqual(progress.completedInstructionIndices, [1, 2, 3, 4])

        let freshFlight = MissionFlightProgress(instructionCount: 5)
        XCTAssertTrue(freshFlight.completedInstructionIndices.isEmpty)
    }

    @MainActor
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

        let atDestinationSession = FlightSession(mission: MissionFlightDefinition(
            id: resolved.plan.id, title: resolved.plan.name,
            initialState: FlightAircraftState(normalizedPosition: destination.normalizedPosition, speedKnots: 0),
            arrivalReference: MissionChartPoint(name: destination.name, normalizedPosition: destination.normalizedPosition)),
            conditions: .calm)
        atDestinationSession.isFlying = true
        atDestinationSession.advance(wallElapsed: 321)
        let atDestination = try XCTUnwrap(atDestinationSession.completeMission())
        let fiftyNMWestSession = FlightSession(mission: MissionFlightDefinition(
            id: resolved.plan.id, title: resolved.plan.name,
            initialState: FlightAircraftState(normalizedPosition: CGPoint(x: destination.normalizedPosition.x - 0.1,
                                                                          y: destination.normalizedPosition.y), speedKnots: 0),
            arrivalReference: MissionChartPoint(name: destination.name, normalizedPosition: destination.normalizedPosition)),
            conditions: .calm)
        fiftyNMWestSession.isFlying = true
        fiftyNMWestSession.advance(wallElapsed: 654)
        let fiftyNMWest = try XCTUnwrap(fiftyNMWestSession.completeMission())

        XCTAssertEqual(atDestination.simulatedElapsedSeconds, 321)
        XCTAssertEqual(try XCTUnwrap(atDestination.distanceFromDestinationNM), 0, accuracy: 0.000_001)
        XCTAssertEqual(fiftyNMWest.simulatedElapsedSeconds, 654)
        XCTAssertEqual(try XCTUnwrap(fiftyNMWest.distanceFromDestinationNM), 50, accuracy: 0.000_001)
    }

    func testIndependentlyTunedReceiversResolveOwnStations() {
        let mossbarrow = makeStation(identifier: "MSB", frequency: 117.15, x: 0.4, y: 0.62)
        let marrowfield = makeStation(identifier: "MFD", frequency: 116.25, x: 0.47, y: 0.7)
        var nav1 = NAVReceiver()
        var nav2 = NAVReceiver()
        nav1.tune(toFrequencyHundredths: 11_715)
        nav2.tune(toFrequencyHundredths: 11_625)

        let nav1Reading = VORNavigation.receiverReading(
            frequencyHundredths: nav1.frequencyHundredths,
            obs: nav1.obs,
            normalizedAircraftPosition: CGPoint(x: 0.43, y: 0.66),
            stations: [mossbarrow, marrowfield],
            mapWidthNM: FlatMap.widthNM,
            mapHeightNM: FlatMap.heightNM,
            cdiMax: 10
        )
        let nav2Reading = VORNavigation.receiverReading(
            frequencyHundredths: nav2.frequencyHundredths,
            obs: nav2.obs,
            normalizedAircraftPosition: CGPoint(x: 0.43, y: 0.66),
            stations: [mossbarrow, marrowfield],
            mapWidthNM: FlatMap.widthNM,
            mapHeightNM: FlatMap.heightNM,
            cdiMax: 10
        )

        XCTAssertEqual(nav1.frequencyLabel, "117.15")
        XCTAssertEqual(nav1Reading.station?.ident, "MSB")
        XCTAssertEqual(nav2.frequencyLabel, "116.25")
        XCTAssertEqual(nav2Reading.station?.ident, "MFD")
        XCTAssertNotEqual(nav1Reading.station?.relativePosition,
                          nav2Reading.station?.relativePosition)
    }

    func testFlightPlanCatalogNamesMissingBundleResource() {
        XCTAssertThrowsError(try FlightPlanCatalog.load(named: "NoSuchPlan")) { error in
            XCTAssertEqual(error as? FlightPlanCatalog.CatalogError, .resourceNotFound("NoSuchPlan"))
        }
    }

    func testWindFromCardinalDirectionsAndZeroWindMode() throws {
        let start = FlightAircraftState(normalizedPosition: CGPoint(x: 0.5, y: 0.5), speedKnots: 0)
        for (bearing, east, south) in [(0, 0.0, 20.0), (90, -20.0, 0.0),
                                       (180, 0.0, -20.0), (270, 20.0, 0.0)] {
            let wind = try XCTUnwrap(SteadyWind(fromDegrees: bearing, speedKnots: 20))
            let end = FlightPhysics.Trajectory(start: start, selectedHeading: 0,
                                               conditions: .steady(wind)).state(at: 3_600)
            let originNM = FlightWorld.nauticalMiles(for: start.normalizedPosition)
            assertPoint(FlightWorld.nauticalMiles(for: end.normalizedPosition),
                        equals: CGPoint(x: originNM.x + east, y: originNM.y + south), accuracy: 1e-7)
        }
        let zero = FlightConditions.steady(try XCTUnwrap(SteadyWind(fromDegrees: 359, speedKnots: 0)))
        XCTAssertNotEqual(zero, .calm)
        XCTAssertEqual(zero.windVelocity, .zero)
        XCTAssertNil(SteadyWind(fromDegrees: 360, speedKnots: 20))
        XCTAssertNil(SteadyWind(fromDegrees: 0, speedKnots: 41))
    }

    func testDirectTrajectoryIntegratesKnownArcAndStraightRemainder() {
        let start = FlightAircraftState(normalizedPosition: .zero, speedKnots: 120)
        let trajectory = FlightPhysics.Trajectory(start: start, selectedHeading: 90, conditions: .calm)
        // At 120 kt and 3°/s the quarter-circle radius is 2/π NM.
        let radius = 2 / Double.pi
        let quarter = trajectory.state(at: 30)
        assertPoint(FlightWorld.nauticalMiles(for: quarter.normalizedPosition),
                    equals: CGPoint(x: radius, y: -radius), accuracy: 1e-7)
        XCTAssertEqual(quarter.heading, 90, accuracy: 1e-7)
        let remainder = trajectory.state(at: 60)
        assertPoint(FlightWorld.nauticalMiles(for: remainder.normalizedPosition),
                    equals: CGPoint(x: radius + 1, y: -radius), accuracy: 1e-7)
        let left = FlightPhysics.Trajectory(start: start, selectedHeading: 270, conditions: .calm).state(at: 30)
        assertPoint(FlightWorld.nauticalMiles(for: left.normalizedPosition),
                    equals: CGPoint(x: -radius, y: -radius), accuracy: 1e-7)
    }

    func testBothRepresentationsOfHalfTurnGoRight() {
        XCTAssertEqual(FlightPhysics.turn(heading: 0, toward: 180, elapsed: 1), 3)
        XCTAssertEqual(FlightPhysics.turn(heading: 270, toward: 90, elapsed: 1), 273)
        let start = FlightAircraftState(normalizedPosition: .zero, heading: 270, speedKnots: 120)
        let end = FlightPhysics.Trajectory(start: start, selectedHeading: 90, conditions: .calm).state(at: 60)
        assertPoint(FlightWorld.nauticalMiles(for: end.normalizedPosition),
                    equals: CGPoint(x: 0, y: -4 / Double.pi), accuracy: 1e-7)
        XCTAssertEqual(end.heading, 90, accuracy: 1e-7)
    }

    @MainActor
    func testOneHourMotionAndEverySecondAgreeAcrossPlaybackPartitions() throws {
        let initial = FlightAircraftState(normalizedPosition: CGPoint(x: 0.4, y: 0.5))
        let phases: [(seconds: Int, target: Double, speed: Double)] = [
            (30, 90, 260), (60, 270, 120), (83, 350, 260),
            (48, 10, 0), (579, 77, 120), (2_800, 180, 260),
        ]
        let windy = FlightConditions.steady(try XCTUnwrap(SteadyWind(fromDegrees: 270, speedKnots: 40)))
        for conditions in [FlightConditions.calm, windy] {
            for multiplier in [1.0, 5, 10, 30] {
                let session = FlightSession(initialState: initial, conditions: conditions)
                session.timeMultiplier = multiplier
                session.isFlying = true
                var reference = initial
                var tick = 0
                for phase in phases {
                    session.selectedHeading = phase.target
                    session.speedKnots = phase.speed
                    let trajectory = FlightPhysics.Trajectory(
                        start: FlightAircraftState(normalizedPosition: reference.normalizedPosition,
                                                   heading: reference.heading, speedKnots: phase.speed),
                        selectedHeading: phase.target, conditions: conditions)
                    for second in 1...phase.seconds {
                        var remaining = 1.0
                        while remaining > 0 {
                            let wallPattern = [0.016, 0.041, 0.003, 0.23, 0.09]
                            let simulated = min(remaining, wallPattern[tick % wallPattern.count] * multiplier)
                            session.advance(wallElapsed: simulated / multiplier)
                            remaining -= simulated
                            tick += 1
                        }
                        let expected = trajectory.state(at: Double(second))
                        let distance = VORNavigation.distanceNM(
                            fromNormalized: session.normalizedAircraftPosition,
                            toNormalized: expected.normalizedPosition,
                            mapWidthNM: FlightWorld.widthNM, mapHeightNM: FlightWorld.heightNM)
                        XCTAssertLessThanOrEqual(distance, 1e-6)
                        XCTAssertEqual(VORNavigation.normalize180(session.heading - expected.heading), 0, accuracy: 1e-7)
                    }
                    reference = trajectory.state(at: Double(phase.seconds))
                }
                XCTAssertEqual(session.elapsedSimulatedSeconds, 3_600, accuracy: 1e-6)
            }
        }
    }

    @MainActor
    func testPauseZeroAirspeedAndMovementBeyondPresentationCrop() throws {
        let wind = FlightConditions.steady(try XCTUnwrap(SteadyWind(fromDegrees: 270, speedKnots: 20)))
        let initial = FlightAircraftState(normalizedPosition: CGPoint(x: 0.99, y: 0.5), speedKnots: 0)
        let session = FlightSession(initialState: initial, conditions: wind)
        session.selectedHeading = 90
        session.advance(wallElapsed: 30)
        XCTAssertEqual(session.aircraftState, initial)
        XCTAssertEqual(session.elapsedSimulatedSeconds, 0)
        session.isFlying = true
        session.advance(wallElapsed: 3_600)
        XCTAssertEqual(session.normalizedAircraftPosition.x, 1.03, accuracy: 1e-10)
        XCTAssertEqual(session.heading, 90)
        XCTAssertEqual(session.elapsedSimulatedSeconds, 3_600)
        session.isFlying = false
        let paused = session.aircraftState
        session.advance(wallElapsed: 500)
        XCTAssertEqual(session.aircraftState, paused)
        XCTAssertEqual(session.elapsedSimulatedSeconds, 3_600)
        let calm = FlightSession(initialState: initial)
        calm.isFlying = true
        calm.advance(wallElapsed: 10)
        XCTAssertEqual(calm.normalizedAircraftPosition, initial.normalizedPosition)
        XCTAssertEqual(calm.elapsedSimulatedSeconds, 10)
    }

    func testWindSetupRandomizesOnlyWhenRequestedAndRetainsEdits() throws {
        var generator = WindTestGenerator()
        var draft = MissionWindSetup()
        XCTAssertEqual(draft.conditions, .calm)
        XCTAssertEqual(generator.calls, 0)
        draft.select(.steady, using: &generator)
        XCTAssertTrue((0...359).contains(try XCTUnwrap(draft.direction)))
        XCTAssertTrue((5...25).contains(try XCTUnwrap(draft.speed)))
        let firstCalls = generator.calls
        draft.directionText = "017"
        draft.speedText = "40"
        let edited = draft.conditions
        draft.select(.calm, using: &generator)
        XCTAssertEqual(draft.conditions, .calm)
        draft.select(.steady, using: &generator)
        XCTAssertEqual(draft.conditions, edited)
        XCTAssertEqual(generator.calls, firstCalls)
        draft.randomize(using: &generator)
        XCTAssertGreaterThan(generator.calls, firstCalls)
        XCTAssertTrue((5...25).contains(try XCTUnwrap(draft.speed)))
    }

    func testWindSetupRequiresCorrectionWithoutClampingOrErasingText() throws {
        var draft = MissionWindSetup()
        var generator = WindTestGenerator()
        draft.select(.steady, using: &generator)
        for invalid in ["", "360", "-1", "-0", "10.5", "east", "+5"] {
            draft.directionText = invalid
            draft.speedText = "20"
            XCTAssertNil(draft.conditions)
            draft.formatValidEntries()
            XCTAssertEqual(draft.directionText, invalid)
        }
        draft.directionText = "359"
        for invalid in ["", "41", "55", "-1", "1.5", "NaN"] {
            draft.speedText = invalid
            XCTAssertNil(draft.conditions)
            draft.select(.calm, using: &generator)
            XCTAssertEqual(draft.conditions, .calm)
            draft.select(.steady, using: &generator)
            XCTAssertEqual(draft.speedText, invalid)
            XCTAssertNil(draft.conditions)
        }
        for speed in ["0", "40"] {
            draft.speedText = speed
            XCTAssertNotNil(draft.conditions)
        }
        draft.directionText = " 0 "
        draft.formatValidEntries()
        XCTAssertEqual(draft.directionText, "000")
        XCTAssertNotNil(draft.conditions)
    }

    @MainActor
    func testCompletionLocksConditionsAndRetryRestoresExplicitInitialState() throws {
        let initial = FlightAircraftState(normalizedPosition: CGPoint(x: 0.35, y: 0.6), heading: 87, speedKnots: 120)
        let mission = MissionFlightDefinition(id: "recovery", title: "Recover a route", initialState: initial,
                                              plannedPoints: [MissionChartPoint(name: "Route start", normalizedPosition: .zero)])
        var draft = MissionWindSetup()
        draft.select(.steady)
        draft.directionText = "270"
        draft.speedText = "20"
        let launched = try XCTUnwrap(draft.conditions)
        let session = FlightSession(mission: mission, conditions: launched)
        draft.select(.calm)
        XCTAssertEqual(session.conditions, launched)
        session.isFlying = true
        session.selectedHeading = 180
        session.advance(wallElapsed: 20)
        session.nav1.obs = 123
        session.zoom = 3
        let result = try XCTUnwrap(session.completeMission())
        XCTAssertNil(result.distanceFromDestinationNM)
        XCTAssertEqual(result.conditions, launched)
        XCTAssertEqual(result.aircraftState, session.aircraftState)
        session.isFlying = true
        XCTAssertFalse(session.isFlying)
        session.advance(wallElapsed: 1_000)
        XCTAssertEqual(session.completeMission(), result)
        XCTAssertEqual(session.elapsedSimulatedSeconds, 20)
        let retry = session.freshMissionSession()
        XCTAssertEqual(retry.aircraftState, initial)
        XCTAssertEqual(retry.selectedHeading, 87)
        XCTAssertEqual(retry.conditions, launched)
        XCTAssertEqual(retry.elapsedSimulatedSeconds, 0)
        XCTAssertEqual(retry.nav1, NAVReceiver())
        XCTAssertEqual(retry.zoom, 1)
        XCTAssertNil(retry.completion)
        XCTAssertTrue(MissionFlightProgress(instructionCount: 0).completedInstructionIndices.isEmpty)
    }

    @MainActor
    func testInMemoryPlanAndDifferentMissionUseTheSameFlightPipeline() throws {
        let authored = FlightPlan(id: "in-memory", name: "Eastbound test", origin: .airport(icao: "GNEW"),
                                  waypoints: [], destination: .vor(stationID: "NEW"), terminalReference: nil)
        let resolved = try FlightPlanResolver.resolve(authored,
            airports: [makeAirport(icao: "GNEW", x: 0.2, y: 0.5)],
            stations: [makeStation(identifier: "NEW", x: 0.4, y: 0.5)],
            mapWidthNM: FlightWorld.widthNM, mapHeightNM: FlightWorld.heightNM, cruiseSpeedKnots: 120)
        let first = MissionFlightDefinition(resolvedPlan: resolved)
        XCTAssertEqual(first.plannedPoints.count, 2)
        XCTAssertEqual(first.instructions.count, 1)
        let other = MissionFlightDefinition(id: "other", title: "Other mission", initialState: first.initialState,
            plannedPoints: [MissionChartPoint(name: "Elsewhere", normalizedPosition: CGPoint(x: 0.8, y: 0.8))],
            arrivalReference: MissionChartPoint(name: "Different arrival", normalizedPosition: CGPoint(x: 0.3, y: 0.5)),
            instructions: [MissionInstruction(title: "Find a fix"), MissionInstruction(title: "Recover")])
        let wind = FlightConditions.steady(try XCTUnwrap(SteadyWind(fromDegrees: 90, speedKnots: 10)))
        let a = FlightSession(mission: first, conditions: wind)
        let b = FlightSession(mission: other, conditions: wind)
        for session in [a, b] {
            session.isFlying = true
            session.selectedHeading = 90
            session.advance(wallElapsed: 50)
        }
        XCTAssertEqual(a.aircraftState, b.aircraftState)
        let aResult = try XCTUnwrap(a.completeMission())
        let bResult = try XCTUnwrap(b.completeMission())
        XCTAssertEqual(aResult.mission, first)
        XCTAssertEqual(bResult.mission, other)
        XCTAssertNotEqual(aResult.distanceFromDestinationNM, bResult.distanceFromDestinationNM)
        XCTAssertEqual(b.freshMissionSession().mission, other)
        let noReferences = MissionFlightDefinition(id: "no-reference", title: "Unplanned exercise", initialState: first.initialState)
        let early = try XCTUnwrap(FlightSession(mission: noReferences, conditions: .calm).completeMission())
        XCTAssertEqual(early.simulatedElapsedSeconds, 0)
        XCTAssertNil(early.distanceFromDestinationNM)
        XCTAssertTrue(early.mission.plannedPoints.isEmpty)
    }

    @MainActor
    func testRecordingEvaluatesEveryCrossedSecondOnTheDirectTrajectory() throws {
        let initial = FlightAircraftState(normalizedPosition: CGPoint(x: 0.5, y: 0.5), speedKnots: 120)
        let wind = FlightConditions.steady(try XCTUnwrap(SteadyWind(fromDegrees: 270, speedKnots: 20)))
        let session = FlightSession(mission: MissionFlightDefinition(id: "arc", title: "Arc", initialState: initial),
                                    conditions: wind)
        session.selectedHeading = 90
        session.isFlying = true
        session.advance(wallElapsed: 30.25)
        XCTAssertEqual(session.recording?.samples.map(\.simulatedSeconds), (0...30).map(Double.init))
        let origin = FlightWorld.nauticalMiles(for: initial.normalizedPosition)
        let radius = 2 / Double.pi
        for sample in try XCTUnwrap(session.recording).samples {
            let theta = sample.simulatedSeconds * 3 * .pi / 180
            let expected = CGPoint(x: origin.x + radius * (1 - cos(theta)) + 20 * sample.simulatedSeconds / 3_600,
                                   y: origin.y - radius * sin(theta))
            assertPoint(FlightWorld.nauticalMiles(for: sample.aircraftState.normalizedPosition), equals: expected, accuracy: 1e-7)
            XCTAssertEqual(sample.aircraftState.heading, sample.simulatedSeconds * 3, accuracy: 1e-7)
            XCTAssertEqual(sample.aircraftState.speedKnots, 120)
        }
        let result = try XCTUnwrap(session.completeMission())
        XCTAssertEqual(result.recording.count, 32)
        XCTAssertEqual(result.recording.last?.simulatedSeconds, 30.25)
        XCTAssertEqual(result.aircraftState, session.aircraftState)
        XCTAssertEqual(result.ending, .playerCompleted)
        assertPoint(FlightWorld.nauticalMiles(for: result.aircraftState.normalizedPosition),
                    equals: CGPoint(x: origin.x + radius + 120 * 0.25 / 3_600 + 20 * 30.25 / 3_600,
                                    y: origin.y - radius), accuracy: 1e-7)
    }

    @MainActor
    func testRecordingCoalescesExactFinishAndKeepsZeroTimeFlightHonest() throws {
        let initial = FlightAircraftState(normalizedPosition: CGPoint(x: 0.5, y: 0.5))
        let mission = MissionFlightDefinition(id: "coincident", title: "Coincident", initialState: initial)
        let early = FlightSession(mission: mission, conditions: .calm)
        let zero = try XCTUnwrap(early.completeMission())
        XCTAssertEqual(zero.recording, [FlightSample(simulatedSeconds: 0, aircraftState: initial)])
        let session = FlightSession(mission: mission, conditions: .calm)
        session.isFlying = true
        session.advance(wallElapsed: 2)
        session.speedKnots = 0
        let result = try XCTUnwrap(session.completeMission())
        XCTAssertEqual(result.recording.map(\.simulatedSeconds), [0, 1, 2])
        XCTAssertEqual(result.recording.last?.aircraftState.speedKnots, 0)
        XCTAssertEqual(result.recording.first?.aircraftState, initial)
        XCTAssertEqual(session.completeMission(), result)
        session.isFlying = true
        session.advance(wallElapsed: 100)
        XCTAssertEqual(session.recording?.samples, result.recording)
        XCTAssertEqual(session.elapsedSimulatedSeconds, 2)
    }

    @MainActor
    func testPauseStationaryAndWindOnlyRecordingKeepTheSchedule() throws {
        let initial = FlightAircraftState(normalizedPosition: CGPoint(x: 0.5, y: 0.5), speedKnots: 0)
        let mission = MissionFlightDefinition(id: "stationary", title: "Stationary", initialState: initial)
        for conditions in [FlightConditions.calm, .steady(try XCTUnwrap(SteadyWind(fromDegrees: 270, speedKnots: 20)))] {
            let session = FlightSession(mission: mission, conditions: conditions)
            session.isFlying = true
            session.advance(wallElapsed: 2.25)
            let paused = session.recording
            session.isFlying = false
            session.advance(wallElapsed: 1_000)
            XCTAssertEqual(session.recording, paused)
            XCTAssertEqual(session.elapsedSimulatedSeconds, 2.25)
            session.isFlying = true
            session.advance(wallElapsed: 1)
            let result = try XCTUnwrap(session.completeMission())
            XCTAssertEqual(result.recording.map(\.simulatedSeconds), [0, 1, 2, 3, 3.25])
            for sample in result.recording {
                let expectedX = initial.normalizedPosition.x + conditions.windVelocity.x * sample.simulatedSeconds / FlightWorld.widthNM
                XCTAssertEqual(sample.aircraftState.normalizedPosition.x, expectedX, accuracy: 1e-10)
            }
        }
        XCTAssertNil(FlightSession(initialState: initial).recording)
    }

    @MainActor
    func testOneHourRecordingIsIdenticalAcrossPlaybackAndIrregularTicks() throws {
        let initial = FlightAircraftState(normalizedPosition: CGPoint(x: 0.5, y: 0.5), speedKnots: 120)
        let mission = MissionFlightDefinition(id: "loops", title: "Loops", initialState: initial)
        for conditions in [FlightConditions.calm, .steady(try XCTUnwrap(SteadyWind(fromDegrees: 270, speedKnots: 40)))] {
            var reference: MissionFlightCompletion?
            for multiplier in [1.0, 5, 10, 30] {
                let session = FlightSession(mission: mission, conditions: conditions)
                session.timeMultiplier = multiplier
                session.isFlying = true
                var tick = 0
                for phase in 0..<60 {
                    session.selectedHeading = Double([90, 180, 270, 0][phase % 4])
                    let targetTime = Double((phase + 1) * 60)
                    while session.elapsedSimulatedSeconds < targetTime {
                        let step = min(targetTime - session.elapsedSimulatedSeconds,
                                       [0.015625, 0.03125, 0.125, 0.25][tick % 4] * multiplier)
                        session.advance(wallElapsed: step / multiplier)
                        tick += 1
                        if session.simulationError != nil || !session.isFlying { XCTFail("Unexpected mission ending"); return }
                    }
                }
                let result = try XCTUnwrap(session.completeMission())
                XCTAssertEqual(result.recording.map(\.simulatedSeconds), (0...3_600).map(Double.init))
                XCTAssertEqual(result.ending, .playerCompleted)
                if let reference {
                    for (actual, expected) in zip(result.recording, reference.recording) {
                        let error = VORNavigation.distanceNM(fromNormalized: actual.aircraftState.normalizedPosition,
                                                             toNormalized: expected.aircraftState.normalizedPosition,
                                                             mapWidthNM: FlightWorld.widthNM, mapHeightNM: FlightWorld.heightNM)
                        XCTAssertLessThanOrEqual(error, 1e-6)
                        XCTAssertEqual(VORNavigation.normalize180(actual.aircraftState.heading - expected.aircraftState.heading), 0, accuracy: 1e-7)
                    }
                } else { reference = result }
                XCTAssertEqual(result.simulatedElapsedSeconds, 3_600, accuracy: 1e-6)
            }
        }
    }

    func testFirstChartCrossingOfEachEdgeHasIndependentStraightFlightTime() throws {
        let cases: [(CGPoint, Double, Double, CGPoint)] = [
            (CGPoint(x: 0.99, y: 0.5), 90, 150, CGPoint(x: 1, y: 0.5)),
            (CGPoint(x: 0.01, y: 0.5), 270, 150, CGPoint(x: 0, y: 0.5)),
            (CGPoint(x: 0.5, y: 0.01), 0, FlightWorld.heightNM * 0.01 * 30, CGPoint(x: 0.5, y: 0)),
            (CGPoint(x: 0.5, y: 0.99), 180, FlightWorld.heightNM * 0.01 * 30, CGPoint(x: 0.5, y: 1)),
        ]
        for (position, heading, expectedTime, expectedPosition) in cases {
            let trajectory = FlightPhysics.Trajectory(start: FlightAircraftState(normalizedPosition: position, heading: heading, speedKnots: 120),
                                                       selectedHeading: heading, conditions: .calm)
            let exit = try XCTUnwrap(trajectory.firstChartExit(through: expectedTime + 10))
            XCTAssertEqual(exit.elapsed, expectedTime, accuracy: 1e-6)
            assertPoint(FlightWorld.nauticalMiles(for: exit.state.normalizedPosition),
                        equals: FlightWorld.nauticalMiles(for: expectedPosition), accuracy: 1e-7)
        }
    }

    func testCornerCrossingPinsBothEdgesAndBoundaryStartsDistinguishDirection() throws {
        let start = FlightAircraftState(normalizedPosition: CGPoint(x: 0.99, y: 5 / FlightWorld.heightNM), heading: 45, speedKnots: 120)
        let corner = try XCTUnwrap(FlightPhysics.Trajectory(start: start, selectedHeading: 45, conditions: .calm).firstChartExit(through: 300))
        XCTAssertEqual(corner.elapsed, 150 * sqrt(2), accuracy: 1e-6)
        XCTAssertEqual(corner.state.normalizedPosition, CGPoint(x: 1, y: 0))
        for (position, outward, inward, along) in [
            (CGPoint(x: 0, y: 0.5), 270.0, 90.0, 0.0),
            (CGPoint(x: 1, y: 0.5), 90, 270, 0),
            (CGPoint(x: 0.5, y: 0), 0, 180, 90),
            (CGPoint(x: 0.5, y: 1), 180, 0, 90),
        ] {
            for heading in [outward, inward, along] {
                let trajectory = FlightPhysics.Trajectory(start: FlightAircraftState(normalizedPosition: position, heading: heading, speedKnots: 120),
                                                           selectedHeading: heading, conditions: .calm)
                if heading == outward { XCTAssertEqual(try trajectory.firstChartExit(through: 1)?.elapsed, 0) }
                else { XCTAssertNil(try trajectory.firstChartExit(through: 1)) }
            }
        }
    }

    func testCurvedExitAndReentryIsFoundWhileTangencyDoesNotEndFlight() throws {
        let radius = 2 / Double.pi
        let start = FlightAircraftState(normalizedPosition: CGPoint(x: 0.5, y: radius / 2 / FlightWorld.heightNM), speedKnots: 120)
        let trajectory = FlightPhysics.Trajectory(start: start, selectedHeading: 180, conditions: .calm)
        XCTAssertGreaterThan(trajectory.state(at: 60).normalizedPosition.y, 0)
        let exit = try XCTUnwrap(trajectory.firstChartExit(through: 60))
        XCTAssertEqual(exit.elapsed, 10, accuracy: 1e-6)
        let expectedX = 250 + radius * (1 - cos(Double.pi / 6))
        assertPoint(FlightWorld.nauticalMiles(for: exit.state.normalizedPosition), equals: CGPoint(x: expectedX, y: 0), accuracy: 1e-7)
        let tangent = FlightPhysics.Trajectory(
            start: FlightAircraftState(normalizedPosition: CGPoint(x: 0.5, y: radius / FlightWorld.heightNM), speedKnots: 120),
            selectedHeading: 180, conditions: .calm)
        XCTAssertNil(try tangent.firstChartExit(through: 60))
        XCTAssertNil(try tangent.firstChartExit(through: 30))
    }

    @MainActor
    func testAutomaticCrossingRecordingAndClockAgreeAtEveryPlaybackSpeed() throws {
        let radius = 2 / Double.pi
        for curve in [false, true] {
            var reference: MissionFlightCompletion?
            for multiplier in [1.0, 5, 10, 30] {
                let initial = FlightAircraftState(normalizedPosition: curve
                    ? CGPoint(x: 0.5, y: radius / 2 / FlightWorld.heightNM) : CGPoint(x: 0.999, y: 0.5),
                    heading: curve ? 0 : 90, speedKnots: 120)
                let mission = MissionFlightDefinition(id: "exit", title: "Exit", initialState: initial)
                let session = FlightSession(mission: mission, conditions: .calm)
                session.selectedHeading = curve ? 180 : 90
                session.timeMultiplier = multiplier
                session.isFlying = true
                for _ in 0..<2_000 {
                    if session.completion != nil { break }
                    session.advance(wallElapsed: 0.23)
                }
                let result = try XCTUnwrap(session.completion)
                let expectedTime = curve ? 10.0 : 15.0
                XCTAssertEqual(result.simulatedElapsedSeconds, expectedTime, accuracy: 1e-6)
                XCTAssertEqual(result.recording.map(\.simulatedSeconds), (0...Int(expectedTime)).map(Double.init))
                XCTAssertEqual(result.ending, .leftChart)
                XCTAssertFalse(session.isFlying)
                XCTAssertNil(session.simulationError)
                XCTAssertTrue(result.recording.allSatisfy { sample in
                    let p = sample.aircraftState.normalizedPosition
                    return (0...1).contains(p.x) && (0...1).contains(p.y)
                })
                if let reference {
                    for (a, b) in zip(result.recording, reference.recording) {
                        assertPoint(FlightWorld.nauticalMiles(for: a.aircraftState.normalizedPosition),
                                    equals: FlightWorld.nauticalMiles(for: b.aircraftState.normalizedPosition), accuracy: 1e-6)
                    }
                } else { reference = result }
                session.isFlying = true
                session.advance(wallElapsed: 1_000)
                XCTAssertEqual(session.completeMission(), result)
            }
        }
    }

    @MainActor
    func testWindOnlyExitAndZeroTimeOutwardExitFinalizeExactState() throws {
        let wind = FlightConditions.steady(try XCTUnwrap(SteadyWind(fromDegrees: 270, speedKnots: 20)))
        let initial = FlightAircraftState(normalizedPosition: CGPoint(x: 0.999, y: 0.5), speedKnots: 0)
        let session = FlightSession(mission: MissionFlightDefinition(id: "drift", title: "Drift", initialState: initial), conditions: wind)
        session.isFlying = true
        session.selectedHeading = 180
        session.advance(wallElapsed: 100)
        let result = try XCTUnwrap(session.completion)
        XCTAssertEqual(result.simulatedElapsedSeconds, 90, accuracy: 1e-6)
        XCTAssertEqual(result.aircraftState.normalizedPosition.x, 1)
        XCTAssertEqual(result.aircraftState.heading, 180)
        XCTAssertEqual(result.recording.count, 91)
        let edge = FlightSession(mission: MissionFlightDefinition(id: "edge", title: "Edge",
            initialState: FlightAircraftState(normalizedPosition: CGPoint(x: 1, y: 0.5), heading: 90)), conditions: .calm)
        edge.isFlying = true
        edge.advance(wallElapsed: 1)
        XCTAssertEqual(edge.completion?.ending, .leftChart)
        XCTAssertEqual(edge.completion?.recording.count, 1)
        XCTAssertEqual(edge.completion?.simulatedElapsedSeconds, 0)
    }

    @MainActor
    func testRecordingsStayIndependentOfChecklistAndAreReleasedOnExit() throws {
        let initial = FlightAircraftState(normalizedPosition: CGPoint(x: 0.5, y: 0.5), speedKnots: 120)
        let a = MissionFlightDefinition(id: "a", title: "A", initialState: initial,
            instructions: [MissionInstruction(title: "Check a fix")])
        let b = MissionFlightDefinition(id: "b", title: "B", initialState: initial,
            arrivalReference: MissionChartPoint(name: "Other destination", normalizedPosition: CGPoint(x: 0.6, y: 0.6)))
        var session: FlightSession? = FlightSession(mission: a, conditions: .calm)
        weak var released = session
        let other = FlightSession(mission: b, conditions: .calm)
        var checklist = MissionFlightProgress(instructionCount: 1)
        for tick in 0..<12 {
            checklist.setInstructionComplete(tick % 2 == 0, at: 0)
            for flight in [session!, other] { flight.isFlying = true; flight.advance(wallElapsed: 0.25) }
        }
        let completed = try XCTUnwrap(session?.completeMission())
        let otherResult = try XCTUnwrap(other.completeMission())
        XCTAssertEqual(completed.recording, otherResult.recording)
        XCTAssertNil(completed.distanceFromDestinationNM)
        XCTAssertNotNil(otherResult.distanceFromDestinationNM)
        let retry = session!.freshMissionSession()
        XCTAssertEqual(retry.recording?.samples, [FlightSample(simulatedSeconds: 0, aircraftState: initial)])
        XCTAssertEqual(retry.mission?.id, "a")
        session = nil
        XCTAssertNil(released)
        XCTAssertEqual(completed.recording.count, 4)
    }

    @MainActor
    func testBoundaryCalculationFailureDoesNotAdvanceTheFlight() {
        let initial = FlightAircraftState(normalizedPosition: CGPoint(x: 1.1, y: 0.5))
        let session = FlightSession(mission: MissionFlightDefinition(id: "invalid", title: "Invalid start", initialState: initial), conditions: .calm)
        session.isFlying = true
        session.advance(wallElapsed: 10)
        XCTAssertNotNil(session.simulationError)
        XCTAssertFalse(session.isFlying)
        XCTAssertEqual(session.elapsedSimulatedSeconds, 0)
        XCTAssertEqual(session.aircraftState, initial)
        XCTAssertEqual(session.recording?.samples.count, 1)
    }

    func testDebriefFitIncludesFullSourceEdgesAndHandlesStationaryRecording() {
        let positions = [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1), CGPoint(x: 0.5, y: 0.3)]
        let projection = MissionChartProjection(positions: positions, size: CGSize(width: 700, height: 760))
        for position in positions {
            let point = projection.point(for: position)
            XCTAssertTrue((64...636).contains(point.x))
            XCTAssertTrue((64...696).contains(point.y))
        }
        XCTAssertEqual(projection.sourceImageRect.width / projection.sourceImageRect.height, FlightWorld.sourceAspect, accuracy: 1e-10)
        let stationary = MissionChartProjection(positions: [CGPoint(x: 0.99, y: 0.01)], size: CGSize(width: 700, height: 760))
        XCTAssertTrue(stationary.pointsPerNM.isFinite)
        assertPoint(stationary.point(for: CGPoint(x: 0.99, y: 0.01)), equals: CGPoint(x: 350, y: 380))
    }

    @MainActor
    func testFractionalWindExitKeepsTheExactEndpointAcrossPlaybackSpeeds() throws {
        let wind = FlightConditions.steady(try XCTUnwrap(SteadyWind(fromDegrees: 270, speedKnots: 20)))
        let initial = FlightAircraftState(normalizedPosition: CGPoint(x: 1 - (20.0 / 3_600 * 1.25) / 500, y: 0.5), speedKnots: 0)
        let mission = MissionFlightDefinition(id: "fractional-exit", title: "Fractional exit", initialState: initial)
        for multiplier in [1.0, 5, 10, 30] {
            let session = FlightSession(mission: mission, conditions: wind)
            session.timeMultiplier = multiplier
            session.selectedHeading = 90
            session.isFlying = true
            for _ in 0..<20 {
                if session.completion != nil { break }
                session.advance(wallElapsed: 0.2)
            }
            let result = try XCTUnwrap(session.completion)
            XCTAssertEqual(result.recording.count, 3)
            XCTAssertEqual(result.recording[1].simulatedSeconds, 1)
            XCTAssertEqual(result.simulatedElapsedSeconds, 1.25, accuracy: 1e-6)
            XCTAssertEqual(result.aircraftState.normalizedPosition.x, 1)
            XCTAssertEqual(result.aircraftState.heading, 3.75, accuracy: 1e-7)
            XCTAssertEqual(result.recording.last?.aircraftState, result.aircraftState)
        }
    }

    func testBoundaryContinuationDistinguishesExactTouchTurnAndWindCancellation() throws {
        let start = FlightAircraftState(normalizedPosition: CGPoint(x: 0.99, y: 0.5), heading: 90, speedKnots: 120)
        let straight = FlightPhysics.Trajectory(start: start, selectedHeading: 90, conditions: .calm)
        XCTAssertNil(try straight.firstChartExit(through: 149.99))
        XCTAssertEqual(try straight.firstChartExit(through: 150)?.elapsed, 150)
        let radius = 2 / Double.pi
        let touchesThenTracksEdge = FlightPhysics.Trajectory(
            start: FlightAircraftState(normalizedPosition: CGPoint(x: 0.5, y: radius / FlightWorld.heightNM), speedKnots: 120),
            selectedHeading: 90, conditions: .calm)
        XCTAssertNil(try touchesThenTracksEdge.firstChartExit(through: 60))
        let northEdge = FlightAircraftState(normalizedPosition: CGPoint(x: 0.5, y: 0), heading: 90, speedKnots: 120)
        XCTAssertEqual(try FlightPhysics.Trajectory(start: northEdge, selectedHeading: 0, conditions: .calm)
            .firstChartExit(through: 10)?.elapsed, 0)
        XCTAssertNil(try FlightPhysics.Trajectory(start: northEdge, selectedHeading: 180, conditions: .calm)
            .firstChartExit(through: 10))
        // Wind cancels initial ground velocity and acceleration at this west
        // edge. The first nonzero (cubic) term still moves outward on turning.
        let cancelled = FlightAircraftState(normalizedPosition: CGPoint(x: 0, y: 0.5), heading: 90, speedKnots: 20)
        let wind = FlightConditions.steady(try XCTUnwrap(SteadyWind(fromDegrees: 90, speedKnots: 20)))
        XCTAssertEqual(try FlightPhysics.Trajectory(start: cancelled, selectedHeading: 180, conditions: wind)
            .firstChartExit(through: 30)?.elapsed, 0)
        XCTAssertNil(try FlightPhysics.Trajectory(start: cancelled, selectedHeading: 90, conditions: wind)
            .firstChartExit(through: 30))
    }

    func testWindShiftedTurningExtremaStillFindFirstExitAndRejectTangency() throws {
        let radius = 2 / Double.pi
        let wind = FlightConditions.steady(try XCTUnwrap(SteadyWind(fromDegrees: 270, speedKnots: 20)))
        // Starting westbound and turning right, x(t) = gap - R sin(ωt) + wt.
        // Choose gap so the first west-edge crossing is exactly θ=60°, t=20 s.
        let gap = radius * sin(Double.pi / 3) - 20.0 / 3_600 * 20
        let crossing = FlightPhysics.Trajectory(
            start: FlightAircraftState(normalizedPosition: CGPoint(x: gap / 500, y: 0.5), heading: 270, speedKnots: 120),
            selectedHeading: 90, conditions: wind)
        XCTAssertGreaterThan(crossing.state(at: 60).normalizedPosition.x, 0)
        let exit = try XCTUnwrap(crossing.firstChartExit(through: 60))
        XCTAssertEqual(exit.elapsed, 20, accuracy: 1e-6)
        assertPoint(FlightWorld.nauticalMiles(for: exit.state.normalizedPosition),
                    equals: CGPoint(x: 0, y: FlightWorld.heightNM / 2 - radius / 2), accuracy: 1e-7)
        // Wind moves the x-velocity zero away from the cardinal heading.
        let theta = acos(20.0 / 120)
        let tangentTime = theta / (.pi / 60)
        let tangentGap = radius * sin(theta) - 20.0 / 3_600 * tangentTime
        let tangent = FlightPhysics.Trajectory(
            start: FlightAircraftState(normalizedPosition: CGPoint(x: tangentGap / 500, y: 0.5), heading: 270, speedKnots: 120),
            selectedHeading: 90, conditions: wind)
        XCTAssertNil(try tangent.firstChartExit(through: 60))
    }

    func testDebriefZoomKeepsPointerAnchorAcrossLimitsAndPriorPan() {
        let size = CGSize(width: 725, height: 760)
        let fit = MissionChartProjection(positions: [CGPoint(x: 0.2, y: 0.4), CGPoint(x: 0.9, y: 0.6)], size: size)
        let pointer = CGPoint(x: 173, y: 541)
        var camera = MissionDebriefCamera()
        camera.move(by: CGSize(width: 117, height: -93))
        let fixedPosition = fit.applying(camera).position(at: pointer)
        for factor: CGFloat in [2, 3, 100, 0.25, 0.001, 1.7] {
            camera.zoom(by: factor, anchoredAt: pointer, in: size)
            assertPoint(fit.applying(camera).point(for: fixedPosition), equals: pointer, accuracy: 1e-9)
            XCTAssertTrue((0.5...16).contains(camera.zoom))
        }
        camera.zoom(by: 1_000, anchoredAt: pointer, in: size)
        XCTAssertEqual(camera.zoom, 16)
        camera.zoom(by: 0.00001, anchoredAt: pointer, in: size)
        XCTAssertEqual(camera.zoom, 0.5)
        camera.fitFlight()
        XCTAssertEqual(camera, MissionDebriefCamera())
        assertPoint(fit.applying(camera).point(for: fixedPosition), equals: fit.point(for: fixedPosition))
    }

    func testDebriefCanPanEveryFullSourceEdgeIntoViewAtAnyZoom() {
        let size = CGSize(width: 725, height: 760)
        // Fit a tiny flight near one corner: the other edges start far offscreen.
        let fit = MissionChartProjection(positions: [CGPoint(x: 0.99, y: 0.01)], size: size)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        for zoom: CGFloat in [0.5, 1, 16] {
            for edge in [CGPoint.zero, CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1)] {
                var camera = MissionDebriefCamera()
                camera.zoom(by: zoom, anchoredAt: center, in: size)
                let point = fit.applying(camera).point(for: edge)
                camera.move(by: CGSize(width: center.x - point.x, height: center.y - point.y))
                let projected = fit.applying(camera)
                assertPoint(projected.point(for: edge), equals: center, accuracy: 1e-8)
                XCTAssertEqual(projected.sourceImageRect.width / projected.sourceImageRect.height,
                               FlightWorld.sourceAspect, accuracy: 1e-10)
            }
        }
    }

    func testDebriefFitsDifferentLayoutsWithoutChangingCompletedSnapshot() {
        let initial = FlightAircraftState(normalizedPosition: CGPoint(x: 0, y: 0.9), heading: 90, speedKnots: 120)
        let mission = MissionFlightDefinition(id: "generated", title: "Another mission", initialState: initial,
            plannedPoints: [MissionChartPoint(name: "Route origin", normalizedPosition: CGPoint(x: 0.1, y: 0.1)),
                            MissionChartPoint(name: "Route end", normalizedPosition: CGPoint(x: 1, y: 0.5))],
            arrivalReference: MissionChartPoint(name: "Arrival reference", normalizedPosition: CGPoint(x: 0.4, y: 1)))
        let completion = MissionFlightCompletion(mission: mission,
            recording: [FlightSample(simulatedSeconds: 0, aircraftState: initial),
                        FlightSample(simulatedSeconds: 123.456,
                            aircraftState: FlightAircraftState(normalizedPosition: CGPoint(x: 0.2, y: 0), heading: 80, speedKnots: 120))],
            conditions: .calm, ending: .playerCompleted)
        let saved = completion
        let positions = completion.recording.map { $0.aircraftState.normalizedPosition }
            + completion.mission.plannedPoints.map(\.normalizedPosition)
            + [completion.mission.arrivalReference!.normalizedPosition]
        var camera = MissionDebriefCamera()
        for size in [CGSize(width: 725, height: 760), CGSize(width: 1_100, height: 900), CGSize(width: 760, height: 1_000)] {
            camera.fitFlight() // The view resets on layout changes, using these same values.
            let fitRect = CGRect(x: 64, y: 104, width: size.width - 128, height: size.height - 208)
            let fit = MissionChartProjection(positions: positions, size: size, fitRect: fitRect)
            for position in positions {
                let point = fit.applying(camera).point(for: position)
                XCTAssertGreaterThanOrEqual(point.x, fitRect.minX - 1e-9)
                XCTAssertLessThanOrEqual(point.x, fitRect.maxX + 1e-9)
                XCTAssertGreaterThanOrEqual(point.y, fitRect.minY - 1e-9)
                XCTAssertLessThanOrEqual(point.y, fitRect.maxY + 1e-9)
            }
            camera.zoom(by: 4, anchoredAt: CGPoint(x: 90, y: 190), in: size)
            camera.move(by: CGSize(width: -900, height: 700))
            XCTAssertEqual(completion, saved)
            camera.fitFlight()
            XCTAssertEqual(camera.zoom, 1)
            XCTAssertEqual(camera.pan, .zero)
            XCTAssertEqual(completion.recording.last?.simulatedSeconds, 123.456)
        }
    }

    func testDebriefCoincidentAndEdgeLabelsStaySeparateAndInsideMargin() {
        let bounds = CGRect(x: 48, y: 48, width: 629, height: 664)
        let controls = [CGRect(x: 16, y: 40, width: 100, height: 44),
                        CGRect(x: 485, y: 40, width: 224, height: 44),
                        CGRect(x: 16, y: 696, width: 230, height: 48)]
        for anchor in [CGPoint(x: 64, y: 104), CGPoint(x: 661, y: 104),
                       CGPoint(x: 64, y: 656), CGPoint(x: 661, y: 656), CGPoint(x: 350, y: 380)] {
            let inputs = [CGSize(width: 50, height: 22), CGSize(width: 60, height: 22), CGSize(width: 180, height: 36)]
                .map { MissionDebriefMarkerLayout.Input(anchor: anchor, labelSize: $0) }
            let placements = MissionDebriefMarkerLayout.place(inputs, in: bounds, avoiding: controls)
            XCTAssertEqual(placements.count, 3)
            for (index, placement) in placements.enumerated() {
                XCTAssertTrue(bounds.contains(placement.labelRect))
                XCTAssertFalse(controls.contains { $0.intersects(placement.labelRect) })
                XCTAssertTrue(bounds.contains(CGRect(x: placement.symbolCenter.x - 10,
                                                     y: placement.symbolCenter.y - 10, width: 20, height: 20)))
                for other in placements.dropFirst(index + 1) {
                    XCTAssertFalse(placement.labelRect.intersects(other.labelRect))
                    XCTAssertGreaterThanOrEqual(hypot(placement.symbolCenter.x - other.symbolCenter.x,
                                                     placement.symbolCenter.y - other.symbolCenter.y), 24)
                }
                for other in placements {
                    XCTAssertFalse(placement.labelRect.intersects(CGRect(x: other.symbolCenter.x - 10,
                                                                        y: other.symbolCenter.y - 10, width: 20, height: 20)))
                }
            }
        }
    }

    private func makeTimingMission(distances: [Double] = [20, 4],
                                   policy: MissionTimingSchedule.StartupPolicy = .firstLegOnFirstPlay,
                                   initial: FlightAircraftState? = nil) -> MissionFlightDefinition {
        MissionFlightDefinition(id: "timed-test", title: "Independent timing inputs",
            initialState: initial ?? FlightAircraftState(normalizedPosition: CGPoint(x: 0.5, y: 0.5),
                                                       heading: 90, speedKnots: 120),
            instructions: [MissionInstruction(title: "First instruction"), MissionInstruction(title: "Second instruction")],
            timingSchedule: MissionTimingSchedule(legs: distances.map {
                .init(startLabel: "Repeated label", endLabel: "Repeated label", distanceNM: $0)
            }, planningAirspeedKnots: 120, startupPolicy: policy))
    }

    private struct WindTestGenerator: RandomNumberGenerator {
        var calls = 0
        var state: UInt64 = 42
        mutating func next() -> UInt64 {
            calls += 1
            state = state &* 6_364_136_223_846_793_005 &+ 1
            return state
        }
    }

    private func makeStation(identifier: String,
                             frequency: Double = 116.8,
                             x: Double = 0.5,
                             y: Double = 0.5) -> VORStation {
        VORStation(
            id: identifier,
            name: "Test Station",
            identifier: identifier,
            frequency: frequency,
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
