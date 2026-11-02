import XCTest
@testable import NavigatorCore

final class MapTests: XCTestCase {
    func testDemoMapLoadsWithoutValidationErrors() throws {
        let map = try TestSupport.demoMap()
        let errors = MapValidator.validate(map).filter { $0.severity == .error }
        XCTAssertEqual(errors, [])
        XCTAssertEqual(map.floors.count, 2)
        XCTAssertTrue((8...12).contains(map.landmarks.count), "Milestone asks for about 8-12 landmarks")
    }

    func testDemoMapIsClearlyFictional() throws {
        let map = try TestSupport.demoMap()
        XCTAssertEqual(map.dataStatus, .fictionalDemo)
        XCTAssertTrue(map.isFictional)
        XCTAssertTrue(map.name.localizedCaseInsensitiveContains("fictional"))
        XCTAssertTrue(map.disclaimer.localizedCaseInsensitiveContains("fictional"))
        XCTAssertTrue(map.connections.allSatisfy { $0.verification.status == .simulated })
        // The map must never present itself as real Davis Hall data.
        XCTAssertFalse(map.name.localizedCaseInsensitiveContains("Davis"))
    }

    func testDemoMapContainsRequiredFeatures() throws {
        let map = try TestSupport.demoMap()
        let kinds = Set(map.landmarks.map(\.kind))
        XCTAssertTrue(kinds.contains(.entrance))
        XCTAssertTrue(kinds.contains(.junction))
        XCTAssertTrue(kinds.contains(.room))
        let types = Set(map.connections.map(\.type))
        XCTAssertTrue(types.isSuperset(of: [.stairs, .elevator, .ramp, .bridge, .corridor]))
    }

    func testValidatorRejectsStairsMarkedStepFree() {
        var map = TestSupport.map(
            landmarks: [TestSupport.landmark("a"), TestSupport.landmark("b")],
            connections: [TestSupport.connection("s", "a", "b", type: .stairs, stepFree: .confirmed)]
        )
        XCTAssertTrue(MapValidator.validate(map).contains { $0.message.contains("stairs but is marked step-free") })

        map.connections[0].stepFree = .unsuitable
        XCTAssertEqual(MapValidator.validate(map).filter { $0.severity == .error }, [])
    }

    func testValidatorRejectsVerifiedClaimsInFictionalMap() {
        var connection = TestSupport.connection("c", "a", "b")
        connection.verification = Verification(status: .verified, source: "x", checkedOn: "2026-11-01", checkedBy: "J")
        let map = TestSupport.map(landmarks: [TestSupport.landmark("a"), TestSupport.landmark("b")],
                                  connections: [connection])
        XCTAssertTrue(MapValidator.validate(map).contains { $0.message.contains("fictional map but claims") })
    }

    func testValidatorRequiresReverseInstructionForBidirectional() {
        var connection = TestSupport.connection("c", "a", "b")
        connection.instructions.reverse = nil
        let map = TestSupport.map(landmarks: [TestSupport.landmark("a"), TestSupport.landmark("b")],
                                  connections: [connection])
        XCTAssertTrue(MapValidator.validate(map).contains { $0.message.contains("no reverse instruction") })
    }

    func testValidatorRejectsUnknownLandmarkAndMissingCost() {
        let connection = TestSupport.connection("c", "a", "missing", length: nil, cost: nil)
        let map = TestSupport.map(landmarks: [TestSupport.landmark("a")], connections: [connection])
        let messages = MapValidator.validate(map).map(\.message)
        XCTAssertTrue(messages.contains { $0.contains("unknown landmark 'missing'") })
        XCTAssertTrue(messages.contains { $0.contains("needs lengthMeters or routingCost") })
    }

    func testLoadingInvalidJSONGivesReadableError() {
        let data = Data(#"{"schemaVersion": 1}"#.utf8)
        XCTAssertThrowsError(try CampusMap.load(from: data)) { error in
            guard case MapLoadError.decodingFailed(let message) = error else {
                return XCTFail("Expected decodingFailed, got \(error)")
            }
            XCTAssertTrue(message.contains("missing key"))
        }
    }

    func testAvailabilityOverrideLeavesSuitabilityUntouched() throws {
        let map = try TestSupport.demoMap()
        let changed = map.applying(availabilityOverrides: ["elevator-a": .unavailable])
        let elevator = try XCTUnwrap(changed.connections.first { $0.id == "elevator-a" })
        XCTAssertEqual(elevator.availability, .unavailable)
        XCTAssertEqual(elevator.stepFree, .confirmed)
    }
}
