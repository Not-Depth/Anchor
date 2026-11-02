import SwiftUI
import UIKit

/// Nearby tab: experimental LiDAR depth readings from the center of the camera view.
struct NearbyView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    private var vm: NearbyViewModel { model.nearby }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    experimentalNotice
                    content
                }
                .padding()
            }
            .navigationTitle("Nearby")
        }
        // Never leave the camera on when the person switches tabs.
        .onDisappear { vm.stop() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: vm.suspend()
            case .active: Task { await vm.resume() }
            default: break
            }
        }
    }

    // MARK: Content per state

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .unsupported(let message):
            messageCard(title: "Not available on this device", message: message, systemImage: "sensor")

        case .permissionDenied(let restricted):
            messageCard(
                title: "Camera access is off",
                message: restricted
                    ? "Camera access is restricted on this device (for example by Screen Time), so Nearby can't run. Routes work normally."
                    : "Nearby needs the camera to read LiDAR depth. You can allow camera access for UB Access Navigator in the Settings app. Routes work without it.",
                systemImage: "camera.badge.ellipsis"
            )
            if !restricted {
                largeButton("Open Settings app", systemImage: "gear") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            }

        case .idle:
            Text("Point the back camera in the direction you're facing. The app reports how far away surfaces are in the center of the view.")
            alertSummary
            largeButton("Start depth sensing", systemImage: "play.fill") {
                Task { await vm.start() }
            }

        case .running, .interrupted:
            cameraPreview
            readingCard
            alertSummary
            largeButton("Stop", systemImage: "stop.fill") { vm.stop() }

        case .failed(let message):
            messageCard(title: "Depth sensing stopped", message: message, systemImage: "exclamationmark.triangle")
            largeButton("Try again", systemImage: "arrow.clockwise") {
                Task { await vm.start() }
            }
        }
    }

    // MARK: Pieces

    private var experimentalNotice: some View {
        Label {
            Text("Experimental. Readings are approximate and do not identify objects. They can miss glass, thin poles, overhangs and drop-offs. Keep using your usual mobility aids.")
                .font(.subheadline)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var cameraPreview: some View {
        #if targetEnvironment(simulator)
        EmptyView()
        #else
        DepthCameraView { session in vm.sessionReady(session) }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                // Marks the analyzed region (center 30% of the view, approximately).
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.white, lineWidth: 3)
                    .frame(width: 90, height: 90)
                    .shadow(radius: 2)
            }
            .overlay {
                if vm.state == .interrupted {
                    Text("Camera paused by the system")
                        .font(.headline)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            // The preview carries no information beyond the reading card below.
            .accessibilityHidden(true)
        #endif
    }

    private var readingCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nearest surface, center of view")
                .font(.headline)
            Text(readingText.visual)
                .font(.largeTitle.weight(.bold))
                .monospacedDigit()
            Text(readingText.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Nearest surface, center of view")
        .accessibilityValue("\(readingText.spoken). \(readingText.detail)")
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// Text for the reading card, in visual and spoken form.
    private var readingText: (visual: String, spoken: String, detail: String) {
        if vm.state == .interrupted {
            return ("—", "No reading", "The camera is paused. Readings resume when the system releases it.")
        }
        guard let reading = vm.currentReading else {
            return ("—", "No current reading", "Waiting for depth data.")
        }
        switch reading.status {
        case .measured(let distance) where distance > 4.5:
            return ("> 4.5 m", "More than 4.5 meters", "Nothing close detected in the center of the view.")
        case .measured(let distance):
            return (DistanceText.depth(distance), "About \(DistanceText.spokenDepth(distance))",
                    "Depth quality: \(Int(reading.usableFraction * 100))% of points usable.")
        case .insufficientData:
            return ("—", "No reliable reading",
                    "Too few confident depth points (\(Int(reading.usableFraction * 100))% usable). Try pointing at surfaces within a few meters.")
        }
    }

    private var alertSummary: some View {
        let settings = model.settings
        let text: String
        if settings.anyNearbyAlertsEnabled {
            var kinds: [String] = []
            if settings.nearbyAudioAlerts { kinds.append("audio") }
            if settings.nearbyHapticAlerts { kinds.append("haptic") }
            text = "Alerts on (\(kinds.joined(separator: " and "))) for surfaces closer than \(String(format: "%.2g", settings.nearbyAlertDistance)) m. Change in Settings."
        } else {
            text = "Alerts are off. Turn on audio or haptic alerts in Settings."
        }
        return Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private func messageCard(title: String, message: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.title3.weight(.semibold))
            Text(message)
        }
        .accessibilityElement(children: .combine)
    }

    private func largeButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
    }
}
