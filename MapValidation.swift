import Foundation

/// A problem found in a map file. Errors stop the map from loading; warnings are shown
/// to the developer but do not block routing.
struct MapIssue: Equatable, CustomStringConvertible {
    enum Severity: String, Equatable {
        case error
        case warning
    }

    var severity: Severity
    var message: String

    var description: String { "[\(severity.rawValue)] \(message)" }

    static func error(_ message: String) -> MapIssue { MapIssue(severity: .error, message: message) }
    static func warning(_ message: String) -> MapIssue { MapIssue(severity: .warning, message: message) }
}

/// Checks a map for mistakes that would make routing wrong or misleading.
///
/// The most important rules are about honesty: stairs can never be marked step-free,
/// and a fictional map can never claim on-site verification.
enum MapValidator {
    static func validate(_ map: CampusMap) -> [MapIssue] {
        var issues: [MapIssue] = []

        // 1. Basic labelling.
        if map.disclaimer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.error("Map must include a disclaimer describing the data's limits."))
        }

        // 2. IDs must be unique, or lookups become ambiguous.
        issues += duplicateIDIssues(map.floors.map(\.id), kind: "floor")
        issues += duplicateIDIssues(map.landmarks.map(\.id), kind: "landmark")
        issues += duplicateIDIssues(map.connections.map(\.id), kind: "connection")

        // 3. Landmarks must sit on a real floor.
        let floorIDs = Set(map.floors.map(\.id))
        for landmark in map.landmarks where !floorIDs.contains(landmark.floorID) {
            issues.append(.error("Landmark '\(landmark.id)' refers to unknown floor '\(landmark.floorID)'."))
        }

        if !map.landmarks.contains(where: \.canStartHere) {
            issues.append(.error("Map has no landmark marked canStartHere."))
        }
        if !map.landmarks.contains(where: \.isDestination) {
            issues.append(.error("Map has no landmark marked isDestination."))
        }

        // 4. Connections.
        let landmarkIDs = Set(map.landmarks.map(\.id))
        for connection in map.connections {
            issues += validate(connection, landmarkIDs: landmarkIDs, mapStatus: map.dataStatus)
        }

        return issues
    }

    private static func validate(
        _ c: Connection,
        landmarkIDs: Set<String>,
        mapStatus: MapDataStatus
    ) -> [MapIssue] {
        var issues: [MapIssue] = []
        let label = "Connection '\(c.id)'"

        if !landmarkIDs.contains(c.from) {
            issues.append(.error("\(label) starts at unknown landmark '\(c.from)'."))
        }
        if !landmarkIDs.contains(c.to) {
            issues.append(.error("\(label) ends at unknown landmark '\(c.to)'."))
        }
        if c.from == c.to {
            issues.append(.error("\(label) connects a landmark to itself."))
        }

        // Dijkstra needs a positive, finite weight.
        if c.routingCost == nil && c.lengthMeters == nil {
            issues.append(.error("\(label) needs lengthMeters or routingCost."))
        }
        if let cost = c.routingCost, !(cost.isFinite && cost > 0) {
            issues.append(.error("\(label) routingCost must be a positive number."))
        }
        if let length = c.lengthMeters, !(length.isFinite && length >= 0) {
            issues.append(.error("\(label) lengthMeters must be zero or more."))
        }
        if c.routingCost == nil, let length = c.lengthMeters, length == 0 {
            issues.append(.error("\(label) has zero length; add a positive routingCost."))
        }

        // Instructions must exist for every direction that can be traveled.
        if c.instructions.forward.trimmingCharacters(in: .whitespaces).isEmpty {
            issues.append(.error("\(label) is missing a forward instruction."))
        }
        if c.direction == .bidirectional,
           (c.instructions.reverse ?? "").trimmingCharacters(in: .whitespaces).isEmpty {
            issues.append(.error("\(label) is bidirectional but has no reverse instruction."))
        }
        if c.direction == .oneWay, c.instructions.reverse != nil {
            issues.append(.warning("\(label) is one-way; its reverse instruction will never be used."))
        }

        // Stairs are never step-free, whatever the data says.
        if c.type == .stairs && c.stepFree == .confirmed {
            issues.append(.error("\(label) is stairs but is marked step-free confirmed."))
        }

        // Verification honesty.
        if mapStatus == .fictionalDemo && c.verification.status != .simulated {
            issues.append(.error("\(label) is in a fictional map but claims '\(c.verification.status.rawValue)' verification."))
        }
        if c.verification.status == .verified && (c.verification.checkedOn == nil || c.verification.checkedBy == nil) {
            issues.append(.error("\(label) is marked verified but has no checkedOn date or checkedBy name."))
        }
        if mapStatus != .fictionalDemo && c.verification.status == .simulated {
            issues.append(.error("\(label) uses simulated data inside a non-fictional map."))
        }

        return issues
    }

    private static func duplicateIDIssues(_ ids: [String], kind: String) -> [MapIssue] {
        var seen: Set<String> = []
        var issues: [MapIssue] = []
        for id in ids {
            if seen.contains(id) {
                issues.append(.error("Duplicate \(kind) id '\(id)'."))
            }
            seen.insert(id)
        }
        return issues
    }
}
