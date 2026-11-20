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
    /// Barometer-based floor checks during guidance.
    let floorTracker: FloorTracker

    /// The campus map, as loaded from disk. `nil` if it failed to load or validate.
    private(set) var map: CampusMap?
    /// Shown instead of the route UI if the map failed to load or validate.
    private(set) var mapLoadError: String?

    /// Whether the recorded Anchor voice has a clip for everything the app can say.
    private(set) var voiceStatus: VoiceStatus = .notBundled

    init(settings: AppSettings? = nil, bundle: Bundle = .main) {
        let settings = settings ?? AppSettings()
        let clips = VoiceClipLibrary(bundle: bundle)
        let speech = SpeechService(settings: settings, clips: clips)
        let haptics = HapticsService()
        self.settings = settings
        self.speech = speech
        self.haptics = haptics
        self.nearby = NearbyViewModel(settings: settings, speech: speech, haptics: haptics)
        self.floorTracker = FloorTracker()
        do {
            map = try CampusMap.load(in: bundle)
        } catch {
            mapLoadError = String(describing: error)
        }
        if let clips {
            let phrases = map.map { SpokenPhrases.all(in: $0) } ?? []
            voiceStatus = .bundled(voiceName: clips.manifest.voice.name,
                                   missingPhrases: clips.missingPhrases(in: phrases).count)
        }
    }

    func planRoute(_ request: RouteRequest) -> Result<Route, RouteFailure>? {
        guard let map else { return nil }
        return RoutePlanner(map: map).route(from: request.startID, to: request.destinationID)
    }

    /// Speaks only if the person has spoken directions turned on.
    func speakDirection(_ text: String) {
        speakDirection([text])
    }

    /// Speaks several phrases in order, e.g. the route intro followed by the first step.
    func speakDirection(_ phrases: [String]) {
        guard settings.spokenDirections else { return }
        speech.speak(phrases)
    }
}

/// Shown in Settings, so a missing or incomplete recorded voice is never a silent change.
enum VoiceStatus: Equatable {
    /// No voice clips are bundled; the iPhone voice is used.
    case notBundled
    /// Clips are bundled. Phrases without a clip are spoken with the iPhone voice.
    case bundled(voiceName: String, missingPhrases: Int)
}

/// What the person asked for on the Routes screen. Hashable so it can drive navigation.
struct RouteRequest: Hashable {
    var startID: String
    var destinationID: String
}
