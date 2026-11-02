import Foundation

/// Distance wording used on screen and in speech.
///
/// Lengths are always "about" a value: map lengths are authored estimates and LiDAR
/// readings are approximate.
enum DistanceText {
    /// Map lengths: whole meters, e.g. "about 25 m".
    static func meters(_ value: Double) -> String {
        "about \(Int(value.rounded())) m"
    }

    /// Depth readings: one decimal place, e.g. "about 1.4 m".
    static func depth(_ value: Double) -> String {
        "about \(String(format: "%.1f", value)) m"
    }

    /// Depth readings for speech, e.g. "1.4 meters".
    static func spokenDepth(_ value: Double) -> String {
        "\(String(format: "%.1f", value)) meters"
    }
}
