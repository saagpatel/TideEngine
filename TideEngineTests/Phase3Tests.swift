import XCTest
@testable import TideEngine

final class Phase3Tests: XCTestCase {
    func testHaversineDistance_SFisCloseToNOAAStation() {
        let distance = NOAAClient.haversineDistance(
            lat1: 37.7749, lon1: -122.4194,
            lat2: 37.806305, lon2: -122.465889
        )
        XCTAssertLessThan(distance, 200)
    }

    func testHaversineDistance_TokyoIsOutsideSupportedRegion() {
        let distance = NOAAClient.haversineDistance(
            lat1: 35.6762, lon1: 139.6503,
            lat2: 37.806305, lon2: -122.465889
        )
        XCTAssertGreaterThan(distance, 200)
    }

    func testUnsupportedRegionErrorExplainsNOAABoundary() {
        let error = TideError.unsupportedRegion
        let description = try! XCTUnwrap(error.errorDescription).lowercased()
        XCTAssertTrue(description.contains("noaa"))
        XCTAssertTrue(description.contains("supported"))
    }

    func testUnsupportedRegionErrorCanBePatternMatched() {
        let error: Error = TideError.unsupportedRegion
        guard let tideError = error as? TideError,
              case .unsupportedRegion = tideError else {
            return XCTFail("Expected TideError.unsupportedRegion")
        }
    }

    func testNoDataErrorIncludesContext() {
        let error = TideError.noData("station offline")
        XCTAssertEqual(error.errorDescription, "No tide data available: station offline")
    }

    func testWidgetDataAvailability_SaveAndLoadNOAAStation() {
        let station = TideStation(
            id: "widget-test-\(UUID().uuidString)",
            name: "Widget Test Station",
            latitude: 37,
            longitude: -122,
            dataSource: .noaa
        )
        TideCache.saveLastStation(station)
        defer { UserDefaults(suiteName: "group.com.tideengine")?.removeObject(forKey: "lastStation") }

        let loaded = TideCache.loadLastStation()
        XCTAssertEqual(loaded?.id, station.id)
        XCTAssertEqual(loaded?.name, station.name)
        XCTAssertEqual(loaded?.latitude ?? 0, station.latitude, accuracy: 0.0001)
        XCTAssertEqual(loaded?.longitude ?? 0, station.longitude, accuracy: 0.0001)
        XCTAssertEqual(loaded?.dataSource, .noaa)
    }

    func testTidePrediction_HighAndLow() {
        let station = TideStation(id: "test", name: "Test", latitude: 0, longitude: 0, dataSource: .noaa)
        let high = TidePrediction(timestamp: .now, heightMeters: 1.5, type: .high, station: station)
        let low = TidePrediction(timestamp: .now.addingTimeInterval(3600), heightMeters: 0.3, type: .low, station: station)

        XCTAssertEqual(high.type, .high)
        XCTAssertEqual(high.heightMeters, 1.5)
        XCTAssertEqual(low.type, .low)
        XCTAssertEqual(low.heightMeters, 0.3)
    }

    func testTidePrediction_RoundTripCoding() throws {
        let station = TideStation(id: "encode-test", name: "Encode Test", latitude: 37.8, longitude: -122.5, dataSource: .noaa)
        let prediction = TidePrediction(
            timestamp: Date(timeIntervalSince1970: 1_711_108_800),
            heightMeters: 2.1,
            type: .high,
            station: station
        )

        let decoded = try JSONDecoder().decode(TidePrediction.self, from: JSONEncoder().encode(prediction))
        XCTAssertEqual(decoded.heightMeters, prediction.heightMeters, accuracy: 0.0001)
        XCTAssertEqual(decoded.type, prediction.type)
        XCTAssertEqual(decoded.station.id, prediction.station.id)
        XCTAssertEqual(decoded.timestamp.timeIntervalSince1970, prediction.timestamp.timeIntervalSince1970, accuracy: 0.001)
    }
}
