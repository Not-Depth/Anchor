import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings

        NavigationStack {
            Form {
                Section {
                    Toggle("Speak directions", isOn: $settings.spokenDirections)
                    Button("Test voice") {
                        model.speech.speak("This is how route directions will sound.")
                    }
                } header: {
                    Text("Spoken directions")
                } footer: {
                    Text("With VoiceOver on, VoiceOver reads each new step and spoken messages use VoiceOver's voice.")
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
                }
            }
            .navigationTitle("Settings")
        }
    }
}
