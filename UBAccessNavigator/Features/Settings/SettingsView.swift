import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var settings = model.settings

        NavigationStack {
            Form {
                Section {
                    Toggle("Speak directions", isOn: $settings.spokenDirections)
                    Picker("Voice", selection: $settings.speechVoice) {
                        ForEach(AppSettings.SpeechVoice.allCases) { voice in
                            Text(voice.displayName).tag(voice)
                        }
                    }
                    Button("Test voice") {
                        model.speech.speak(SpokenPhrases.voiceTest)
                    }
                } header: {
                    Text("Spoken directions")
                } footer: {
                    Text(voiceFooter)
                }

                Section {
                    if model.floorTracker.isSupported {
                        Toggle("Check floor changes", isOn: $settings.floorDetection)
                        LabeledContent("Motion & Fitness", value: floorAccessText)
                        if settings.floorDetection {
                            switch model.floorTracker.access {
                            case .notAsked:
                                Button("Allow Motion & Fitness") { model.floorTracker.requestAccess() }
                            case .denied:
                                Button("Open iPhone Settings") {
                                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                                }
                            case .allowed, .restricted, .unavailable:
                                EmptyView()
                            }
                        }
                    } else {
                        Text("This iPhone has no barometer, so floor checks aren't available.")
                    }
                } header: {
                    Text("Floor changes")
                } footer: {
                    Text("On stairs and elevator steps, Anchor uses the barometer to check that you went up or down the right number of floors. It measures air pressure only, not your location, and nothing leaves your iPhone. Weather and air conditioning can shift readings, so keep confirming each landmark yourself.")
                }

                Section {
                    Toggle("Audio alerts", isOn: $settings.nearbyAudioAlerts)
                    Toggle("Haptic alerts", isOn: $settings.nearbyHapticAlerts)
                    Picker("Alert distance", selection: $settings.nearbyAlertDistance) {
                        ForEach(AppSettings.alertDistanceOptions, id: \.self) { distance in
                            Text(String(format: "%.2g m", distance)).tag(distance)
                        }
                    }
                } header: {
                    Text("Nearby alerts (experimental)")
                } footer: {
                    Text("Alerts respond to how close surfaces are in the center of the camera view. They do not identify objects and can miss hazards such as glass, thin poles or drop-offs. Keep using your cane, guide dog or other usual mobility aids.")
                }

                if let map = model.map {
                    Section("Map data") {
                        LabeledContent("Map", value: map.name)
                        LabeledContent("Status", value: map.isFictional ? "Fictional demo data" : map.dataStatus.rawValue)
                        Text(map.disclaimer)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("About Anchor") {
                    Text("Anchor helps blind and low-vision students get around campus with spoken, landmark-by-landmark directions.")
                    if case .bundled(let voiceName, _) = model.voiceStatus {
                        LabeledContent("Anchor voice", value: "\(voiceName), by ElevenLabs (elevenlabs.io)")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var floorAccessText: String {
        switch model.floorTracker.access {
        case .allowed: "Allowed"
        case .notAsked: "Not asked yet"
        case .denied: "Off for Anchor"
        case .restricted: "Restricted on this iPhone"
        case .unavailable: "Not available"
        }
    }

    private var voiceFooter: String {
        var lines: [String] = []
        switch (model.settings.speechVoice, model.voiceStatus) {
        case (.anchor, .notBundled):
            lines.append("The Anchor voice isn't included in this build, so the iPhone voice is used.")
        case (.anchor, .bundled(let voiceName, let missing)):
            lines.append("Anchor voice is a recorded voice (\(voiceName)) that works offline.")
            if missing > 0 {
                lines.append("\(missing) \(missing == 1 ? "phrase has" : "phrases have") no recording yet and will use the iPhone voice.")
            }
        case (.system, _):
            lines.append("iPhone voice follows your Spoken Content voice and speaking rate.")
        }
        lines.append("With VoiceOver on, VoiceOver reads each new step and spoken messages use VoiceOver's voice.")
        return lines.joined(separator: " ")
    }
}
