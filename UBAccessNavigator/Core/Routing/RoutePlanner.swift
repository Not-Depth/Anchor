import Foundation

/// Finds the lowest-cost route between two landmarks with Dijkstra's algorithm.
///
/// Rules that are never relaxed when building a route:
/// - Connections marked `unavailable` are excluded.
/// - One-way connections are only traveled `from -> to`.
///
/// The relaxed search in `diagnoseFailure` is only used to *explain* a failure.
/// Its route is never returned to the person.
struct RoutePlanner {
    let map: CampusMap

    /// One directed edge of the graph: a connection traveled in one direction.
    private struct Edge {
        let connection: Connection
        let from: String
        let to: String
        let isReversed: Bool
    }

    /// How a search treats connections that are currently unavailable.
    private enum UnavailableRule {
        /// Never use them. Normal routing.
        case exclude
        /// Allowed, but with a huge extra cost. Used only when diagnosing a failure, so the
        /// search finds the route that needs the *fewest* unavailable connections.
        case penalize
    }

    private static let diagnosisPenalty = 1_000_000.0

    private let outgoing: [String: [Edge]]

    init(map: CampusMap) {
        self.map = map
        var adjacency: [String: [Edge]] = [:]
        for connection in map.connections {
            adjacency[connection.from, default: []].append(
                Edge(connection: connection, from: connection.from, to: connection.to, isReversed: false)
            )
            if connection.direction == .bidirectional {
                adjacency[connection.to, default: []].append(
                    Edge(connection: connection, from: connection.to, to: connection.from, isReversed: true)
                )
            }
        }
        self.outgoing = adjacency
    }

    func route(from startID: String, to destinationID: String) -> Result<Route, RouteFailure> {
        guard let start = map.landmark(withID: startID) else {
            return .failure(.unknownLandmark(startID))
        }
        guard let destination = map.landmark(withID: destinationID) else {
            return .failure(.unknownLandmark(destinationID))
        }
        guard startID != destinationID else {
            return .failure(.sameStartAndDestination)
        }

        guard let path = shortestPath(from: startID, to: destinationID, unavailable: .exclude) else {
            return .failure(.noSuitableRoute(diagnoseFailure(from: startID, to: destinationID)))
        }

        let legs = path.edges.enumerated().map { index, edge in
            RouteLeg(
                index: index,
                connection: edge.connection,
                from: map.landmark(withID: edge.from)!,  // IDs were checked by MapValidator
                to: map.landmark(withID: edge.to)!,
                isReversed: edge.isReversed
            )
        }

        return .success(Route(
            start: start,
            destination: destination,
            legs: legs,
            mapName: map.name,
            mapDataStatus: map.dataStatus,
            mapDisclaimer: map.disclaimer,
            totalRoutingCost: path.cost,
            floorLevels: Dictionary(map.floors.map { ($0.id, $0.level) }, uniquingKeysWith: { first, _ in first })
        ))
    }

    // MARK: - Costs

    /// The cost of using `connection`, or `nil` if it may not be used.
    private func cost(of connection: Connection, unavailable rule: UnavailableRule) -> Double? {
        guard connection.availability == .unavailable else { return connection.effectiveCost }
        switch rule {
        case .exclude: return nil
        case .penalize: return connection.effectiveCost + Self.diagnosisPenalty
        }
    }

    // MARK: - Dijkstra

    /// Textbook Dijkstra. The "frontier" is a plain Set scanned for its minimum, which is
    /// O(V^2) overall: easy to read and fast enough for a building with hundreds of
    /// landmarks. A binary heap would make it O(E log V) if maps grow much larger.
    ///
    /// Ties are broken by landmark ID so the same input always gives the same route.
    private func shortestPath(
        from start: String,
        to goal: String,
        unavailable rule: UnavailableRule
    ) -> (edges: [Edge], cost: Double)? {
        var bestCost: [String: Double] = [start: 0]
        var arrivedVia: [String: Edge] = [:]
        var settled: Set<String> = []
        var frontier: Set<String> = [start]

        while let current = frontier.min(by: { (bestCost[$0]!, $0) < (bestCost[$1]!, $1) }) {
            frontier.remove(current)
            if current == goal { break }
            settled.insert(current)

            for edge in outgoing[current, default: []] {
                guard !settled.contains(edge.to),
                      let edgeCost = cost(of: edge.connection, unavailable: rule) else { continue }
                let candidate = bestCost[current]! + edgeCost
                if candidate < bestCost[edge.to, default: .infinity] {
                    bestCost[edge.to] = candidate
                    arrivedVia[edge.to] = edge
                    frontier.insert(edge.to)
                }
            }
        }

        guard let totalCost = bestCost[goal] else { return nil }

        // Walk backwards from the goal to rebuild the path.
        var edges: [Edge] = []
        var node = goal
        while let edge = arrivedVia[node] {
            edges.append(edge)
            node = edge.from
        }
        return (edges.reversed(), totalCost)
    }

    // MARK: - Explaining failures

    /// Runs a relaxed search to find *why* no route exists, so the app can say
    /// "Stairwell A stairs is unavailable" instead of just "no route". Unavailable
    /// connections are penalized rather than freely allowed, so only the unavoidable
    /// blockers are listed.
    private func diagnoseFailure(from start: String, to goal: String) -> NoRouteDiagnosis {
        if let path = shortestPath(from: start, to: goal, unavailable: .penalize) {
            let blockers = path.edges.map(\.connection).filter { $0.availability == .unavailable }
            return NoRouteDiagnosis(reason: .blockedByUnavailableConnections, blockingConnections: unique(blockers))
        }
        return NoRouteDiagnosis(reason: .notConnected, blockingConnections: [])
    }

    private func unique(_ connections: [Connection]) -> [Connection] {
        var seen: Set<String> = []
        return connections.filter { seen.insert($0.id).inserted }
    }
}
