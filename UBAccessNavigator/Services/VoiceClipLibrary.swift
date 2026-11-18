import Foundation

/// The recorded Anchor voice: audio clips generated ahead of time with ElevenLabs
/// (see Tools/VoiceClips) and bundled with the app.
///
/// The app never contacts ElevenLabs. Playback is offline and instant, and no API key
/// is in the app.
struct VoiceClipLibrary {
    let manifest: VoiceClipManifest
    private let bundle: Bundle

    /// `nil` if no voice manifest is bundled or it can't be read.
    init?(bundle: Bundle = .main) {
        guard let url = Self.resourceURL(name: VoiceClipManifest.resourceName, extension: "json", in: bundle) else {
            return nil
        }
        do {
            manifest = try VoiceClipManifest.decode(Data(contentsOf: url))
            self.bundle = bundle
        } catch {
            print("VoiceClipLibrary: could not read voice manifest: \(error)")
            return nil
        }
    }

    /// Clip files for these phrases, in order. `nil` unless every phrase has a clip, so a
    /// message is never spoken half in one voice and half in another.
    func urls(for phrases: [String]) -> [URL]? {
        var urls: [URL] = []
        for phrase in phrases {
            guard let file = manifest.fileName(for: phrase), let url = url(forFile: file) else { return nil }
            urls.append(url)
        }
        return urls
    }

    /// Phrases with no clip, or whose clip file is missing from the app bundle.
    func missingPhrases(in phrases: [String]) -> [String] {
        phrases.filter { urls(for: [$0]) == nil }
    }

    private func url(forFile file: String) -> URL? {
        let name = (file as NSString).deletingPathExtension
        let ext = (file as NSString).pathExtension
        return Self.resourceURL(name: name, extension: ext, in: bundle)
    }

    /// Xcode normally copies resources to the top of the bundle; also check Voice/ in
    /// case the folder is kept as a folder.
    private static func resourceURL(name: String, extension ext: String, in bundle: Bundle) -> URL? {
        bundle.url(forResource: name, withExtension: ext)
            ?? bundle.url(forResource: name, withExtension: ext, subdirectory: "Voice")
    }
}
