import Foundation

/// Index of the bundled Anchor voice clips: which audio file holds each spoken phrase,
/// and which voice and settings generated them.
///
/// Written by Tools/VoiceClips into Resources/Voice/voice_manifest.json and read by the app.
public struct VoiceClipManifest: Codable, Equatable, Sendable {
    public struct Voice: Codable, Equatable, Sendable {
        public var provider: String
        public var voiceID: String
        public var name: String
        public var modelID: String
        public var stability: Double
        public var similarityBoost: Double
        public var style: Double
        public var useSpeakerBoost: Bool
        public var seed: UInt32

        public init(provider: String, voiceID: String, name: String, modelID: String,
                    stability: Double, similarityBoost: Double, style: Double,
                    useSpeakerBoost: Bool, seed: UInt32) {
            self.provider = provider
            self.voiceID = voiceID
            self.name = name
            self.modelID = modelID
            self.stability = stability
            self.similarityBoost = similarityBoost
            self.style = style
            self.useSpeakerBoost = useSpeakerBoost
            self.seed = seed
        }
    }

    public enum ManifestError: Error, Equatable {
        case unsupportedFormatVersion(Int)
    }

    public static let currentFormatVersion = 1
    /// Resource name, without the .json extension.
    public static let resourceName = "voice_manifest"

    public var formatVersion: Int
    public var voice: Voice
    /// Exact spoken text → clip file name, e.g. "anchor-voice-0123456789abcdef.mp3".
    public var clips: [String: String]

    public init(voice: Voice, clips: [String: String] = [:]) {
        self.formatVersion = Self.currentFormatVersion
        self.voice = voice
        self.clips = clips
    }

    public func fileName(for text: String) -> String? {
        clips[text]
    }

    /// Phrases that have no clip in this manifest.
    public func missing(from phrases: [String]) -> [String] {
        phrases.filter { clips[$0] == nil }
    }

    public static func decode(_ data: Data) throws -> VoiceClipManifest {
        let manifest = try JSONDecoder().decode(VoiceClipManifest.self, from: data)
        guard manifest.formatVersion == currentFormatVersion else {
            throw ManifestError.unsupportedFormatVersion(manifest.formatVersion)
        }
        return manifest
    }

    /// Stable, readable JSON, so regenerating unchanged clips gives an unchanged file.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}
