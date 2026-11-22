import XCTest
@testable import NavigatorCore

final class RoutePlannerTests: XCTestCase {
    private func legIDs(_ route: Route) -> [String] {
        route.legs.map(\.connection.id)
    }

    // MARK: Demo map scenarios

    func testShortestRouteUsesTheStairs() throws {
        let planner = RoutePlanner(map: try TestSupport.demoMap())
        let route = try XCTUnwrap(planner.route(from: "plaza", to: "room-201").successValue)

        XCTAssertEqual(legIDs(route), [
            "front-steps", "lobby-doors", "west-to-stairwell",
            "stairwell-a-stairs", "f2-stairwell-to-central", "central-to-room-201",
        ])
        XCTAssertTrue(route.usesStairs)
        XCTAssertEqual(route.totalRoutingCost, 47)
        XCTAssertTrue(route.usesSimulatedData)
    }

    func testClosedStairwellReroutesThroughTheElevator() throws {
        let map = TestSupport.setting(.unavailable, on: ["stairwell-a-stairs"], in: try TestSupport.demoMap())
        let route = try XCTUnwrap(RoutePlanner(map: map).route(from: "plaza", to: "room-201").successValue)

        XCTAssertEqual(legIDs(route), [
            "front-steps", "lobby-doors", "main-corridor", "east-to-elevator",
            "elevator-a", "f2-elevator-to-central", "central-to-room-201",
        ])
        XCTAssertFalse(legIDs(route).contains("stairwell-a-stairs"))
        // The elevator has no recorded length, so it is counted as unknown rather than invented.
        XCTAssertEqual(route.legsWithUnknownLength, 1)
        XCTAssertEqual(route.recordedLengthMeters, 6 + 8 + 25 + 10 + 20 + 6)
    }

    func testEveryWayUpstairsClosedExplainsTheBlocker() throws {
        let map = TestSupport.setting(.unavailable, on: ["stairwell-a-stairs", "elevator-a"], in: try TestSupport.demoMap())

        let failure = RoutePlanner(map: map).route(from: "plaza", to: "room-201").failureValue
        guard case .noSuitableRoute(let diagnosis)? = failure else {
            return XCTFail("Expected noSuitableRoute, got \(String(describing: failure))")
        }
        XCTAssertEqual(diagnosis.reason, .blockedByUnavailableConnections)
        XCTAssertEqual(diagnosis.blockingConnections.map(\.id), ["stairwell-a-stairs"])
        XCTAssertTrue(diagnosis.explanation.contains("Stairwell A stairs (unavailable)"))
    }

    func testUnknownAvailabilityIsAllowedButWarned() throws {
        let planner = RoutePlanner(map: try TestSupport.demoMap())
        let route = try XCTUnwrap(planner.route(from: "plaza", to: "annex-reading-room").successValue)
        XCTAssertEqual(route.legs.last?.connection.id, "annex-skybridge")
        XCTAssertEqual(route.warnings, ["Skybridge to Annex: current availability is not confirmed."])
    }

    func testOneWayExitDoorIsOnlyUsedInItsDirection() throws {
        let planner = RoutePlanner(map: try TestSupport.demoMap())

        let outbound = try XCTUnwrap(planner.route(from: "room-105", to: "plaza").successValue)
        XCTAssertEqual(legIDs(outbound), ["east-to-room-105", "east-exit-door"])

        let inbound = try XCTUnwrap(planner.route(from: "plaza", to: "room-105").successValue)
        XCTAssertFalse(legIDs(inbound).contains("east-exit-door"))
        XCTAssertEqual(legIDs(inbound), ["front-steps", "lobby-doors", "main-corridor", "east-to-room-105"])
    }

    func testReverseInstructionIsUsedWhenTravelingBackwards() throws {
        let planner = RoutePlanner(map: try TestSupport.demoMap())
        let route = try XCTUnwrap(planner.route(from: "room-201", to: "room-105").successValue)

        let stairsLeg = try XCTUnwrap(route.legs.first { $0.connection.id == "stairwell-a-stairs" })
        XCTAssertTrue(stairsLeg.isReversed)
        XCTAssertTrue(stairsLeg.instruction.contains("Go down the stairs to Floor 1"))
        XCTAssertEqual(route.landmarksInOrder.first?.id, "room-201")
        XCTAssertEqual(route.landmarksInOrder.last?.id, "room-105")
    }

    func testEveryDemoRouteIsConnectedAndUsesOnlyUsableConnections() throws {
        // Covers every start/destination pair, not just the named examples above.
        let map = try TestSupport.demoMap()
        let planner = RoutePlanner(map: map)
        for start in map.startLandmarks {
            for destination in map.destinationLandmarks where destination.id != start.id {
                let route = try XCTUnwrap(planner.route(from: start.id, to: destination.id).successValue,
                                          "\(start.id) -> \(destination.id)")
                var current = start.id
                for leg in route.legs {
                    XCTAssertEqual(leg.from.id, current)
                    XCTAssertNotEqual(leg.connection.availability, .unavailable)
                    XCTAssertFalse(leg.instruction.isEmpty)
                    if leg.isReversed { XCTAssertEqual(leg.connection.direction, .bidirectional) }
                    current = leg.to.id
                }
                XCTAssertEqual(current, destination.id)
            }
        }
    }

    // MARK: Edge cases on small maps

    func testDisconnectedDestinationReportsNotConnected() {
        let map = TestSupport.map(
            landmarks: ["a", "b", "island"].map { TestSupport.landmark($0) },
            connections: [TestSupport.connection("ab", "a", "b")]
        )
        let failure = RoutePlanner(map: map).route(from: "a", to: "island").failureValue
        XCTAssertEqual(failure, .noSuitableRoute(NoRouteDiagnosis(reason: .notConnected, blockingConnections: [])))
    }

    func testSameStartAndDestinationAndUnknownIDs() throws {
        let planner = RoutePlanner(map: try TestSupport.demoMap())
        XCTAssertEqual(planner.route(from: "plaza", to: "plaza").failureValue, .sameStartAndDestination)
        XCTAssertEqual(planner.route(from: "nowhere", to: "plaza").failureValue, .unknownLandmark("nowhere"))
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
        let route = RoutePlanner(map: map).route(from: "a", to: "c").successValue
        XCTAssertEqual(route.map(legIDs), ["ab", "bc"])
    }

    func testOnlyRouteClosedGivesNoRouteInsteadOfUsingIt() {
        let map = TestSupport.map(
            landmarks: ["a", "b", "c"].map { TestSupport.landmark($0) },
            connections: [
                TestSupport.connection("hall", "a", "b"),
                TestSupport.connection("lift", "b", "c", type: .elevator, length: nil, cost: 20, availability: .unavailable),
            ]
        )
        let failure = RoutePlanner(map: map).route(from: "a", to: "c").failureValue
        guard case .noSuitableRoute(let diagnosis)? = failure else {
            return XCTFail("Expected noSuitableRoute")
        }
        XCTAssertEqual(diagnosis.reason, .blockedByUnavailableConnections)
        XCTAssertEqual(diagnosis.blockingConnections.map(\.id), ["lift"])
    }

    func testRoutingCostCanOverrideLength() {
        // The elevator is physically short but slow (waiting), so the corridor wins.
        let map = TestSupport.map(
            landmarks: ["a", "b"].map { TestSupport.landmark($0) },
            connections: [
                TestSupport.connection("lift", "a", "b", type: .elevator, length: 2, cost: 40),
                TestSupport.connection("hall", "a", "b", type: .corridor, length: 30),
            ]
        )
        let route = RoutePlanner(map: map).route(from: "a", to: "b").successValue
        XCTAssertEqual(route.map(legIDs), ["hall"])
    }
}
