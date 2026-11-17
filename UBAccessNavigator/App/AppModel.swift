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

    /// The campus map, as loaded from disk. `nil` if it failed to load or validate.
    private(set) var map: CampusMap?
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
            map = try CampusMap.load(in: bundle)
        } catch {
            mapLoadError = String(describing: error)
        }
    }

    func planRoute(_ request: RouteRequest) -> Result<Route, RouteFailure>? {
        guard let map else { return nil }
        return RoutePlanner(map: map).route(from: request.startID, to: request.destinationID)
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
