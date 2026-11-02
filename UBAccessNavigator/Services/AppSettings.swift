import Foundation
import Observation

/// User preferences, saved to UserDefaults whenever they change.
///
/// Each preference is independent, so they can be combined freely (for example,
/// step-free routes + spoken directions + haptic alerts).
@MainActor
@Observable
final class AppSettings {
    private enum Key {
        static let requireStepFree = "settings.requireStepFree"
        static let spokenDirections = "settings.spokenDirections"
        static let nearbyAudioAlerts = "settings.nearbyAudioAlerts"
        static let nearbyHapticAlerts = "settings.nearbyHapticAlerts"
        static let nearbyAlertDistance = "settings.nearbyAlertDistance"
        static let simulateElevatorOutage = "demo.simulateElevatorOutage"
    }

    /// Distances offered for nearby alerts, in meters.
    static let alertDistanceOptions: [Double] = [0.5, 0.75, 1.0, 1.5, 2.0]

    private let defaults: UserDefaults

    var requireStepFree: Bool {
        didSet { defaults.set(requireStepFree, forKey: Key.requireStepFree) }
    }
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
    /// Demo-only switch: marks every elevator in the map as unavailable.
    var simulateElevatorOutage: Bool {
        didSet { defaults.set(simulateElevatorOutage, forKey: Key.simulateElevatorOutage) }
    }

    var anyNearbyAlertsEnabled: Bool { nearbyAudioAlerts || nearbyHapticAlerts }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Values used until the person changes a setting.
        defaults.register(defaults: [
            Key.requireStepFree: false,
            Key.spokenDirections: true,
            Key.nearbyAudioAlerts: false,
            Key.nearbyHapticAlerts: false,
            Key.nearbyAlertDistance: 1.0,
            Key.simulateElevatorOutage: false,
        ])
        requireStepFree = defaults.bool(forKey: Key.requireStepFree)
        spokenDirections = defaults.bool(forKey: Key.spokenDirections)
        nearbyAudioAlerts = defaults.bool(forKey: Key.nearbyAudioAlerts)
        nearbyHapticAlerts = defaults.bool(forKey: Key.nearbyHapticAlerts)
        nearbyAlertDistance = defaults.double(forKey: Key.nearbyAlertDistance)
        simulateElevatorOutage = defaults.bool(forKey: Key.simulateElevatorOutage)
    }
}
