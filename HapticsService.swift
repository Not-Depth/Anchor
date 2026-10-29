import UIKit

/// Small wrapper around UIKit's feedback generators so the rest of the app asks for
/// *meanings* ("proximity alert") rather than specific vibration styles.
@MainActor
final class HapticsService {
    private let impact: UIImpactFeedbackGenerator
    private let notification: UINotificationFeedbackGenerator

    init() {
        impact = UIImpactFeedbackGenerator(style: .heavy)
        notification = UINotificationFeedbackGenerator()
    }

    /// Call shortly before alerts are likely, to reduce latency.
    func prepare() {
        impact.prepare()
        notification.prepare()
    }

    /// A surface came within the alert distance.
    func proximityAlert() {
        impact.impactOccurred(intensity: 1.0)
    }

    /// Something stopped working (for example, depth readings became unreliable).
    func warning() {
        notification.notificationOccurred(.warning)
    }
}
