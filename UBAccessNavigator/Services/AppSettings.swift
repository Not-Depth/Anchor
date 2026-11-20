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
        static let speechVoice = "settings.speechVoice"
        static let floorDetection = "settings.floorDetection"
        static let hasSeenFloorIntro = "settings.hasSeenFloorIntro"
    }

    /// Which voice speaks directions and alerts when VoiceOver is off.
    enum SpeechVoice: String, CaseIterable, Identifiable {
        /// The recorded Anchor voice bundled with the app.
        case anchor
        /// The iPhone's own voice, following the person's Spoken Content settings.
        case system

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .anchor: "Anchor voice"
            case .system: "iPhone voice"
            }
        }
    }

    /// Distances offered for nearby alerts, in meters.
    static let alertDistanceOptions = ProximityAlertPolicy.alertDistanceOptions

    private let defaults: UserDefaults

    var spokenDirections: Bool {
        didSet { defaults.set(spokenDirections, forKey: Key.spokenDirections) }
    }
    var speechVoice: SpeechVoice {
        didSet { defaults.set(speechVoice.rawValue, forKey: Key.speechVoice) }
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

    /// Check floor changes on stairs and elevator steps with the barometer.
    var floorDetection: Bool {
        didSet { defaults.set(floorDetection, forKey: Key.floorDetection) }
    }
    /// Whether the first-launch screen about floor detection has been shown.
    var hasSeenFloorIntro: Bool {
        didSet { defaults.set(hasSeenFloorIntro, forKey: Key.hasSeenFloorIntro) }
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
            Key.speechVoice: SpeechVoice.anchor.rawValue,
            Key.floorDetection: true,
            Key.hasSeenFloorIntro: false,
        ])
        spokenDirections = defaults.bool(forKey: Key.spokenDirections)
        speechVoice = defaults.string(forKey: Key.speechVoice).flatMap(SpeechVoice.init(rawValue:)) ?? .anchor
        nearbyAudioAlerts = defaults.bool(forKey: Key.nearbyAudioAlerts)
        nearbyHapticAlerts = defaults.bool(forKey: Key.nearbyHapticAlerts)
        nearbyAlertDistance = defaults.double(forKey: Key.nearbyAlertDistance)
        floorDetection = defaults.bool(forKey: Key.floorDetection)
        hasSeenFloorIntro = defaults.bool(forKey: Key.hasSeenFloorIntro)
    }
}
