import Foundation

// MARK: - Map file model
//
// These types mirror `Resources/demo_map.json` one-to-one, so Swift's synthesized
// Codable conformance can load the file without any custom decoding code.
//
// Everything in Core/ uses Foundation only (no SwiftUI, UIKit or ARKit), so it can be
// unit-tested with `swift test` on a Mac or Linux without a simulator.

/// How trustworthy the whole map file is.
enum MapDataStatus: String, Codable, Equatable {
    /// Invented for demonstration. Does not describe any real building.
    case fictionalDemo = "fictional_demo"
    /// Collected on site, not yet independently checked.
    case surveyedUnverified = "surveyed_unverified"
    /// Collected on site and independently checked.
    case surveyedVerified = "surveyed_verified"
}

struct CampusMap: Codable, Equatable {
    var schemaVersion: Int
    var id: String
    var name: String
    var dataStatus: MapDataStatus
    /// Shown wherever the map is used. Required so the data's limits are never hidden.
    var disclaimer: String
    var floors: [Floor]
    var landmarks: [Landmark]
    var connections: [Connection]
}

struct Floor: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    /// Used only for sorting floors in the UI (1 = Floor 1, 2 = Floor 2, ...).
    var level: Int
}

enum LandmarkKind: String, Codable, Equatable {
    case outdoor
    case entrance
    case junction
    case stairLanding = "stair_landing"
    case elevatorLobby = "elevator_lobby"
    case room
}

/// A place a person can confirm they have reached.
struct Landmark: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var floorID: String
    var kind: LandmarkKind
    /// Non-visual cues that help someone confirm arrival (sounds, floor texture, signs).
    var arrivalCue: String
    var canStartHere: Bool
    var isDestination: Bool
    /// Optional position for the schematic drawing, 0...1 on each axis of its floor.
    var schematic: SchematicPoint?
}

struct SchematicPoint: Codable, Equatable {
    var x: Double
    var y: Double
}

/// A way to travel between two landmarks.
struct Connection: Codable, Equatable, Identifiable {
    var id: String
    /// Human-readable name used in summaries and warnings, e.g. "Elevator A".
    var name: String
    var from: String
    var to: String
    var type: ConnectionType
    var direction: Directionality
    /// Recorded travel length. `nil` means it was not recorded (common for elevators and
    /// stairs). The app never invents a length when this is missing.
    var lengthMeters: Double?
    /// Weight used by Dijkstra. Defaults to `lengthMeters` when omitted. Use it to make
    /// a connection "more expensive" than its length (for example, elevator waiting time).
    /// It is never shown or spoken as a distance.
    var routingCost: Double?
    /// Physical suitability for wheelchair users. Separate from `availability`.
    var stepFree: StepFreeSuitability
    /// Whether the connection can be used right now (e.g. an elevator out of service).
    var availability: Availability
    var verification: Verification
    var instructions: Instructions

    /// The weight Dijkstra uses. Map validation guarantees one of the two values exists.
    var effectiveCost: Double {
        routingCost ?? lengthMeters ?? .infinity
    }
}

enum ConnectionType: String, Codable, Equatable, CaseIterable {
    case corridor
    case door
    case stairs
    case ramp
    case elevator
    case bridge

    var displayName: String {
        switch self {
        case .corridor: return "Corridor"
        case .door: return "Doorway"
        case .stairs: return "Stairs"
        case .ramp: return "Ramp"
        case .elevator: return "Elevator"
        case .bridge: return "Bridge"
        }
    }
}

enum Directionality: String, Codable, Equatable {
    /// Can be traveled `from -> to` and `to -> from`.
    case bidirectional
    /// Can only be traveled `from -> to` (for example, an exit-only door).
    case oneWay = "one_way"
}

/// Physical suitability for step-free travel. An elevator, ramp or bridge is NOT assumed
/// to be suitable just because of its type: someone has to confirm it.
enum StepFreeSuitability: String, Codable, Equatable {
    case confirmed
    case unsuitable
    case unknown

    var displayName: String {
        switch self {
        case .confirmed: return "Step-free: confirmed"
        case .unsuitable: return "Step-free: not suitable"
        case .unknown: return "Step-free: unknown"
        }
    }
}

/// Current availability. Kept separate from physical suitability: a confirmed step-free
/// elevator can still be out of service today.
enum Availability: String, Codable, Equatable {
    case available
    case unavailable
    case unknown

    var displayName: String {
        switch self {
        case .available: return "Available"
        case .unavailable: return "Unavailable"
        case .unknown: return "Availability unknown"
        }
    }
}

/// Where a connection's information came from. Lets future surveyed data record who
/// checked what, and when.
struct Verification: Codable, Equatable {
    enum Status: String, Codable, Equatable {
        /// Authored for the fictional demo. Drives simulated routing only.
        case simulated
        /// Reported or surveyed once, not yet independently checked.
        case unverified
        /// Checked on site by a named person on a known date.
        case verified
    }

    var status: Status
    var source: String
    /// ISO 8601 date, e.g. "2026-11-20".
    var checkedOn: String?
    var checkedBy: String?
    var notes: String?
}

/// Authored, landmark-based directions. The app only speaks what is written here;
/// it never generates turns, compass directions or distances on its own.
struct Instructions: Codable, Equatable {
    /// Used when traveling `from -> to`.
    var forward: String
    /// Used when traveling `to -> from`. Required for bidirectional connections.
    var reverse: String?
}

// MARK: - Lookups

extension CampusMap {
    func landmark(withID id: String) -> Landmark? {
        landmarks.first { $0.id == id }
    }

    func floor(withID id: String) -> Floor? {
        floors.first { $0.id == id }
    }

    var sortedFloors: [Floor] {
        floors.sorted { $0.level < $1.level }
    }

    var startLandmarks: [Landmark] {
        landmarks.filter(\.canStartHere)
    }

    var destinationLandmarks: [Landmark] {
        landmarks.filter(\.isDestination)
    }

    var isFictional: Bool {
        dataStatus == .fictionalDemo
    }

    /// Returns a copy with some connections' availability replaced. Used for the
    /// "simulate elevator outage" demo switch; physical suitability is untouched.
    func applying(availabilityOverrides overrides: [String: Availability]) -> CampusMap {
        var copy = self
        for index in copy.connections.indices {
            if let override = overrides[copy.connections[index].id] {
                copy.connections[index].availability = override
            }
        }
        return copy
    }
}
