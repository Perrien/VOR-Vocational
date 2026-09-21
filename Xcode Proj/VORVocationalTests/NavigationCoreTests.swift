import XCTest
import CoreGraphics
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

    func testFreshFlightSessionDefaults() {
        let position = CGPoint(x: 0.5067, y: 0.6889)
        let session = FlightSession(normalizedAirportPosition: position)

        assertPoint(session.normalizedAircraftPosition, equals: position)
        XCTAssertEqual(session.heading, 0)
        XCTAssertEqual(session.speedKnots, 260)
        XCTAssertFalse(session.isFlying)
        XCTAssertEqual(session.timeMultiplier, 1)
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
        XCTAssertEqual(session.gridSizeNM, 50)
    }

    func testFlightSurfaceConfigurationPresets() {
        XCTAssertEqual(
            .freeFlight,
            FlightSurfaceConfiguration(
                showsAirportsByDefault: true,
                allowsAircraftSimulation: true,
                showsHeadingPresentation: true,
                showsFlightControls: true
            )
        )
        XCTAssertEqual(
            .positionChallenge,
            FlightSurfaceConfiguration(
                showsAirportsByDefault: false,
                allowsAircraftSimulation: false,
                showsHeadingPresentation: true,
                showsFlightControls: false
            )
        )
    }

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

    private func makeStation(identifier: String) -> VORStation {
        VORStation(
            id: identifier,
            name: "Test Station",
            identifier: identifier,
            frequency: 116.8,
            location: VORStation.Location(x: 0.5, y: 0.5),
            type: .vor,
            serviceVolume: .high,
            elevationFT: 100,
            dme: false
        )
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
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(point.x, expected.x, accuracy: 0.000_001, file: file, line: line)
        XCTAssertEqual(point.y, expected.y, accuracy: 0.000_001, file: file, line: line)
    }
}
