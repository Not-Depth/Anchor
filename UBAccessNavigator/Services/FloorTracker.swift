import CoreMotion
import Foundation
import Observation

/// Reads the iPhone's barometer (CMAltimeter) to notice floor changes.
///
/// - Needs the Motion & Fitness permission. iOS asks the first time readings start, using
///   the NSMotionUsageDescription text in the app's Info.plist.
/// - Measures air pressure only. It doesn't know where the person is, and readings never
///   leave the phone.
/// - Runs only while a stairs or elevator step is on screen during guidance.
@MainActor
@Observable
final class FloorTracker {
    enum Access: Equatable {
        /// This iPhone has no barometer.
        case unavailable
        case notAsked
        case allowed
        /// Turned off for Anchor in iPhone Settings → Privacy & Security → Motion & Fitness.
        case denied
        /// Blocked by a device policy, such as Screen Time or a school profile.
        case restricted
    }

    private(set) var access: Access = .notAsked
    private(set) var isRunning = false
    private(set) var detector = FloorChangeDetector()

    /// Kept for the app's lifetime: an altimeter that is released stops delivering readings.
    private let altimeter = CMAltimeter()
    private var permissionCompletion: (() -> Void)?

    init() {
        refreshAccess()
    }

    var isSupported: Bool { access != .unavailable }

    /// Call when the app returns to the foreground, in case the person changed the permission.
    func refreshAccess() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            access = .unavailable
            return
        }
        switch CMAltimeter.authorizationStatus() {
        case .authorized: access = .allowed
        case .denied: access = .denied
        case .restricted: access = .restricted
        case .notDetermined: access = .notAsked
        @unknown default: access = .notAsked
        }
    }

    /// Shows the iOS Motion & Fitness prompt if it hasn't been answered yet. iOS has no
    /// separate request call for the barometer: starting readings is what asks, so this
    /// starts them and stops at the first answer.
    func requestAccess(completion: (() -> Void)? = nil) {
        refreshAccess()
        guard access == .notAsked, !isRunning else {
            completion?()
            return
        }
        permissionCompletion = completion
        startUpdates()
    }

    /// Start measuring from now, e.g. when a stairs step begins. Does nothing unless the
    /// permission was already given, so iOS never interrupts guidance with a prompt.
    func startMeasuring() {
        refreshAccess()
        guard access == .allowed else { return }
        detector.reset()
        if !isRunning { startUpdates() }
    }

    func stop() {
        guard isRunning else { return }
        altimeter.stopRelativeAltitudeUpdates()
        isRunning = false
    }

    // MARK: Readings

    private func startUpdates() {
        isRunning = true
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            let meters = data?.relativeAltitude.doubleValue
            let failed = error != nil
            Task { @MainActor in self?.handle(meters: meters, failed: failed) }
        }
    }

    private func handle(meters: Double?, failed: Bool) {
        if let completion = permissionCompletion {
            // Only the permission answer was wanted, not readings.
            permissionCompletion = nil
            stop()
            detector.reset()
            refreshAccess()
            completion()
            return
        }
        if failed {
            // Usually Motion & Fitness was turned off, or the sensor is unavailable.
            stop()
            refreshAccess()
        } else if let meters {
            detector.add(relativeAltitude: meters)
        }
    }
}
