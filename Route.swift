import Foundation

/// What the person needs from a route. More preferences can be added later
/// (for example, avoiding heavy doors) without changing the planner's shape.
struct RoutePreferences: Equatable {
    /// When true, the route may only use connections confirmed step-free.
    /// Stairs and connections marked unsuitable or unknown are excluded, not penalized.
    var requireStepFree: Bool
}

/// One traversal of one connection, in the direction actually traveled.
struct RouteLeg: Equatable, Identifiable {
    var id: Int { index }
    var index: Int
    var connection: Connection
    var from: Landmark
    var to: Landmark
    /// True when the connection is traveled `to -> from`.
    var isReversed: Bool

    /// The authored instruction for the direction traveled.
    var instruction: String {
        if isReversed, let reverse = connection.instructions.reverse {
            return reverse
        }
        return connection.instructions.forward
    }
}

/// A route the planner found, plus everything the summary screen needs to describe it.
struct Route: Equatable {
    var start: Landmark
    var destination: Landmark
    var legs: [RouteLeg]
    var preferences: RoutePreferences
    var mapName: String
    var mapDataStatus: MapDataStatus
    var mapDisclaimer: String
    var totalRoutingCost: Double

    /// Landmarks in travel order, starting with `start` and ending with `destination`.
    var landmarksInOrder: [Landmark] {
        [start] + legs.map(\.to)
    }

    /// Sum of lengths that were actually recorded. Legs without a recorded length
    /// (often elevators and stairs) are counted in `legsWithUnknownLength` instead.
    var recordedLengthMeters: Double {
        legs.compactMap(\.connection.lengthMeters).reduce(0, +)
    }

    var legsWithUnknownLength: Int {
        legs.filter { $0.connection.lengthMeters == nil }.count
    }

    /// e.g. [.corridor: 3, .elevator: 1]
    var connectionTypeCounts: [ConnectionType: Int] {
        legs.reduce(into: [:]) { counts, leg in counts[leg.connection.type, default: 0] += 1 }
    }

    var usesStairs: Bool {
        legs.contains { $0.connection.type == .stairs }
    }

    /// True when any part of the route comes from simulated (fictional) data.
    var usesSimulatedData: Bool {
        mapDataStatus == .fictionalDemo || legs.contains { $0.connection.verification.status == .simulated }
    }

    /// Things the person should know before setting off.
    var warnings: [String] {
        var result: [String] = []
        for leg in legs {
            let name = leg.connection.name
            if leg.connection.availability == .unknown {
                result.append("\(name): current availability is not confirmed.")
            }
            if leg.connection.verification.status == .unverified {
                result.append("\(name): details have not been verified on site.")
            }
            if !preferences.requireStepFree && leg.connection.stepFree == .unknown {
                result.append("\(name): step-free suitability is unknown.")
            }
        }
        return result
    }
}

/// Why no route could be offered. Used to explain the failure instead of silently
/// falling back to a route the person did not ask for.
struct NoRouteDiagnosis: Equatable {
    enum Reason: Equatable {
        /// A route meeting the preferences exists on paper, but uses connections that are
        /// currently unavailable (for example, an elevator out of service).
        case blockedByUnavailableConnections
        /// The only routes that exist use connections that are not confirmed step-free.
        case blockedByStepFreeRequirement
        /// Routes exist only if both unavailable and non-step-free connections were used.
        case blockedByBoth
        /// The two landmarks are not connected at all in this map.
        case notConnected
    }

    var reason: Reason
    /// The specific connections that stand in the way, deduplicated, in travel order.
    var blockingConnections: [Connection]

    var explanation: String {
        let names = blockingConnections.map { describe($0) }.joined(separator: "; ")
        switch reason {
        case .blockedByUnavailableConnections:
            return "A route meeting your preferences needs connections that are currently unavailable: \(names)."
        case .blockedByStepFreeRequirement:
            return "Every route in this map uses at least one connection that is not confirmed step-free: \(names)."
        case .blockedByBoth:
            return "Routes exist only through connections that are unavailable or not confirmed step-free: \(names)."
        case .notConnected:
            return "These two places are not connected in this map."
        }
    }

    private func describe(_ c: Connection) -> String {
        var parts: [String] = []
        if c.availability == .unavailable { parts.append("unavailable") }
        if c.type == .stairs {
            parts.append("stairs")
        } else if c.stepFree == .unsuitable {
            parts.append("not suitable for step-free travel")
        } else if c.stepFree == .unknown {
            parts.append("step-free suitability unknown")
        }
        return parts.isEmpty ? c.name : "\(c.name) (\(parts.joined(separator: ", ")))"
    }
}

enum RouteFailure: Error, Equatable {
    case unknownLandmark(String)
    case sameStartAndDestination
    case noSuitableRoute(NoRouteDiagnosis)
}
