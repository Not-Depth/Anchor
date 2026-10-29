// ARKit isn't usable in the Simulator, so this whole file is compiled only for devices.
// NearbyViewModel reports "not available in the Simulator" instead.
#if !targetEnvironment(simulator)

import ARKit
import Foundation

/// Which depth stream to request, decided once by checking the device.
enum DepthSemantic {
    /// Temporally smoothed LiDAR depth: fewer holes and less flicker, slightly more lag.
    case smoothedSceneDepth
    /// Per-frame LiDAR depth.
    case sceneDepth

    var frameSemantics: ARConfiguration.FrameSemantics {
        switch self {
        case .smoothedSceneDepth: return .smoothedSceneDepth
        case .sceneDepth: return .sceneDepth
        }
    }

    /// Checks `supportsFrameSemantics` before anything is enabled. Returns nil on devices
    /// without LiDAR (or without world tracking).
    static func bestSupported() -> DepthSemantic? {
        guard ARWorldTrackingConfiguration.isSupported else { return nil }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) { return .smoothedSceneDepth }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) { return .sceneDepth }
        return nil
    }
}

enum DepthSessionEvent {
    case interrupted
    case interruptionEnded
    case cameraAccessDenied
    case failed(String)
}

/// Starts and stops the ARKit session. Lives on the main actor.
///
/// Frame handling happens in `DepthFrameDelegate` on a background queue; results come
/// back here through `onReading` / `onEvent`, always on the main actor.
@MainActor
final class DepthSessionController {
    /// Roughly 10 readings per second while running.
    var onReading: ((DepthReading) -> Void)?
    var onEvent: ((DepthSessionEvent) -> Void)?

    private weak var session: ARSession?
    /// ARSession only keeps a weak reference to its delegate, so we keep the strong one.
    private var frameDelegate: DepthFrameDelegate?
    private let frameQueue = DispatchQueue(label: "UBAccessNavigator.depthFrames", qos: .userInitiated)

    /// Starts depth capture on the session that belongs to the camera preview view.
    func start(on session: ARSession, semantic: DepthSemantic) {
        let delegate = DepthFrameDelegate(
            semantic: semantic,
            onReading: { [weak self] reading in
                Task { @MainActor in self?.onReading?(reading) }
            },
            onEvent: { [weak self] event in
                Task { @MainActor in self?.onEvent?(event) }
            }
        )
        frameDelegate = delegate
        self.session = session

        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = semantic.frameSemantics
        configuration.isLightEstimationEnabled = false

        session.delegateQueue = frameQueue
        session.delegate = delegate
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    func stop() {
        session?.pause()
        session?.delegate = nil
        session = nil
        frameDelegate = nil
    }
}

/// Receives ARKit callbacks on the frame queue and turns depth frames into readings.
final class DepthFrameDelegate: NSObject, ARSessionDelegate {
    /// Fraction of the depth map's width and height to analyze, centered.
    static let centerFraction = 0.3
    /// Process at most ~10 frames per second; ARKit delivers up to 60.
    static let minimumInterval: TimeInterval = 0.1

    private let semantic: DepthSemantic
    private let onReading: @Sendable (DepthReading) -> Void
    private let onEvent: @Sendable (DepthSessionEvent) -> Void
    /// Only touched on the frame queue.
    private var lastProcessed: TimeInterval = 0

    init(semantic: DepthSemantic,
         onReading: @escaping @Sendable (DepthReading) -> Void,
         onEvent: @escaping @Sendable (DepthSessionEvent) -> Void) {
        self.semantic = semantic
        self.onReading = onReading
        self.onEvent = onEvent
    }

    // MARK: ARSessionDelegate

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard frame.timestamp - lastProcessed >= Self.minimumInterval else { return }
        lastProcessed = frame.timestamp

        // Read what we need from the frame here and don't keep it:
        // holding on to ARFrames starves ARKit of camera buffers.
        let depthData: ARDepthData?
        switch semantic {
        case .smoothedSceneDepth: depthData = frame.smoothedSceneDepth
        case .sceneDepth: depthData = frame.sceneDepth
        }

        guard let depthData else {
            // Depth missing from this frame (common for a moment after starting).
            onReading(DepthReading(status: .insufficientData, usableFraction: 0, timestamp: frame.timestamp))
            return
        }
        let sample = Self.centerSample(of: depthData, timestamp: frame.timestamp)
        onReading(DepthAnalyzer.analyze(sample))
    }

    func sessionWasInterrupted(_ session: ARSession) {
        onEvent(.interrupted)
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        onEvent(.interruptionEnded)
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        if (error as? ARError)?.code == .cameraUnauthorized {
            onEvent(.cameraAccessDenied)
        } else {
            onEvent(.failed(error.localizedDescription))
        }
    }

    // MARK: Reading the depth buffer

    /// Copies the centered region of the depth map (Float32 meters) and confidence map
    /// (UInt8 ARConfidenceLevel raw values) into plain arrays for DepthAnalyzer.
    static func centerSample(of depthData: ARDepthData, timestamp: TimeInterval) -> DepthSample {
        let depthMap = depthData.depthMap
        let empty = DepthSample(depths: [], confidences: nil, timestamp: timestamp)

        guard CVPixelBufferGetPixelFormatType(depthMap) == kCVPixelFormatType_DepthFloat32 else { return empty }
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let region = DepthAnalyzer.centerRegion(width: width, height: height, fraction: centerFraction)

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(depthMap) else { return empty }
        let rowBytes = CVPixelBufferGetBytesPerRow(depthMap)

        var depths: [Float] = []
        depths.reserveCapacity(region.x.count * region.y.count)
        for y in region.y {
            let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: Float32.self)
            for x in region.x { depths.append(row[x]) }
        }

        let confidences = confidenceValues(depthData.confidenceMap, width: width, height: height, region: region)
        return DepthSample(depths: depths, confidences: confidences, timestamp: timestamp)
    }

    private static func confidenceValues(
        _ map: CVPixelBuffer?,
        width: Int,
        height: Int,
        region: (x: Range<Int>, y: Range<Int>)
    ) -> [UInt8]? {
        guard let map,
              CVPixelBufferGetPixelFormatType(map) == kCVPixelFormatType_OneComponent8,
              CVPixelBufferGetWidth(map) == width,
              CVPixelBufferGetHeight(map) == height else { return nil }

        CVPixelBufferLockBaseAddress(map, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(map, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(map) else { return nil }
        let rowBytes = CVPixelBufferGetBytesPerRow(map)

        var values: [UInt8] = []
        values.reserveCapacity(region.x.count * region.y.count)
        for y in region.y {
            let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: UInt8.self)
            for x in region.x { values.append(row[x]) }
        }
        return values
    }
}

#endif
