import Foundation

/// Floor-change checks from the iPhone's barometer.
///
/// The barometer reports how much higher or lower the phone is than when readings
/// started (relative altitude, in meters). Anchor uses it only to check steps that change
/// floor, such as stairs or an elevator. It never moves guidance forward by itself: the
/// person still confirms each landmark. It measures air pressure only, not location.

enum VerticalDirection: Equatable, Sendable {
    case up
    case down

    var word: String {
        switch self {
        case .up: "up"
        case .down: "down"
        }
    }
}

/// The floor change a route step should produce, from the map's floor levels.
struct ExpectedFloorChange: Equatable, Sendable {
    var direction: VerticalDirection
    /// Number of floors changed, at least 1.
    var floors: Int

    /// `nil` when both levels are the same or either is unknown.
    init?(fromLevel: Int?, toLevel: Int?) {
        guard let fromLevel, let toLevel, fromLevel != toLevel else { return nil }
        direction = toLevel > fromLevel ? .up : .down
        floors = abs(toLevel - fromLevel)
    }

    init(direction: VerticalDirection, floors: Int) {
        self.direction = direction
        self.floors = max(1, floors)
    }
}

enum FloorText {
    /// "1 floor", "2 floors"
    static func count(_ floors: Int) -> String {
        floors == 1 ? "1 floor" : "\(floors) floors"
    }
}

/// Turns relative-altitude readings into a floor-change estimate since a baseline.
struct FloorChangeDetector: Equatable, Sendable {
    /// A change smaller than this is treated as staying on the same floor. A storey is
    /// usually about 3–4.5 m, while short-term barometer noise is well under 1 m, so 2 m
    /// separates the two with margin on both sides.
    static let detectionThreshold = 2.0
    /// Used to estimate how many floors a larger change covers.
    static let typicalFloorHeight = 3.5
    /// Readings smoothed with a median of this many, so one noisy sample can't flip the result.
    static let smoothingWindow = 3

    enum Estimate: Equatable, Sendable {
        /// No reading since the baseline was reset.
        case waiting
        /// Within the threshold of the baseline.
        case sameFloor
        case changed(VerticalDirection, floors: Int)
    }

    /// Altitude (relative to when readings started) at the moment of the reset.
    private(set) var baseline: Double?
    private var recent: [Double] = []

    /// Start measuring from the next reading, e.g. when a stairs step begins.
    mutating func reset() {
        baseline = nil
        recent = []
    }

    mutating func add(relativeAltitude meters: Double) {
        guard meters.isFinite else { return }
        if baseline == nil { baseline = meters }
        recent.append(meters)
        if recent.count > Self.smoothingWindow { recent.removeFirst(recent.count - Self.smoothingWindow) }
    }

    /// Smoothed height change since the baseline, in meters (positive = higher).
    var heightChange: Double? {
        guard let baseline, !recent.isEmpty else { return nil }
        let sorted = recent.sorted()
        let median = sorted.count % 2 == 1
            ? sorted[sorted.count / 2]
            : (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
        return median - baseline
    }

    var estimate: Estimate {
        guard let change = heightChange else { return .waiting }
        guard abs(change) >= Self.detectionThreshold else { return .sameFloor }
        let floors = max(1, Int((abs(change) / Self.typicalFloorHeight).rounded()))
        return .changed(change > 0 ? .up : .down, floors: floors)
    }
}

/// How a barometer estimate compares with what the current step expects.
enum FloorCheck: Equatable, Sendable {
    case waiting
    case notYet
    case matches
    case wrongDirection(sensed: VerticalDirection)
    case wrongCount(sensedFloors: Int)

    init(expected: ExpectedFloorChange, estimate: FloorChangeDetector.Estimate) {
        switch estimate {
        case .waiting:
            self = .waiting
        case .sameFloor:
            self = .notYet
        case .changed(let direction, let floors):
            if direction != expected.direction {
                self = .wrongDirection(sensed: direction)
            } else if floors != expected.floors {
                self = .wrongCount(sensedFloors: floors)
            } else {
                self = .matches
            }
        }
    }

    /// Shown on the guidance screen.
    func displayText(expected: ExpectedFloorChange) -> String {
        switch self {
        case .waiting:
            "Floor check: waiting for a barometer reading."
        case .notYet:
            "Floor check: no floor change sensed yet."
        case .matches:
            "Floor check: you went \(expected.direction.word) \(FloorText.count(expected.floors)), as expected."
        case .wrongDirection(let sensed):
            "Floor check: Anchor sensed you going \(sensed.word), but this step goes \(expected.direction.word)."
        case .wrongCount(let sensedFloors):
            "Floor check: Anchor sensed about \(FloorText.count(sensedFloors)), but this step changes \(FloorText.count(expected.floors))."
        }
    }

    /// Spoken once when the check reaches a result. `nil` while there is nothing to report.
    /// Fixed wording (no sensed numbers), so every phrase can be recorded ahead of time.
    func spokenText(expected: ExpectedFloorChange) -> String? {
        switch self {
        case .waiting, .notYet: nil
        case .matches: SpokenPhrases.floorChangeConfirmed(expected)
        case .wrongDirection: SpokenPhrases.floorChangeWrongDirection
        case .wrongCount: SpokenPhrases.floorChangeWrongCount
        }
    }
}
