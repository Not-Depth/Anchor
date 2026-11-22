import XCTest
@testable import NavigatorCore

final class SpokenPhrasesTests: XCTestCase {
    func testIntroIsSpokenAsItsOwnPhrase() throws {
        let map = try TestSupport.demoMap()
        let route = try RoutePlanner(map: map).route(from: "plaza", to: "room-201").get()
        XCTAssertEqual(RouteGuidance(route: route).introText, "Fictional demo route to Room 201 (demo lab).")
    }

    func testCatalogHasEverythingSpokenOnARoute() throws {
        let map = try TestSupport.demoMap()
        let catalog = Set(SpokenPhrases.all(in: map))
        let route = try RoutePlanner(map: map).route(from: "plaza", to: "room-201").get()
        let guidance = RouteGuidance(route: route)

        XCTAssertTrue(catalog.contains(guidance.introText))
        for step in guidance.steps {
            XCTAssertTrue(catalog.contains(step.spokenText), "Missing: \(step.spokenText)")
        }
        XCTAssertTrue(catalog.contains("Start at North Plaza (outside). Arrival cue: Open paved area with a bike rack and benches."))
        XCTAssertTrue(catalog.contains("You have arrived at Room 201 (demo lab)."))
    }

    func testCatalogCoversEveryStartAndDestinationPair() throws {
        let map = try TestSupport.demoMap()
        let catalog = Set(SpokenPhrases.all(in: map))
        let planner = RoutePlanner(map: map)
        var routes = 0
        for start in map.startLandmarks {
            for destination in map.destinationLandmarks where destination.id != start.id {
                guard case .success(let route) = planner.route(from: start.id, to: destination.id) else { continue }
                routes += 1
                let guidance = RouteGuidance(route: route)
                XCTAssertTrue(catalog.isSuperset(of: [guidance.introText] + guidance.steps.map(\.spokenText)),
                              "\(start.id) → \(destination.id)")
            }
        }
        XCTAssertGreaterThan(routes, 0)
    }

    func testCatalogHasFixedMessages() throws {
        let catalog = Set(SpokenPhrases.all(in: try TestSupport.demoMap()))
        XCTAssertTrue(catalog.contains(SpokenPhrases.voiceTest))
        XCTAssertTrue(catalog.contains(SpokenPhrases.depthReadingsUnavailable))
        XCTAssertTrue(catalog.contains(SpokenPhrases.depthReadingsRestored))
    }

    /// Readings start at 0.1 m, and an alert can repeat up to the largest alert distance
    /// (3 m) plus the 0.25 m hysteresis.
    func testEveryDistanceAnAlertCanSpeakIsInCatalog() throws {
        let catalog = Set(SpokenPhrases.all(in: try TestSupport.demoMap()))
        for millimeters in 100...3250 {
            let phrase = SpokenPhrases.obstacleWarning(atMeters: Double(millimeters) / 1000)
            XCTAssertTrue(catalog.contains(phrase), "Missing: \(phrase)")
        }
        XCTAssertEqual(SpokenPhrases.obstacleWarning(atMeters: 1.26), "Warning, objects ahead at 1.3 meters.")
        XCTAssertTrue(catalog.contains("Warning, objects ahead at 3.0 meters."))
    }

    func testCatalogIsSortedWithoutDuplicatesOrBlanks() throws {
        let phrases = SpokenPhrases.all(in: try TestSupport.demoMap())
        XCTAssertEqual(phrases, Array(Set(phrases)).sorted())
        XCTAssertFalse(phrases.contains { $0.trimmingCharacters(in: .whitespaces).isEmpty })
    }

    func testPublicEntryPointMatchesCatalog() throws {
        XCTAssertEqual(try SpokenPhrases.all(mapJSON: TestSupport.demoMapData()),
                       SpokenPhrases.all(in: try TestSupport.demoMap()))
    }
}

final class VoiceClipManifestTests: XCTestCase {
    private let voice = VoiceClipManifest.Voice(
        provider: "ElevenLabs", voiceID: "voice", name: "Test", modelID: "model",
        stability: 0.6, similarityBoost: 0.75, style: 0, useSpeakerBoost: true, seed: 1)

    func testRoundTrip() throws {
        let manifest = VoiceClipManifest(voice: voice, clips: ["Hello.": "anchor-voice-1.mp3"])
        XCTAssertEqual(try VoiceClipManifest.decode(manifest.encoded()), manifest)
    }

    func testRejectsUnknownFormatVersion() throws {
        var manifest = VoiceClipManifest(voice: voice)
        manifest.formatVersion = 99
        XCTAssertThrowsError(try VoiceClipManifest.decode(manifest.encoded())) { error in
            XCTAssertEqual(error as? VoiceClipManifest.ManifestError, .unsupportedFormatVersion(99))
        }
    }

    func testMissingListsPhrasesWithoutClips() {
        let manifest = VoiceClipManifest(voice: voice, clips: ["A.": "a.mp3"])
        XCTAssertEqual(manifest.missing(from: ["A.", "B."]), ["B."])
        XCTAssertEqual(manifest.fileName(for: "A."), "a.mp3")
    }

    /// The recorded voice must cover every phrase, or part of the app would switch to the
    /// iPhone voice. If this fails after a map edit, run `swift run anchor-voice-clips`.
    func testBundledClipsCoverEveryPhrase() throws {
        let directory = TestSupport.repositoryFile("UBAccessNavigator/Resources/Voice")
        let manifestURL = directory.appendingPathComponent("\(VoiceClipManifest.resourceName).json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw XCTSkip("No voice clips yet. Record them with: swift run anchor-voice-clips")
        }
        let manifest = try VoiceClipManifest.decode(Data(contentsOf: manifestURL))
        let phrases = SpokenPhrases.all(in: try TestSupport.demoMap())

        XCTAssertEqual(manifest.missing(from: phrases), [], "Run: swift run anchor-voice-clips")
        XCTAssertEqual(Set(manifest.clips.keys), Set(phrases), "The manifest has clips for phrases the app no longer says")

        for file in Set(manifest.clips.values) {
            let attributes = try? FileManager.default.attributesOfItem(atPath: directory.appendingPathComponent(file).path)
            let size = (attributes?[.size] as? NSNumber)?.intValue ?? 0
            XCTAssertGreaterThan(size, 1_000, "\(file) is missing or empty")
        }
        let onDisk = try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasSuffix(".mp3") }
        XCTAssertEqual(Set(onDisk), Set(manifest.clips.values), "Voice folder has clips the manifest doesn't use")
    }
}
