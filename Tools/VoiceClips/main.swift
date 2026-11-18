// Records the Anchor voice: one ElevenLabs audio clip for every phrase the app can speak.
//
//   ELEVENLABS_API_KEY=your-key swift run anchor-voice-clips
//
// Run from the repository root. Clips go to UBAccessNavigator/Resources/Voice/ with
// voice_manifest.json, which the app bundles and plays offline. Commit that folder.
//
// The key is read from the environment only. It is never written to a file, so it
// can't end up in the app or on GitHub. Phrases that already have a clip with the same
// voice settings are skipped, so re-running after a map edit only records what changed.
//
// Options:
//   --list            Print every phrase and exit (no key or network needed).
//   --dry-run         Show what would be generated, and how many characters, then exit.
//   --force           Re-record every clip.
//   --voice-id ID     Use another ElevenLabs voice (default: Matilda).
//   --voice-name NAME Name shown in the app's Settings for that voice.
//   --model ID        ElevenLabs model (default: eleven_multilingual_v2).

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import NavigatorCore

/// Matilda: an American ElevenLabs default voice described as friendly, made for
/// narration. Warm but steady, which suits instructions someone has to act on.
let defaultVoice = VoiceClipManifest.Voice(
    provider: "ElevenLabs",
    voiceID: "XrExE9yKIg1WjnnlVkGX",
    name: "Matilda",
    modelID: "eleven_multilingual_v2",
    stability: 0.6,          // a little steadier than default, so all clips sound alike
    similarityBoost: 0.75,
    style: 0,                // no added dramatic style: directions should be plain
    useSpeakerBoost: true,
    seed: 2026
)

// MARK: - Paths

let repositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // VoiceClips
    .deletingLastPathComponent()  // Tools
    .deletingLastPathComponent()  // repository root
let resources = repositoryRoot.appendingPathComponent("UBAccessNavigator/Resources")
let mapURL = resources.appendingPathComponent("demo_map.json")
let voiceDirectory = resources.appendingPathComponent("Voice")
let manifestURL = voiceDirectory.appendingPathComponent("\(VoiceClipManifest.resourceName).json")
let clipPrefix = "anchor-voice-"

// MARK: - Helpers

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

func note(_ message: String) {
    print(message)
    fflush(stdout)
}

/// Stable file name for a phrase in a given voice (FNV-1a, 64-bit). Not a security hash;
/// it only has to be the same on every run and differ between phrases.
func clipFileName(for phrase: String, voice: VoiceClipManifest.Voice) -> String {
    let identity = [voice.voiceID, voice.modelID, "\(voice.stability)", "\(voice.similarityBoost)",
                    "\(voice.style)", "\(voice.useSpeakerBoost)", "\(voice.seed)", phrase]
        .joined(separator: "\u{1F}")
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in identity.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* 0x0000_0100_0000_01b3
    }
    let hex = String(hash, radix: 16)
    return clipPrefix + String(repeating: "0", count: 16 - hex.count) + hex + ".mp3"
}

func writeManifest(_ manifest: VoiceClipManifest) {
    do {
        try manifest.encoded().write(to: manifestURL, options: .atomic)
    } catch {
        fail("could not write \(manifestURL.path): \(error)")
    }
}

// MARK: - ElevenLabs

struct SpeechRequest: Encodable {
    struct Settings: Encodable {
        var stability: Double
        var similarityBoost: Double
        var style: Double
        var useSpeakerBoost: Bool

        enum CodingKeys: String, CodingKey {
            case stability
            case similarityBoost = "similarity_boost"
            case style
            case useSpeakerBoost = "use_speaker_boost"
        }
    }

    var text: String
    var modelID: String
    var seed: UInt32
    var voiceSettings: Settings

    enum CodingKeys: String, CodingKey {
        case text
        case modelID = "model_id"
        case seed
        case voiceSettings = "voice_settings"
    }
}

final class ResponseBox: @unchecked Sendable {
    var data: Data?
    var response: HTTPURLResponse?
    var error: Error?
}

func send(_ request: URLRequest) -> ResponseBox {
    let box = ResponseBox()
    let done = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: request) { data, response, error in
        box.data = data
        box.response = response as? HTTPURLResponse
        box.error = error
        done.signal()
    }.resume()
    done.wait()
    return box
}

/// Returns MP3 audio for one phrase. Retries rate limits and server errors.
func record(_ phrase: String, voice: VoiceClipManifest.Voice, apiKey: String) -> Data {
    var components = URLComponents(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voice.voiceID)")!
    components.queryItems = [URLQueryItem(name: "output_format", value: "mp3_44100_128")]
    var request = URLRequest(url: components.url!)
    request.httpMethod = "POST"
    request.timeoutInterval = 60
    request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
    request.httpBody = try! JSONEncoder().encode(SpeechRequest(
        text: phrase,
        modelID: voice.modelID,
        seed: voice.seed,
        voiceSettings: .init(stability: voice.stability, similarityBoost: voice.similarityBoost,
                             style: voice.style, useSpeakerBoost: voice.useSpeakerBoost)
    ))

    let attempts = 4
    for attempt in 1...attempts {
        let result = send(request)
        let body = result.data ?? Data()
        let detail = String(decoding: body.prefix(600), as: UTF8.self)
        if let status = result.response?.statusCode {
            if status == 200, !body.isEmpty {
                return body
            }
            if status == 401 || status == 403 {
                fail("ElevenLabs refused the request (HTTP \(status)). Check the API key, its permissions, and your character quota.\n\(detail)")
            }
            if status != 429 && status < 500 {
                fail("ElevenLabs returned HTTP \(status) for \"\(phrase)\".\n\(detail)")
            }
            note("  HTTP \(status), retrying (\(attempt)/\(attempts))…")
        } else {
            note("  network error: \(result.error.map { "\($0)" } ?? "no response"), retrying (\(attempt)/\(attempts))…")
        }
        if attempt < attempts {
            Thread.sleep(forTimeInterval: pow(2, Double(attempt)))
        }
    }
    fail("could not record \"\(phrase)\" after \(attempts) attempts.")
}

// MARK: - Main

var arguments = Array(CommandLine.arguments.dropFirst())
func flag(_ name: String) -> Bool {
    guard let index = arguments.firstIndex(of: name) else { return false }
    arguments.remove(at: index)
    return true
}
func option(_ name: String) -> String? {
    guard let index = arguments.firstIndex(of: name) else { return nil }
    guard index + 1 < arguments.count else { fail("\(name) needs a value") }
    let value = arguments[index + 1]
    arguments.removeSubrange(index...(index + 1))
    return value
}

let listOnly = flag("--list")
let dryRun = flag("--dry-run")
let force = flag("--force")
var voice = defaultVoice
if let id = option("--voice-id") {
    voice.voiceID = id
    voice.name = "Custom voice"
}
if let name = option("--voice-name") { voice.name = name }
if let model = option("--model") { voice.modelID = model }
if !arguments.isEmpty {
    fail("unknown option \(arguments[0]). See the comment at the top of Tools/VoiceClips/main.swift.")
}

let phrases: [String]
do {
    phrases = try SpokenPhrases.all(mapJSON: Data(contentsOf: mapURL))
} catch {
    fail("could not read the map at \(mapURL.path): \(error)")
}

if listOnly {
    phrases.forEach { print($0) }
    note("\(phrases.count) phrases, \(phrases.reduce(0) { $0 + $1.count }) characters.")
    exit(0)
}

// Keep existing clips only if they were recorded with exactly the same voice settings.
var manifest = VoiceClipManifest(voice: voice)
if !force, let data = try? Data(contentsOf: manifestURL),
   let existing = try? VoiceClipManifest.decode(data), existing.voice == voice {
    for phrase in phrases {
        guard let file = existing.fileName(for: phrase),
              FileManager.default.fileExists(atPath: voiceDirectory.appendingPathComponent(file).path)
        else { continue }
        manifest.clips[phrase] = file
    }
}

let toRecord = manifest.missing(from: phrases)
let characters = toRecord.reduce(0) { $0 + $1.count }
note("""
Voice: \(voice.name) (\(voice.voiceID)), model \(voice.modelID)
\(phrases.count) phrases: \(manifest.clips.count) already recorded, \(toRecord.count) to record (\(characters) characters).
""")
if dryRun {
    toRecord.forEach { print("  \($0)") }
    exit(0)
}

if !toRecord.isEmpty {
    guard let apiKey = ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"]?
        .trimmingCharacters(in: .whitespacesAndNewlines), !apiKey.isEmpty else {
        fail("set ELEVENLABS_API_KEY, e.g.  ELEVENLABS_API_KEY=your-key swift run anchor-voice-clips")
    }
    if !apiKey.hasPrefix("sk_") {
        note("Note: ElevenLabs API keys start with \"sk_\". A long code without it is usually the key's ID, which ElevenLabs rejects.")
    }
    do {
        try FileManager.default.createDirectory(at: voiceDirectory, withIntermediateDirectories: true)
    } catch {
        fail("could not create \(voiceDirectory.path): \(error)")
    }
    for (index, phrase) in toRecord.enumerated() {
        let file = clipFileName(for: phrase, voice: voice)
        let audio = record(phrase, voice: voice, apiKey: apiKey)
        do {
            try audio.write(to: voiceDirectory.appendingPathComponent(file), options: .atomic)
        } catch {
            fail("could not write \(file): \(error)")
        }
        manifest.clips[phrase] = file
        writeManifest(manifest)  // after every clip, so an interrupted run can resume
        note("[\(index + 1)/\(toRecord.count)] \(phrase.prefix(70))\(phrase.count > 70 ? "…" : "")")
    }
}

// Remove clips that no phrase uses any more (old wording or an old voice).
let inUse = Set(manifest.clips.values)
let existingFiles = (try? FileManager.default.contentsOfDirectory(atPath: voiceDirectory.path)) ?? []
var removed = 0
for file in existingFiles where file.hasPrefix(clipPrefix) && file.hasSuffix(".mp3") && !inUse.contains(file) {
    try? FileManager.default.removeItem(at: voiceDirectory.appendingPathComponent(file))
    removed += 1
}
writeManifest(manifest)
note("Done. \(manifest.clips.count) clips in \(voiceDirectory.path)\(removed > 0 ? "; removed \(removed) unused" : "").")
