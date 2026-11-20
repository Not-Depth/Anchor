import XCTest
@testable import NavigatorCore

final class FloorChangeTests: XCTestCase {
    func testExpectedChangeFromLevels() {
        XCTAssertNil(ExpectedFloorChange(fromLevel: 1, toLevel: 1))
        XCTAssertNil(ExpectedFloorChange(fromLevel: nil, toLevel: 2))
        XCTAssertEqual(ExpectedFloorChange(fromLevel: 1, toLevel: 2), ExpectedFloorChange(direction: .up, floors: 1))
        XCTAssertEqual(ExpectedFloorChange(fromLevel: 3, toLevel: 1), ExpectedFloorChange(direction: .down, floors: 2))
    }

    func testWaitsForAReading() {
        XCTAssertEqual(FloorChangeDetector().estimate, .waiting)
    }

    func testNoiseOnOneFloorIsNotAFloorChange() {
        var detector = FloorChangeDetector()
        for reading in [10.0, 10.4, 9.7, 10.6, 9.5, 10.3] {
            detector.add(relativeAltitude: reading)
        }
        XCTAssertEqual(detector.estimate, .sameFloor)
    }

    func testClimbingOneStoreyIsUpOneFloor() {
        var detector = FloorChangeDetector()
        for reading in stride(from: 0.0, through: 3.6, by: 0.4) {
            detector.add(relativeAltitude: reading)
        }
        XCTAssertEqual(detector.estimate, .changed(.up, floors: 1))
    }

    func testLargerChangesCountFloors() {
        var up = FloorChangeDetector()
        for reading in [0.0, 7.0, 7.1, 7.2] { up.add(relativeAltitude: reading) }
        XCTAssertEqual(up.estimate, .changed(.up, floors: 2))

        var down = FloorChangeDetector()
        for reading in [5.0, 1.7, 1.6, 1.6] { down.add(relativeAltitude: reading) }
        XCTAssertEqual(down.estimate, .changed(.down, floors: 1))
    }

    func testOneSpikeDoesNotFlipTheResult() {
        var detector = FloorChangeDetector()
        for reading in [0.0, 0.1, 4.0, 0.2] {
            detector.add(relativeAltitude: reading)
        }
        XCTAssertEqual(detector.estimate, .sameFloor)
    }

    func testResetMeasuresFromTheNextReading() {
        var detector = FloorChangeDetector()
        for reading in [0.0, 3.5, 3.5, 3.5] { detector.add(relativeAltitude: reading) }
        detector.reset()
        XCTAssertEqual(detector.estimate, .waiting)
        for reading in [3.5, 3.6, 3.4] { detector.add(relativeAltitude: reading) }
        XCTAssertEqual(detector.estimate, .sameFloor)
    }

    func testIgnoresNonFiniteReadings() {
        var detector = FloorChangeDetector()
        detector.add(relativeAltitude: .nan)
        XCTAssertEqual(detector.estimate, .waiting)
    }

    func testCheckAgainstExpectedChange() {
        let up = ExpectedFloorChange(direction: .up, floors: 1)
        XCTAssertEqual(FloorCheck(expected: up, estimate: .waiting), .waiting)
        XCTAssertEqual(FloorCheck(expected: up, estimate: .sameFloor), .notYet)
        XCTAssertEqual(FloorCheck(expected: up, estimate: .changed(.up, floors: 1)), .matches)
        XCTAssertEqual(FloorCheck(expected: up, estimate: .changed(.down, floors: 1)), .wrongDirection(sensed: .down))
        XCTAssertEqual(FloorCheck(expected: up, estimate: .changed(.up, floors: 2)), .wrongCount(sensedFloors: 2))
    }

    func testCheckWording() {
        let up = ExpectedFloorChange(direction: .up, floors: 1)
        XCTAssertEqual(FloorCheck.matches.displayText(expected: up), "Floor check: you went up 1 floor, as expected.")
        XCTAssertEqual(FloorCheck.wrongDirection(sensed: .down).displayText(expected: up),
                       "Floor check: Anchor sensed you going down, but this step goes up.")
        XCTAssertEqual(FloorCheck.wrongCount(sensedFloors: 2).displayText(expected: up),
                       "Floor check: Anchor sensed about 2 floors, but this step changes 1 floor.")
        XCTAssertEqual(FloorCheck.matches.spokenText(expected: up), "Floor change sensed: you went up 1 floor.")
        XCTAssertNil(FloorCheck.notYet.spokenText(expected: up))
        XCTAssertNil(FloorCheck.waiting.spokenText(expected: up))
    }
}

final class FloorGuidanceTests: XCTestCase {
    func testOnlyTheStairsStepChangesFloor() throws {
        let map = try TestSupport.demoMap()
        let route = try RoutePlanner(map: map).route(from: "plaza", to: "room-201").get()
        let steps = RouteGuidance(route: route).steps
        let changing = steps.filter { $0.floorChange != nil }
        XCTAssertEqual(changing.count, 1)
        XCTAssertEqual(changing.first?.details.first, "Stairs: Stairwell A stairs")
        XCTAssertEqual(changing.first?.floorChange, ExpectedFloorChange(direction: .up, floors: 1))
    }

    func testGoingDownstairsExpectsDown() throws {
        let map = try TestSupport.demoMap()
        let route = try RoutePlanner(map: map).route(from: "room-201", to: "room-105").get()
        let changes = RouteGuidance(route: route).steps.compactMap(\.floorChange)
        XCTAssertEqual(changes, [ExpectedFloorChange(direction: .down, floors: 1)])
    }

    func testFloorPhrasesAreInTheVoiceCatalog() throws {
        let catalog = Set(SpokenPhrases.all(in: try TestSupport.demoMap()))
        XCTAssertTrue(catalog.contains("Floor change sensed: you went up 1 floor."))
        XCTAssertTrue(catalog.contains("Floor change sensed: you went down 1 floor."))
        XCTAssertTrue(catalog.contains(SpokenPhrases.floorChangeWrongDirection))
        XCTAssertTrue(catalog.contains(SpokenPhrases.floorChangeWrongCount))
    }
}
