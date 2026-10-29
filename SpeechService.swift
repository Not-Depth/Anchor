import AVFoundation
import UIKit

/// Speaks short messages (route instructions, nearby alerts).
///
/// - With VoiceOver on, messages go through VoiceOver as announcements, so the person
///   hears one voice, at their VoiceOver rate, instead of two voices talking over each other.
/// - Otherwise AVSpeechSynthesizer speaks them, ducking other audio such as music.
///
/// Whether to speak at all is decided by the caller (based on AppSettings).
@MainActor
final class SpeechService: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var audioSessionActive = false

    var isSpeaking: Bool { synthesizer.isSpeaking }

    func speak(_ text: String) {
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: text)
            return
        }

        // Set here rather than in init, which keeps this @MainActor class from having to
        // override NSObject's nonisolated init.
        if synthesizer.delegate == nil {
            synthesizer.delegate = self
        }
        // A new message replaces whatever was being said: stale directions are worse than none.
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        activateAudioSession()

        let utterance = AVSpeechUtterance(string: text)
        // Uses the person's Spoken Content voice and rate settings where available.
        utterance.prefersAssistiveTechnologySettings = true
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: Audio session

    private func activateAudioSession() {
        guard !audioSessionActive else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            // .voicePrompt is the mode intended for navigation-style prompts.
            try session.setCategory(.playback, mode: .voicePrompt,
                                    options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            try session.setActive(true)
            audioSessionActive = true
        } catch {
            // Speech still works with the default session; nothing else to do.
            print("SpeechService: could not configure audio session: \(error)")
        }
    }

    private func deactivateAudioSessionIfIdle() {
        guard audioSessionActive, !synthesizer.isSpeaking else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        audioSessionActive = false
    }

    // MARK: AVSpeechSynthesizerDelegate
    // Delegate methods are declared nonisolated and hop back to the main actor.

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.deactivateAudioSessionIfIdle() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.deactivateAudioSessionIfIdle() }
    }
}
