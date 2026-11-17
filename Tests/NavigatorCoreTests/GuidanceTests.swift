import XCTest
@testable import NavigatorCore

final class GuidanceTests: XCTestCase {
    private func demoGuidance() throws -> RouteGuidance {
        let planner = RoutePlanner(map: try TestSupport.demoMap())
        let route = try XCTUnwrap(planner.route(from: "plaza", to: "room-201").successValue)
        return RouteGuidance(route: route)
    }

    func testStartsByConfirmingStartingPoint() throws {
        let guidance = try demoGuidance()
        XCTAssertEqual(guidance.current.kind, .confirmStart)
        XCTAssertEqual(guidance.current.confirmLabel, "I'm at North Plaza (outside)")
        XCTAssertNil(guidance.previous)
        XCTAssertEqual(guidance.next?.kind, .travel(legIndex: 0))
        XCTAssertEqual(guidance.steps.count, guidance.route.legs.count + 2)
    }

    func testAdvancesOnlyWhenConfirmedAndCanGoBack() throws {
        var guidance = try demoGuidance()
        guidance.confirmCurrentStep()
        XCTAssertEqual(guidance.current.kind, .travel(legIndex: 0))
        XCTAssertTrue(guidance.current.instruction.contains("five front steps"))
        XCTAssertEqual(guidance.current.confirmLabel, "I've reached Main Entrance lobby")
        XCTAssertEqual(guidance.previous?.kind, .confirmStart)

        guidance.goBack()
        XCTAssertEqual(guidance.current.kind, .confirmStart)
        guidance.goBack()  // no-op at the first step
        XCTAssertEqual(guidance.current.kind, .confirmStart)
    }

    func testReachesArrivalAndStops() throws {
        var guidance = try demoGuidance()
        for _ in 0..<50 { guidance.confirmCurrentStep() }
        XCTAssertTrue(guidance.isFinished)
        XCTAssertEqual(guidance.current.instruction, "You have arrived at Room 201 (demo lab).")
        XCTAssertNil(guidance.current.confirmLabel)
        XCTAssertNil(guidance.next)
    }

    func testDetailsNeverInventLengthForStairs() throws {
        let guidance = try demoGuidance()
        let stairsStep = try XCTUnwrap(guidance.steps.first { $0.details.first == "Stairs: Stairwell A stairs" })
        XCTAssertTrue(stairsStep.details.contains("Length not recorded"))
        XCTAssertFalse(stairsStep.spokenText.contains(" m "))

        let frontStepsStep = guidance.steps[1]
        XCTAssertTrue(frontStepsStep.details.contains("Recorded length: about 6 m (simulated)"))
    }

    func testDetailsDoNotMentionStepFreeStatus() throws {
        let guidance = try demoGuidance()
        let allDetails = guidance.steps.flatMap(\.details).joined(separator: " ")
        XCTAssertFalse(allDetails.localizedCaseInsensitiveContains("step-free"))
    }

    func testSpokenTextOnlyUsesAuthoredContent() throws {
        let guidance = try demoGuidance()
        let step = guidance.steps[1]
        XCTAssertEqual(step.spokenText, "\(step.instruction) Arrival cue: \(step.arrivalCue!)")
    }
}
