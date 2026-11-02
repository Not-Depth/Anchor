import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings

        NavigationStack {
            Form {
                Section {
                    Toggle("Step-free routes only", isOn: $settings.requireStepFree)
                } header: {
                    Text("Routes")
                } footer: {
                    Text("Excludes stairs and any connection not confirmed step-free. If no such route exists, the app says so instead of offering stairs.")
                }

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
                    Text("Alerts respond to how close surfaces are in the center of the camera view. They do not identify objects and can miss hazards such as glass, thin poles or drop-offs. Keep using your usual mobility aids.")
                }

                Section {
                    Toggle("Simulate elevator outage", isOn: $settings.simulateElevatorOutage)
                } header: {
                    Text("Demo simulation")
                } footer: {
                    Text("Marks every elevator in the fictional demo map as unavailable, to show how the app handles a missing step-free route. Does not reflect any real elevator.")
                }

                if let map = model.baseMap {
                    Section("Map data") {
                        LabeledContent("Map", value: map.name)
                        LabeledContent("Status", value: map.isFictional ? "Fictional demo data" : map.dataStatus.rawValue)
                        Text(map.disclaimer)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
