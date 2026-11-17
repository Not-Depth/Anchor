import Foundation

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
        }
        return result
    }
}

/// Why no route could be offered. Used to explain the failure instead of just saying "no route".
struct NoRouteDiagnosis: Equatable {
    enum Reason: Equatable {
        /// A route exists on paper, but it uses connections that are currently unavailable
        /// (for example, a corridor closed for repairs).
        case blockedByUnavailableConnections
        /// The two landmarks are not connected at all in this map.
        case notConnected
    }

    var reason: Reason
    /// The specific connections that stand in the way, deduplicated, in travel order.
    var blockingConnections: [Connection]

    var explanation: String {
        switch reason {
        case .blockedByUnavailableConnections:
            let names = blockingConnections.map { "\($0.name) (unavailable)" }.joined(separator: "; ")
            return "Every route to this place needs a connection that is currently unavailable: \(names)."
        case .notConnected:
            return "These two places are not connected in this map."
        }
    }
}

enum RouteFailure: Error, Equatable {
    case unknownLandmark(String)
    case sameStartAndDestination
    case noSuitableRoute(NoRouteDiagnosis)
}
