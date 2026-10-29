import Foundation

/// Decides *when* to alert, given a stream of depth readings. It does not play sounds or
/// haptics itself; the app reacts to the events it returns.
///
/// Behaviour:
/// - Alerts once when the nearest surface comes within `alertDistance`.
/// - While it stays close, repeats at most every `repeatInterval` seconds.
/// - Re-arms only after the distance grows past `alertDistance + hysteresis`, so a
///   reading hovering around the threshold doesn't cause a flood of alerts.
/// - If reliable readings stop for `lostReadingGrace` seconds (after having worked),
///   it reports `.readingsUnreliable` once, so the person knows alerts are not working.
struct ProximityAlertPolicy {
    enum Event: Equatable {
        case near(distanceMeters: Double)
        case readingsUnreliable
        case readingsRestored
    }

    var alertDistance: Double
    var hysteresis: Double = 0.25
    var repeatInterval: TimeInterval = 3.0
    var lostReadingGrace: TimeInterval = 1.0
    var maxReadingAge: TimeInterval = 0.6

    private(set) var isNear = false
    private var lastAlertTime: TimeInterval?
    private var unreliableSince: TimeInterval?
    private var hasHadReliableReading = false
    private var reportedUnreliable = false

    init(alertDistance: Double) {
        self.alertDistance = alertDistance
    }

    mutating func reset() {
        isNear = false
        lastAlertTime = nil
        unreliableSince = nil
        hasHadReliableReading = false
        reportedUnreliable = false
    }

    /// Call regularly (on every new reading and on a timer, so staleness is noticed
    /// even when frames stop arriving).
    mutating func update(reading: DepthReading?, now: TimeInterval) -> Event? {
        guard let reading,
              !reading.isStale(at: now, maxAge: maxReadingAge),
              let distance = reading.distanceMeters else {
            return handleUnreliable(now: now)
        }

        hasHadReliableReading = true
        unreliableSince = nil
        if reportedUnreliable {
            reportedUnreliable = false
            isNear = false  // re-evaluate from scratch after an outage
            return .readingsRestored
        }

        if isNear {
            if distance > alertDistance + hysteresis {
                isNear = false
                return nil
            }
            if let last = lastAlertTime, now - last < repeatInterval {
                return nil
            }
            lastAlertTime = now
            return .near(distanceMeters: distance)
        }

        if distance <= alertDistance {
            isNear = true
            lastAlertTime = now
            return .near(distanceMeters: distance)
        }
        return nil
    }

    /// Short gaps (a few bad frames) keep the current near/far state, so flickering
    /// readings don't re-trigger alerts. Only a sustained gap is reported.
    private mutating func handleUnreliable(now: TimeInterval) -> Event? {
        guard hasHadReliableReading, !reportedUnreliable else { return nil }
        let since = unreliableSince ?? now
        unreliableSince = since
        if now - since >= lostReadingGrace {
            reportedUnreliable = true
            isNear = false
            return .readingsUnreliable
        }
        return nil
    }
}
