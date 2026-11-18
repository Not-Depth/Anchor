import Foundation

/// Every sentence the app can speak, built by the same code that speaks it.
///
/// The recorded Anchor voice is a set of audio clips generated ahead of time
/// (see Tools/VoiceClips). This catalog is what the clips are generated from, and the
/// tests check that every entry has a clip, so a map edit that adds new wording is
/// caught instead of silently switching to a different voice.
public enum SpokenPhrases {
    static let voiceTest = "This is how route directions will sound."
    static let depthReadingsUnavailable = "Depth readings unavailable. Alerts paused."
    static let depthReadingsRestored = "Depth readings restored."

    /// Nearby alert, e.g. "Surface at 0.8 meters".
    static func surface(atMeters distance: Double) -> String {
        "Surface at \(DistanceText.spokenDepth(distance))"
    }

    /// Every distance a nearby alert can report, at the one-decimal precision it is spoken.
    ///
    /// Readings start at the depth filter's lower limit. An alert can repeat while the
    /// person stays near, up to the largest alert distance plus the policy's hysteresis.
    static func alertDistances() -> [Double] {
        let lowest = Double(DepthAnalysisSettings().validRange.lowerBound)
        let highest = (ProximityAlertPolicy.alertDistanceOptions.max() ?? 0)
            + ProximityAlertPolicy(alertDistance: 0).hysteresis
        let first = Int((lowest * 10).rounded(.down))
        let last = Int((highest * 10).rounded(.up))
        guard first <= last else { return [] }
        return (first...last).map { Double($0) / 10 }
    }

    /// All phrases for this map, sorted and without duplicates.
    static func all(in map: CampusMap) -> [String] {
        var phrases: Set<String> = [voiceTest, depthReadingsUnavailable, depthReadingsRestored]
        for distance in alertDistances() {
            phrases.insert(surface(atMeters: distance))
        }

        // Every route the Routes screen can produce, spoken exactly as GuidanceView speaks it.
        let planner = RoutePlanner(map: map)
        for start in map.startLandmarks {
            for destination in map.destinationLandmarks where destination.id != start.id {
                guard case .success(let route) = planner.route(from: start.id, to: destination.id) else {
                    continue
                }
                let guidance = RouteGuidance(route: route)
                phrases.insert(guidance.introText)
                for step in guidance.steps {
                    phrases.insert(step.spokenText)
                }
            }
        }
        return phrases.sorted()
    }

    /// Entry point for Tools/VoiceClips, which only has the map file.
    public static func all(mapJSON: Data) throws -> [String] {
        all(in: try CampusMap.load(from: mapJSON))
    }
}
