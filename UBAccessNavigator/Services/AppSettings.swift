import Foundation
import Observation

/// User preferences, saved to UserDefaults whenever they change.
///
/// Each preference is independent, so they can be combined freely (for example,
/// spoken directions + haptic alerts but no audio alerts).
@MainActor
@Observable
final class AppSettings {
    private enum Key {
        static let spokenDirections = "settings.spokenDirections"
        static let nearbyAudioAlerts = "settings.nearbyAudioAlerts"
        static let nearbyHapticAlerts = "settings.nearbyHapticAlerts"
        static let nearbyAlertDistance = "settings.nearbyAlertDistance"
    }

    /// Distances offered for nearby alerts, in meters.
    static let alertDistanceOptions: [Double] = [0.5, 0.75, 1.0, 1.5, 2.0]

    private let defaults: UserDefaults

    var spokenDirections: Bool {
        didSet { defaults.set(spokenDirections, forKey: Key.spokenDirections) }
    }
    var nearbyAudioAlerts: Bool {
        didSet { defaults.set(nearbyAudioAlerts, forKey: Key.nearbyAudioAlerts) }
    }
    var nearbyHapticAlerts: Bool {
        didSet { defaults.set(nearbyHapticAlerts, forKey: Key.nearbyHapticAlerts) }
    }
    var nearbyAlertDistance: Double {
        didSet { defaults.set(nearbyAlertDistance, forKey: Key.nearbyAlertDistance) }
    }

    var anyNearbyAlertsEnabled: Bool { nearbyAudioAlerts || nearbyHapticAlerts }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Values used until the person changes a setting.
        defaults.register(defaults: [
            Key.spokenDirections: true,
            Key.nearbyAudioAlerts: false,
            Key.nearbyHapticAlerts: false,
            Key.nearbyAlertDistance: 1.0,
        ])
        spokenDirections = defaults.bool(forKey: Key.spokenDirections)
        nearbyAudioAlerts = defaults.bool(forKey: Key.nearbyAudioAlerts)
        nearbyHapticAlerts = defaults.bool(forKey: Key.nearbyHapticAlerts)
        nearbyAlertDistance = defaults.double(forKey: Key.nearbyAlertDistance)
    }
}
