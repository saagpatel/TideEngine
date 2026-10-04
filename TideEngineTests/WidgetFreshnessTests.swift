import XCTest
@testable import TideEngine

final class WidgetFreshnessTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_774_138_200)

    private func cache(age: TimeInterval, eventOffsets: [TimeInterval]) -> CachedTideData {
        let station = TideStation(id: "fixture", name: "Fixture", latitude: 0, longitude: 0, dataSource: .noaa)
        let fetchedAt = now.addingTimeInterval(-age)
        return CachedTideData(
            stationId: station.id, stationName: station.name,
            predictions: eventOffsets.map {
                TidePrediction(timestamp: now.addingTimeInterval($0), heightMeters: 1,
                               type: .high, station: station)
            },
            hourlyCurve: [], fetchedAt: fetchedAt,
            expiresAt: fetchedAt.addingTimeInterval(86400)
        )
    }

    func testFreshCacheWithFutureEventIsUsable() {
        XCTAssertTrue(WidgetPredictionFreshness.isUsable(cache(age: 0, eventOffsets: [60]), at: now))
    }

    func testExpiredAppCacheWithinOfflineWindowIsUsable() {
        let cached = cache(age: 36 * 3600, eventOffsets: [-60, 60])
        XCTAssertLessThan(cached.expiresAt, now)
        XCTAssertTrue(WidgetPredictionFreshness.isUsable(cached, at: now))
    }

    func testMaximumAgeBoundaryAndOlderCache() {
        XCTAssertEqual(WidgetPredictionFreshness.maximumAge, 48 * 3600)
        XCTAssertTrue(WidgetPredictionFreshness.isUsable(
            cache(age: 48 * 3600, eventOffsets: [60]), at: now
        ))
        XCTAssertFalse(WidgetPredictionFreshness.isUsable(
            cache(age: 48 * 3600 + 1, eventOffsets: [60]), at: now
        ))
    }

    func testEmptyPastAndCurrentEventsAreUnusable() {
        for offsets: [TimeInterval] in [[], [-60], [-60, 0]] {
            XCTAssertFalse(WidgetPredictionFreshness.isUsable(cache(age: 60, eventOffsets: offsets), at: now))
        }
    }

    func testFutureFetchTimestampIsUnusable() {
        XCTAssertFalse(WidgetPredictionFreshness.isUsable(cache(age: -1, eventOffsets: [60]), at: now))
    }

    func testTimelineEntryReevaluatesAgeAndRemainingEvents() {
        let agingCache = cache(age: 48 * 3600 - 60, eventOffsets: [3600])
        XCTAssertTrue(WidgetPredictionFreshness.isUsable(agingCache, at: now))
        XCTAssertFalse(WidgetPredictionFreshness.isUsable(agingCache, at: now.addingTimeInterval(120)))

        let endingCache = cache(age: 60, eventOffsets: [60])
        XCTAssertTrue(WidgetPredictionFreshness.isUsable(endingCache, at: now))
        XCTAssertFalse(WidgetPredictionFreshness.isUsable(endingCache, at: now.addingTimeInterval(60)))
    }
}
