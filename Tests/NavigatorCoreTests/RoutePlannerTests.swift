import XCTest
@testable import NavigatorCore

final class RoutePlannerTests: XCTestCase {
    private let anyRoute = RoutePreferences(requireStepFree: false)
    private let stepFree = RoutePreferences(requireStepFree: true)

    private func legIDs(_ route: Route) -> [String] {
        route.legs.map(\.connection.id)
    }

    // MARK: Demo map scenarios

    func testShortestRouteUsesStairsWhenStepFreeIsOff() throws {
        let planner = RoutePlanner(map: try TestSupport.demoMap())
        let route = try XCTUnwrap(planner.route(from: "plaza", to: "room-201", preferences: anyRoute).successValue)

        XCTAssertEqual(legIDs(route), [
            "front-steps", "lobby-doors", "west-to-stairwell",
            "stairwell-a-stairs", "f2-stairwell-to-central", "central-to-room-201",
        ])
        XCTAssertTrue(route.usesStairs)
        XCTAssertEqual(route.totalRoutingCost, 47)
        XCTAssertTrue(route.usesSimulatedData)
    }

    func testStepFreeRouteUsesRampAndElevatorAndNeverStairs() throws {
        let planner = RoutePlanner(map: try TestSupport.demoMap())
        let route = try XCTUnwrap(planner.route(from: "plaza", to: "room-201", preferences: stepFree).successValue)

        XCTAssertEqual(legIDs(route), [
            "west-ramp", "lobby-doors", "main-corridor", "east-to-elevator",
            "elevator-a", "f2-elevator-to-central", "central-to-room-201",
        ])
        XCTAssertFalse(route.usesStairs)
        XCTAssertTrue(route.legs.allSatisfy { $0.connection.stepFree == .confirmed })
        // Elevator has no recorded length, so it is counted as unknown rather than invented.
        XCTAssertEqual(route.legsWithUnknownLength, 1)
        XCTAssertEqual(route.recordedLengthMeters, 18 + 8 + 25 + 10 + 20 + 6)
    }

    func testElevatorOutageGivesNoRouteInsteadOfFallingBackToStairs() throws {
        let map = try TestSupport.demoMap().applying(availabilityOverrides: ["elevator-a": .unavailable])
        let planner = RoutePlanner(map: map)

        let failure = planner.route(from: "plaza", to: "room-201", preferences: stepFree).failureValue
        guard case .noSuitableRoute(let diagnosis)? = failure else {
            return XCTFail("Expected noSuitableRoute, got \(String(describing: failure))")
        }
        XCTAssertEqual(diagnosis.reason, .blockedByUnavailableConnections)
        XCTAssertEqual(diagnosis.blockingConnections.map(\.id), ["elevator-a"])
        XCTAssertTrue(diagnosis.explanation.contains("Elevator A"))

        // Without the step-free requirement, the stairs route is still offered.
        XCTAssertNotNil(planner.route(from: "plaza", to: "room-201", preferences: anyRoute).successValue)
    }

    func testUnknownStepFreeSuitabilityIsExcludedNotPenalized() throws {
        let planner = RoutePlanner(map: try TestSupport.demoMap())

        let failure = planner.route(from: "plaza", to: "annex-reading-room", preferences: stepFree).failureValue
        guard case .noSuitableRoute(let diagnosis)? = failure else {
            return XCTFail("Expected noSuitableRoute, got \(String(describing: failure))")
        }
        XCTAssertEqual(diagnosis.reason, .blockedByStepFreeRequirement)
        // Only the unavoidable blocker is listed; Floor 2 itself is reachable by elevator.
        XCTAssertEqual(diagnosis.blockingConnections.map(\.id), ["annex-skybridge"])
        XCTAssertTrue(diagnosis.explanation.contains("step-free suitability unknown"))
    }

    func testUnknownAvailabilityIsAllowedButWarned() throws {
        let planner = RoutePlanner(map: try TestSupport.demoMap())
        let route = try XCTUnwrap(planner.route(from: "plaza", to: "annex-reading-room", preferences: anyRoute).successValue)
        XCTAssertEqual(route.legs.last?.connection.id, "annex-skybridge")
        XCTAssertTrue(route.warnings.contains { $0.contains("Skybridge to Annex: current availability is not confirmed") })
        XCTAssertTrue(route.warnings.contains { $0.contains("step-free suitability is unknown") })
    }

    func testOneWayExitDoorIsOnlyUsedInItsDirection() throws {
        let planner = RoutePlanner(map: try TestSupport.demoMap())

        let outbound = try XCTUnwrap(planner.route(from: "room-105", to: "plaza", preferences: stepFree).successValue)
        XCTAssertEqual(legIDs(outbound), ["east-to-room-105", "east-exit-door"])

        let inbound = try XCTUnwrap(planner.route(from: "plaza", to: "room-105", preferences: stepFree).successValue)
        XCTAssertFalse(legIDs(inbound).contains("east-exit-door"))
        XCTAssertEqual(legIDs(inbound), ["west-ramp", "lobby-doors", "main-corridor", "east-to-room-105"])
    }

    func testReverseInstructionIsUsedWhenTravelingBackwards() throws {
        let planner = RoutePlanner(map: try TestSupport.demoMap())
        let route = try XCTUnwrap(planner.route(from: "room-201", to: "room-105", preferences: stepFree).successValue)

        let elevatorLeg = try XCTUnwrap(route.legs.first { $0.connection.id == "elevator-a" })
        XCTAssertTrue(elevatorLeg.isReversed)
        XCTAssertTrue(elevatorLeg.instruction.contains("select Floor 1"))
        XCTAssertEqual(route.landmarksInOrder.first?.id, "room-201")
        XCTAssertEqual(route.landmarksInOrder.last?.id, "room-105")
    }

    // MARK: Edge cases on small maps

    func testDisconnectedDestinationReportsNotConnected() {
        let map = TestSupport.map(
            landmarks: ["a", "b", "island"].map { TestSupport.landmark($0) },
            connections: [TestSupport.connection("ab", "a", "b")]
        )
        let failure = RoutePlanner(map: map).route(from: "a", to: "island", preferences: anyRoute).failureValue
        XCTAssertEqual(failure, .noSuitableRoute(NoRouteDiagnosis(reason: .notConnected, blockingConnections: [])))
    }

    func testSameStartAndDestinationAndUnknownIDs() throws {
        let planner = RoutePlanner(map: try TestSupport.demoMap())
        XCTAssertEqual(planner.route(from: "plaza", to: "plaza", preferences: anyRoute).failureValue, .sameStartAndDestination)
        XCTAssertEqual(planner.route(from: "nowhere", to: "plaza", preferences: anyRoute).failureValue, .unknownLandmark("nowhere"))
    }

    func testUnavailableConnectionIsNeverUsed() {
        let map = TestSupport.map(
            landmarks: ["a", "b", "c"].map { TestSupport.landmark($0) },
            connections: [
                TestSupport.connection("short", "a", "c", length: 5, availability: .unavailable),
                TestSupport.connection("ab", "a", "b", length: 10),
                TestSupport.connection("bc", "b", "c", length: 10),
            ]
        )
        let route = RoutePlanner(map: map).route(from: "a", to: "c", preferences: anyRoute).successValue
        XCTAssertEqual(route.map(legIDs), ["ab", "bc"])
    }

    func testStairsExcludedEvenIfDataWronglyClaimsStepFree() {
        // MapValidator would reject this map; the planner still refuses as a second line of defense.
        let map = TestSupport.map(
            landmarks: ["a", "b"].map { TestSupport.landmark($0) },
            connections: [TestSupport.connection("bad", "a", "b", type: .stairs, stepFree: .confirmed)]
        )
        let failure = RoutePlanner(map: map).route(from: "a", to: "b", preferences: stepFree).failureValue
        guard case .noSuitableRoute(let diagnosis)? = failure else {
            return XCTFail("Expected noSuitableRoute")
        }
        XCTAssertEqual(diagnosis.reason, .blockedByStepFreeRequirement)
    }

    func testBlockedByBothReason() {
        let map = TestSupport.map(
            landmarks: ["a", "b", "c"].map { TestSupport.landmark($0) },
            connections: [
                TestSupport.connection("stairs", "a", "b", type: .stairs, stepFree: .unsuitable),
                TestSupport.connection("lift", "b", "c", type: .elevator, length: nil, cost: 20, availability: .unavailable),
            ]
        )
        let failure = RoutePlanner(map: map).route(from: "a", to: "c", preferences: stepFree).failureValue
        guard case .noSuitableRoute(let diagnosis)? = failure else {
            return XCTFail("Expected noSuitableRoute")
        }
        XCTAssertEqual(diagnosis.reason, .blockedByBoth)
        XCTAssertEqual(diagnosis.blockingConnections.map(\.id), ["stairs", "lift"])
    }

    func testRoutingCostCanOverrideLength() {
        // The elevator is physically short but slow (waiting), so the corridor wins.
        let map = TestSupport.map(
            landmarks: ["a", "b"].map { TestSupport.landmark($0) },
            connections: [
                TestSupport.connection("lift", "a", "b", type: .elevator, length: 2, cost: 40),
                TestSupport.connection("ramp", "a", "b", type: .ramp, length: 30),
            ]
        )
        let route = RoutePlanner(map: map).route(from: "a", to: "b", preferences: stepFree).successValue
        XCTAssertEqual(route.map(legIDs), ["ramp"])
    }
}
