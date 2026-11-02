import Foundation
@testable import NavigatorCore

enum TestSupport {
    /// Loads the real demo map file from the repository, so the tests check the exact
    /// data the app ships with.
    static func demoMapData() throws -> Data {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // NavigatorCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repository root
            .appendingPathComponent("UBAccessNavigator/Resources/demo_map.json")
        return try Data(contentsOf: url)
    }

    static func demoMap() throws -> CampusMap {
        try CampusMap.load(from: demoMapData())
    }

    // MARK: Tiny hand-built maps for edge cases

    static func landmark(_ id: String, floor: String = "f1") -> Landmark {
        Landmark(id: id, name: id.uppercased(), floorID: floor, kind: .junction,
                 arrivalCue: "Cue for \(id)", canStartHere: true, isDestination: true, schematic: nil)
    }

    static func connection(
        _ id: String,
        _ from: String,
        _ to: String,
        type: ConnectionType = .corridor,
        length: Double? = 10,
        cost: Double? = nil,
        stepFree: StepFreeSuitability = .confirmed,
        availability: Availability = .available,
        direction: Directionality = .bidirectional
    ) -> Connection {
        Connection(
            id: id, name: id, from: from, to: to, type: type, direction: direction,
            lengthMeters: length, routingCost: cost, stepFree: stepFree, availability: availability,
            verification: Verification(status: .simulated, source: "test"),
            instructions: Instructions(
                forward: "Go from \(from) to \(to).",
                reverse: direction == .bidirectional ? "Go from \(to) to \(from)." : nil
            )
        )
    }

    static func map(landmarks: [Landmark], connections: [Connection]) -> CampusMap {
        CampusMap(
            schemaVersion: 1, id: "test", name: "Test map", dataStatus: .fictionalDemo,
            disclaimer: "Test data", floors: [Floor(id: "f1", name: "Floor 1", level: 1)],
            landmarks: landmarks, connections: connections
        )
    }
}

extension Result {
    var successValue: Success? {
        if case .success(let value) = self { return value }
        return nil
    }

    var failureValue: Failure? {
        if case .failure(let error) = self { return error }
        return nil
    }
}
