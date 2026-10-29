import Foundation

// Pure depth-processing logic, kept apart from ARKit so it can be unit-tested with
// hand-made arrays. The ARKit layer copies a small region of each depth frame into a
// `DepthSample` and hands it to `DepthAnalyzer`.
//
// What this does NOT do: identify objects. A reading only says "some surface in the
// center of the camera view is about this far away".

/// Mirrors ARKit's `ARConfidenceLevel` raw values (low = 0, medium = 1, high = 2).
enum DepthConfidence: UInt8, Comparable {
    case low = 0
    case medium = 1
    case high = 2

    static func < (lhs: DepthConfidence, rhs: DepthConfidence) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A rectangular patch of a depth frame, copied out of the pixel buffer.
struct DepthSample {
    /// Distances in meters, row by row.
    var depths: [Float]
    /// Per-pixel confidence (same count as `depths`), or `nil` if the frame had none.
    var confidences: [UInt8]?
    /// ARKit frame timestamp, in seconds of system uptime.
    var timestamp: TimeInterval
}

struct DepthAnalysisSettings: Equatable {
    /// Pixels below this confidence are ignored.
    var minimumConfidence: DepthConfidence = .medium
    /// If fewer than this fraction of pixels are usable, there is no reading.
    var minimumUsableFraction: Double = 0.25
    /// Which percentile of usable depths counts as "nearest". Using a low percentile
    /// instead of the minimum ignores a few noisy pixels.
    var nearPercentile: Double = 0.05
    /// LiDAR depth is reported out to roughly 5 m; ignore anything outside this band.
    var validRange: ClosedRange<Float> = 0.1...5.0
}

struct DepthReading: Equatable {
    enum Status: Equatable {
        /// A usable measurement of the nearest surface in the analyzed region.
        case measured(distanceMeters: Double)
        /// Too few usable pixels (low confidence, out of range, or invalid values).
        case insufficientData
    }

    var status: Status
    /// Fraction of pixels that passed the confidence and range checks (0...1).
    var usableFraction: Double
    var timestamp: TimeInterval

    var distanceMeters: Double? {
        if case .measured(let d) = status { return d }
        return nil
    }

    /// A reading older than `maxAge` must not be shown as current or used for alerts.
    func isStale(at now: TimeInterval, maxAge: TimeInterval) -> Bool {
        now - timestamp > maxAge
    }
}

enum DepthAnalyzer {
    static func analyze(_ sample: DepthSample, settings: DepthAnalysisSettings = .init()) -> DepthReading {
        let total = sample.depths.count
        guard total > 0 else {
            return DepthReading(status: .insufficientData, usableFraction: 0, timestamp: sample.timestamp)
        }

        // Without a confidence map we cannot tell good pixels from bad ones,
        // so treat the whole sample as unusable rather than guessing.
        guard let confidences = sample.confidences, confidences.count == total else {
            return DepthReading(status: .insufficientData, usableFraction: 0, timestamp: sample.timestamp)
        }

        var usable: [Float] = []
        usable.reserveCapacity(total)
        for i in 0..<total {
            let depth = sample.depths[i]
            let confidence = DepthConfidence(rawValue: confidences[i]) ?? .low
            guard depth.isFinite,
                  settings.validRange.contains(depth),
                  confidence >= settings.minimumConfidence else { continue }
            usable.append(depth)
        }

        let fraction = Double(usable.count) / Double(total)
        guard fraction >= settings.minimumUsableFraction else {
            return DepthReading(status: .insufficientData, usableFraction: fraction, timestamp: sample.timestamp)
        }

        usable.sort()
        let index = Int((Double(usable.count - 1) * settings.nearPercentile).rounded(.down))
        return DepthReading(
            status: .measured(distanceMeters: Double(usable[index])),
            usableFraction: fraction,
            timestamp: sample.timestamp
        )
    }

    /// Picks the centered rectangle covering `fraction` of each dimension.
    /// Shared by the ARKit layer and the tests so both agree on "the center".
    static func centerRegion(width: Int, height: Int, fraction: Double) -> (x: Range<Int>, y: Range<Int>) {
        let w = max(1, Int(Double(width) * fraction))
        let h = max(1, Int(Double(height) * fraction))
        let x0 = (width - w) / 2
        let y0 = (height - h) / 2
        return (x0..<(x0 + w), y0..<(y0 + h))
    }
}
