import AVFoundation
import UIKit

/// Speaks short messages (route instructions, nearby alerts).
///
/// - With VoiceOver on, messages go through VoiceOver as announcements, so the person
///   hears one voice, at their VoiceOver rate, instead of two voices talking over each other.
/// - Otherwise the recorded Anchor voice plays the bundled clip for each phrase. If the
///   person chose the iPhone voice in Settings, or a phrase has no clip, AVSpeechSynthesizer
///   speaks the whole message instead. Settings shows when clips are missing.
/// - Either way, other audio such as music is ducked while the app speaks.
///
/// Whether to speak at all is decided by the caller (based on AppSettings).
///
/// Audio session calls (`setCategory`, `setActive`) can block while iOS reconfigures
/// audio hardware, so they run on a background queue instead of the main thread.
@MainActor
final class SpeechService: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    private enum SessionState {
        case inactive
        case activating
        case active
    }

    /// One message, ready to play.
    private enum Message {
        /// Recorded clips, played in order. `text` is the full message, used if a clip fails.
        case clips([URL], text: String)
        /// Spoken by the iPhone's speech synthesizer.
        case synthesized(String)
    }

    private let settings: AppSettings
    private let clips: VoiceClipLibrary?
    private let synthesizer = AVSpeechSynthesizer()
    /// One serial queue, so activate and deactivate always run in the order requested.
    private let audioQueue = DispatchQueue(label: "Anchor.audioSession", qos: .userInitiated)
    private var sessionState: SessionState = .inactive
    /// Message waiting for the audio session to finish activating. Only the latest is kept.
    private var pending: Message?

    private var player: AVAudioPlayer?
    private var remainingClips: [URL] = []
    private var currentText = ""

    init(settings: AppSettings, clips: VoiceClipLibrary?) {
        self.settings = settings
        self.clips = clips
        super.init()
        synthesizer.delegate = self
    }

    var isSpeaking: Bool { synthesizer.isSpeaking || player != nil }

    func speak(_ text: String) {
        speak([text])
    }

    /// Speaks phrases in order as one message, e.g. the route intro and then the first step.
    func speak(_ phrases: [String]) {
        let phrases = phrases.filter { !$0.isEmpty }
        guard !phrases.isEmpty else { return }
        let text = phrases.joined(separator: " ")

        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: text)
            return
        }

        // A new message replaces whatever was being said: stale directions are worse than none.
        stopPlayback()

        let message: Message
        if settings.speechVoice == .anchor, let urls = clips?.urls(for: phrases) {
            message = .clips(urls, text: text)
        } else {
            message = .synthesized(text)
        }

        switch sessionState {
        case .active:
            start(message)
        case .activating:
            pending = message
        case .inactive:
            pending = message
            sessionState = .activating
            audioQueue.async { [weak self] in
                let succeeded = SpeechService.activateAudioSession()
                Task { @MainActor in self?.activationFinished(succeeded: succeeded) }
            }
        }
    }

    func stop() {
        pending = nil
        stopPlayback()
        deactivateAudioSessionIfIdle()
    }

    // MARK: Playback

    private func stopPlayback() {
        synthesizer.stopSpeaking(at: .immediate)
        player?.stop()  // stop() doesn't call the delegate
        player = nil
        remainingClips = []
    }

    private func start(_ message: Message) {
        switch message {
        case .clips(let urls, let text):
            currentText = text
            remainingClips = urls
            playNextClip()
        case .synthesized(let text):
            synthesize(text)
        }
    }

    private func synthesize(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        // Uses the person's Spoken Content voice and rate settings where available.
        utterance.prefersAssistiveTechnologySettings = true
        synthesizer.speak(utterance)
    }

    private func playNextClip() {
        guard !remainingClips.isEmpty else {
            player = nil
            deactivateAudioSessionIfIdle()
            return
        }
        let url = remainingClips.removeFirst()
        do {
            let next = try AVAudioPlayer(contentsOf: url)
            next.delegate = self
            player = next
            guard next.play() else { throw CocoaError(.fileReadCorruptFile) }
        } catch {
            // A damaged clip shouldn't leave the person without the instruction.
            print("SpeechService: could not play \(url.lastPathComponent): \(error)")
            player = nil
            remainingClips = []
            synthesize(currentText)
        }
    }

    private func clipFinished(_ finished: ObjectIdentifier) {
        // Ignore a clip that was already replaced by a newer message.
        guard let player, ObjectIdentifier(player) == finished else { return }
        playNextClip()
    }

    // MARK: Audio session

    /// Back on the main thread once the background activation is done.
    private func activationFinished(succeeded: Bool) {
        // If configuring failed, audio still plays with the default session;
        // staying .inactive means the next message tries again.
        sessionState = succeeded ? .active : .inactive
        if let message = pending {
            pending = nil
            start(message)
        } else {
            // The message was stopped while the session was activating.
            deactivateAudioSessionIfIdle()
        }
    }

    private func deactivateAudioSessionIfIdle() {
        guard sessionState == .active, pending == nil, !isSpeaking else { return }
        sessionState = .inactive
        audioQueue.async {
            SpeechService.deactivateAudioSession()
        }
    }

    // MARK: Audio session work (runs on audioQueue, never on the main thread)

    nonisolated private static func activateAudioSession() -> Bool {
        do {
            let session = AVAudioSession.sharedInstance()
            // .voicePrompt is the mode intended for navigation-style prompts.
            try session.setCategory(.playback, mode: .voicePrompt,
                                    options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            try session.setActive(true)
            return true
        } catch {
            print("SpeechService: could not configure audio session: \(error)")
            return false
        }
    }

    nonisolated private static func deactivateAudioSession() {
        // Lets music or podcasts that were ducked return to full volume.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Delegates
    // Delegate methods are declared nonisolated and hop back to the main actor.

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.deactivateAudioSessionIfIdle() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.deactivateAudioSessionIfIdle() }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let id = ObjectIdentifier(player)
        Task { @MainActor in self.clipFinished(id) }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        let id = ObjectIdentifier(player)
        Task { @MainActor in self.clipFinished(id) }
    }
}
