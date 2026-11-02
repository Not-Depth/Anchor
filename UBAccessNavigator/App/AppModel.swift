import Foundation
import Observation

/// App-wide state shared by all three tabs: settings, the loaded map, and services.
@MainActor
@Observable
final class AppModel {
    let settings: AppSettings
    let speech: SpeechService
    let haptics: HapticsService
    let nearby: NearbyViewModel

    /// The map as loaded from disk, before any demo simulation switches are applied.
    private(set) var baseMap: CampusMap?
    /// Shown instead of the route UI if the map failed to load or validate.
    private(set) var mapLoadError: String?

    init(settings: AppSettings? = nil, bundle: Bundle = .main) {
        let settings = settings ?? AppSettings()
        let speech = SpeechService()
        let haptics = HapticsService()
        self.settings = settings
        self.speech = speech
        self.haptics = haptics
        self.nearby = NearbyViewModel(settings: settings, speech: speech, haptics: haptics)
        do {
            baseMap = try CampusMap.load(in: bundle)
        } catch {
            mapLoadError = String(describing: error)
        }
    }

    /// The map routing actually uses: the base map plus demo simulation switches.
    var activeMap: CampusMap? {
        guard let baseMap else { return nil }
        guard settings.simulateElevatorOutage else { return baseMap }
        var overrides: [String: Availability] = [:]
        for connection in baseMap.connections where connection.type == .elevator {
            overrides[connection.id] = .unavailable
        }
        return baseMap.applying(availabilityOverrides: overrides)
    }

    /// Names of connections a demo switch has made unavailable, for on-screen labels.
    var simulatedOutages: [String] {
        guard settings.simulateElevatorOutage, let baseMap else { return [] }
        return baseMap.connections.filter { $0.type == .elevator }.map(\.name)
    }

    func planRoute(_ request: RouteRequest) -> Result<Route, RouteFailure>? {
        guard let map = activeMap else { return nil }
        let preferences = RoutePreferences(requireStepFree: settings.requireStepFree)
        return RoutePlanner(map: map).route(from: request.startID, to: request.destinationID, preferences: preferences)
    }

    /// Speaks only if the person has spoken directions turned on.
    func speakDirection(_ text: String) {
        guard settings.spokenDirections else { return }
        speech.speak(text)
    }
}

/// What the person asked for on the Routes screen. Hashable so it can drive navigation.
struct RouteRequest: Hashable {
    var startID: String
    var destinationID: String
}
