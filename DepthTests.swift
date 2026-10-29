import XCTest
@testable import NavigatorCore

final class DepthAnalyzerTests: XCTestCase {
    private func sample(_ depths: [Float], confidence: UInt8 = 2, time: TimeInterval = 10) -> DepthSample {
        DepthSample(depths: depths, confidences: Array(repeating: confidence, count: depths.count), timestamp: time)
    }

    func testMeasuresNearPercentileNotSingleNoisyPixel() {
        // 100 pixels at 2.0 m, plus one spurious 0.3 m pixel.
        var depths = Array(repeating: Float(2.0), count: 100)
        depths[0] = 0.3
        let reading = DepthAnalyzer.analyze(sample(depths))
        XCTAssertEqual(reading.distanceMeters, 2.0)
    }

    func testDetectsCloseSurfaceCoveringPartOfRegion() {
        let depths = Array(repeating: Float(0.8), count: 20) + Array(repeating: Float(3.0), count: 80)
        XCTAssertEqual(DepthAnalyzer.analyze(sample(depths)).distanceMeters ?? 0, 0.8, accuracy: 0.001)
    }

    func testLowConfidenceGivesNoReading() {
        let reading = DepthAnalyzer.analyze(sample(Array(repeating: 1.0, count: 50), confidence: 0))
        XCTAssertEqual(reading.status, .insufficientData)
        XCTAssertEqual(reading.usableFraction, 0)
    }

    func testMissingConfidenceMapGivesNoReading() {
        let s = DepthSample(depths: [1, 1, 1], confidences: nil, timestamp: 0)
        XCTAssertEqual(DepthAnalyzer.analyze(s).status, .insufficientData)
    }

    func testInvalidValuesAreIgnored() {
        let depths: [Float] = [.nan, .infinity, -1, 0, 9.0, 1.5, 1.5, 1.5]
        let reading = DepthAnalyzer.analyze(sample(depths))
        XCTAssertEqual(reading.usableFraction, 3.0 / 8.0, accuracy: 0.0001)
        XCTAssertEqual(reading.distanceMeters, 1.5)
    }

    func testEmptySample() {
        XCTAssertEqual(DepthAnalyzer.analyze(sample([])).status, .insufficientData)
    }

    func testStaleness() {
        let reading = DepthAnalyzer.analyze(sample([1, 1, 1], time: 10))
        XCTAssertFalse(reading.isStale(at: 10.5, maxAge: 0.6))
        XCTAssertTrue(reading.isStale(at: 10.7, maxAge: 0.6))
    }

    func testCenterRegion() {
        let region = DepthAnalyzer.centerRegion(width: 256, height: 192, fraction: 0.25)
        XCTAssertEqual(region.x, 96..<160)
        XCTAssertEqual(region.y, 72..<120)
    }
}

final class ProximityAlertPolicyTests: XCTestCase {
    private func reading(_ distance: Double?, at time: TimeInterval) -> DepthReading {
        DepthReading(
            status: distance.map { .measured(distanceMeters: $0) } ?? .insufficientData,
            usableFraction: distance == nil ? 0 : 1,
            timestamp: time
        )
    }

    func testAlertsOnEnteringNearZoneThenRepeatsAfterInterval() {
        var policy = ProximityAlertPolicy(alertDistance: 1.0)
        XCTAssertNil(policy.update(reading: reading(2.0, at: 0), now: 0))
        XCTAssertEqual(policy.update(reading: reading(0.9, at: 1), now: 1), .near(distanceMeters: 0.9))
        XCTAssertNil(policy.update(reading: reading(0.8, at: 2), now: 2))       // within repeat interval
        XCTAssertEqual(policy.update(reading: reading(0.8, at: 4.1), now: 4.1), .near(distanceMeters: 0.8))
    }

    func testHysteresisPreventsFlicker() {
        var policy = ProximityAlertPolicy(alertDistance: 1.0)
        XCTAssertNotNil(policy.update(reading: reading(0.95, at: 0), now: 0))
        XCTAssertNil(policy.update(reading: reading(1.1, at: 0.1), now: 0.1))   // still within hysteresis
        XCTAssertTrue(policy.isNear)
        XCTAssertNil(policy.update(reading: reading(1.3, at: 0.2), now: 0.2))   // past 1.25 m: re-armed
        XCTAssertFalse(policy.isNear)
        XCTAssertNotNil(policy.update(reading: reading(0.95, at: 0.3), now: 0.3))
    }

    func testBriefGapsDoNotRetriggerAlerts() {
        var policy = ProximityAlertPolicy(alertDistance: 1.0)
        XCTAssertNotNil(policy.update(reading: reading(0.9, at: 0), now: 0))
        XCTAssertNil(policy.update(reading: reading(nil, at: 0.2), now: 0.2))
        XCTAssertNil(policy.update(reading: reading(0.9, at: 0.4), now: 0.4))   // same near zone, interval not elapsed
    }

    func testReportsUnreliableOnceAfterGraceThenRestored() {
        var policy = ProximityAlertPolicy(alertDistance: 1.0)
        // No "unreliable" before the first good reading (sensor still warming up).
        XCTAssertNil(policy.update(reading: nil, now: 0))
        XCTAssertNil(policy.update(reading: nil, now: 5))

        XCTAssertNil(policy.update(reading: reading(2.0, at: 6), now: 6))
        XCTAssertNil(policy.update(reading: reading(nil, at: 6.5), now: 6.5))
        XCTAssertEqual(policy.update(reading: reading(nil, at: 7.6), now: 7.6), .readingsUnreliable)
        XCTAssertNil(policy.update(reading: reading(nil, at: 9), now: 9))         // only once
        XCTAssertEqual(policy.update(reading: reading(2.0, at: 10), now: 10), .readingsRestored)
    }

    func testStaleReadingCountsAsUnreliable() {
        var policy = ProximityAlertPolicy(alertDistance: 1.0)
        XCTAssertNil(policy.update(reading: reading(2.0, at: 0), now: 0))
        // Frames stopped arriving: the last reading (t = 0) ages out.
        XCTAssertNil(policy.update(reading: reading(0.5, at: 0), now: 0.7))
        XCTAssertEqual(policy.update(reading: reading(0.5, at: 0), now: 1.8), .readingsUnreliable)
    }
}
