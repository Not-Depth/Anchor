import AVFoundation
import Foundation
import Observation
#if !targetEnvironment(simulator)
import ARKit
#endif

/// State for the Nearby tab: device support, camera permission, the session lifecycle,
/// the latest depth reading, and alerts.
///
/// Owned by AppModel, so there is exactly one instance for the app's lifetime.
@MainActor
@Observable
final class NearbyViewModel {
    enum State: Equatable {
        case unsupported(String)
        case permissionDenied(restricted: Bool)
        /// Supported and allowed (or not asked yet); camera off.
        case idle
        /// Camera and depth capture running.
        case running
        /// ARKit paused the session (e.g. another app is using the camera).
        case interrupted
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var latestReading: DepthReading?
    /// Refreshed by the tick loop, so "too old" readings disappear from the screen even
    /// when no new frames arrive.
    private(set) var now: TimeInterval = ProcessInfo.processInfo.systemUptime

    /// A reading older than this is treated as missing.
    static let maxReadingAge: TimeInterval = 0.6

    private let settings: AppSettings
    private let speech: SpeechService
    private let haptics: HapticsService
    @ObservationIgnored private var alertPolicy = ProximityAlertPolicy(alertDistance: 1.0)
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var resumeWhenActive = false

    #if !targetEnvironment(simulator)
    private let semantic: DepthSemantic?
    private let controller: DepthSessionController
    #endif

    init(settings: AppSettings, speech: SpeechService, haptics: HapticsService) {
        self.settings = settings
        self.speech = speech
        self.haptics = haptics
        #if !targetEnvironment(simulator)
        self.semantic = DepthSemantic.bestSupported()
        self.controller = DepthSessionController()
        #endif
        state = Self.checkSupportAndPermission()
        #if !targetEnvironment(simulator)
        controller.onReading = { [weak self] reading in self?.latestReading = reading }
        controller.onEvent = { [weak self] event in self?.handle(event) }
        #endif
    }

    var isSupported: Bool {
        if case .unsupported = state { return false }
        return true
    }

    /// The latest reading, if it is fresh enough to show; otherwise nil.
    var currentReading: DepthReading? {
        guard let reading = latestReading, !reading.isStale(at: now, maxAge: Self.maxReadingAge) else { return nil }
        return reading
    }

    // MARK: Support & permission

    private static func checkSupportAndPermission() -> State {
        #if targetEnvironment(simulator)
        return .unsupported("The Simulator has no camera or LiDAR. Run the app on a LiDAR-equipped iPhone to try Nearby. Routes work normally here.")
        #else
        guard DepthSemantic.bestSupported() != nil else {
            return .unsupported("This device has no LiDAR scanner, so depth readings aren't available. Routes work normally.")
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied: return .permissionDenied(restricted: false)
        case .restricted: return .permissionDenied(restricted: true)
        default: return .idle
        }
        #endif
    }

    // MARK: Start / stop

    /// Called when the person taps Start. Asks for camera permission the first time.
    func start() async {
        guard isSupported else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            beginRunning()
        case .notDetermined:
            if await AVCaptureDevice.requestAccess(for: .video) {
                beginRunning()
            } else {
                state = .permissionDenied(restricted: false)
            }
        case .restricted:
            state = .permissionDenied(restricted: true)
        default:
            state = .permissionDenied(restricted: false)
        }
    }

    private func beginRunning() {
        latestReading = nil
        alertPolicy.reset()
        haptics.prepare()
        // NearbyView reacts by showing the camera view, which calls sessionReady(_:).
        state = .running
        startTicking()
    }

    func stop() {
        #if !targetEnvironment(simulator)
        controller.stop()
        #endif
        stopTicking()
        latestReading = nil
        if state == .running || state == .interrupted {
            state = .idle
        }
    }

    #if !targetEnvironment(simulator)
    /// The camera view has created its ARSession: configure and run it.
    func sessionReady(_ session: ARSession) {
        guard let semantic, state == .running else { return }
        controller.start(on: session, semantic: semantic)
    }
    #endif

    // MARK: App lifecycle

    /// The app moved to the background: stop the camera, remember to restart it.
    func suspend() {
        resumeWhenActive = (state == .running || state == .interrupted)
        stop()
    }

    /// The app is active again. Camera permission may have changed in the Settings app.
    func resume() async {
        let fresh = Self.checkSupportAndPermission()
        guard fresh == .idle else {
            stop()
            state = fresh
            resumeWhenActive = false
            return
        }
        if state != .running && state != .interrupted {
            state = .idle
        }
        if resumeWhenActive {
            resumeWhenActive = false
            await start()
        }
    }

    // MARK: Session events

    #if !targetEnvironment(simulator)
    private func handle(_ event: DepthSessionEvent) {
        switch event {
        case .interrupted:
            if state == .running { state = .interrupted }
            latestReading = nil
        case .interruptionEnded:
            if state == .interrupted { state = .running }
        case .cameraAccessDenied:
            stop()
            state = .permissionDenied(restricted: false)
        case .failed(let message):
            stop()
            state = .failed(message)
        }
    }
    #endif

    // MARK: Tick loop: staleness and alerts

    private func startTicking() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self else { return }
                self.tick()
            }
        }
    }

    private func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
    }

    private func tick() {
        now = ProcessInfo.processInfo.systemUptime
        guard state == .running else { return }
        alertPolicy.alertDistance = settings.nearbyAlertDistance
        if let event = alertPolicy.update(reading: latestReading, now: now) {
            deliver(event)
        }
    }

    private func deliver(_ event: ProximityAlertPolicy.Event) {
        switch event {
        case .near(let distance):
            if settings.nearbyHapticAlerts { haptics.proximityAlert() }
            if settings.nearbyAudioAlerts { speech.speak("Surface at \(DistanceText.spokenDepth(distance))") }
        case .readingsUnreliable:
            if settings.nearbyHapticAlerts { haptics.warning() }
            if settings.nearbyAudioAlerts { speech.speak("Depth readings unavailable. Alerts paused.") }
        case .readingsRestored:
            if settings.nearbyAudioAlerts { speech.speak("Depth readings restored.") }
        }
    }
}
