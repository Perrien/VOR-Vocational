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
