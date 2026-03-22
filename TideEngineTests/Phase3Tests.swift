import XCTest
@testable import TideEngine

final class Phase3Tests: XCTestCase {

    // MARK: - WorldTides Response Parsing

    func testParseWorldTidesResponse_ValidExtremes() throws {
        let json = """
        {
            "status": 200,
            "extremes": [
                {"dt": 1711108800, "height": 1.5, "type": "High"},
                {"dt": 1711130400, "height": 0.3, "type": "Low"},
                {"dt": 1711152000, "height": 1.8, "type": "High"},
                {"dt": 1711173600, "height": 0.1, "type": "Low"}
            ]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(WorldTidesResponse.self, from: json)
        XCTAssertEqual(decoded.status, 200)
        XCTAssertEqual(decoded.extremes?.count, 4)
        XCTAssertNil(decoded.error)

        let first = try XCTUnwrap(decoded.extremes?.first)
        XCTAssertEqual(first.type, "High")
        XCTAssertEqual(first.height, 1.5)
    }

    func testParseWorldTidesResponse_ErrorStatus() throws {
        let json = """
        {"status": 400, "error": "Invalid API key"}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(WorldTidesResponse.self, from: json)
        XCTAssertEqual(decoded.status, 400)
        XCTAssertEqual(decoded.error, "Invalid API key")
        XCTAssertNil(decoded.extremes)
    }

    func testWorldTidesTypeValues_HighAndLow() {
        // WorldTides uses "High"/"Low" strings — verify the raw response model stores them verbatim
        let extreme = WorldTidesExtreme(dt: 1711108800, height: 1.5, type: "High")
        XCTAssertEqual(extreme.type, "High")

        let extremeLow = WorldTidesExtreme(dt: 1711130400, height: 0.3, type: "Low")
        XCTAssertEqual(extremeLow.type, "Low")
    }

    func testWorldTidesTimestampConversion() {
        let dt = 1711108800  // 2024-03-22 12:00:00 UTC
        let date = Date(timeIntervalSince1970: TimeInterval(dt))
        XCTAssertNotNil(date)
        // Verify it's a reasonable date (2024)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let year = calendar.component(.year, from: date)
        XCTAssertEqual(year, 2024)
    }

    func testParseWorldTidesResponse_EmptyExtremes() throws {
        let json = """
        {"status": 200, "extremes": []}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(WorldTidesResponse.self, from: json)
        XCTAssertEqual(decoded.status, 200)
        XCTAssertEqual(decoded.extremes?.count, 0)
        XCTAssertNil(decoded.error)
    }

    // MARK: - Keychain

    func testKeychainSaveAndLoad() throws {
        let testKey = "test-worldtides-key-\(UUID().uuidString)"
        try KeychainHelper.saveWorldTidesKey(testKey)
        let loaded = KeychainHelper.loadWorldTidesKey()
        XCTAssertEqual(loaded, testKey)
        // Cleanup
        KeychainHelper.deleteWorldTidesKey()
    }

    func testKeychainDelete() throws {
        try KeychainHelper.saveWorldTidesKey("temp-key")
        KeychainHelper.deleteWorldTidesKey()
        let loaded = KeychainHelper.loadWorldTidesKey()
        XCTAssertNil(loaded)
    }

    func testKeychainLoadMissing() {
        // Ensure clean state
        KeychainHelper.deleteWorldTidesKey()
        let loaded = KeychainHelper.loadWorldTidesKey()
        XCTAssertNil(loaded)
    }

    func testKeychainOverwrite() throws {
        // Saving a second key should overwrite, not error
        try KeychainHelper.saveWorldTidesKey("first-key")
        try KeychainHelper.saveWorldTidesKey("second-key")
        let loaded = KeychainHelper.loadWorldTidesKey()
        XCTAssertEqual(loaded, "second-key")
        // Cleanup
        KeychainHelper.deleteWorldTidesKey()
    }

    // MARK: - StoreManager / UserDefaults unlock state

    func testStoreManagerInitialState_DefaultsToFalse() {
        // Without a stored value, unlock should default to false
        let suite = UserDefaults(suiteName: "group.com.tideengine")!
        suite.removeObject(forKey: "internationalUnlocked")
        XCTAssertFalse(suite.bool(forKey: "internationalUnlocked"))
    }

    func testUnlockPersistsToAppGroup() {
        let suite = UserDefaults(suiteName: "group.com.tideengine")!
        suite.set(true, forKey: "internationalUnlocked")
        XCTAssertTrue(suite.bool(forKey: "internationalUnlocked"))
        // Cleanup
        suite.removeObject(forKey: "internationalUnlocked")
    }

    func testUnlockDefaultsAfterRemoval() {
        let suite = UserDefaults(suiteName: "group.com.tideengine")!
        suite.set(true, forKey: "internationalUnlocked")
        suite.removeObject(forKey: "internationalUnlocked")
        XCTAssertFalse(suite.bool(forKey: "internationalUnlocked"))
    }

    // MARK: - TideDataService Routing

    func testHaversineDistance_SFisCloseToUS() {
        // SF to NOAA Golden Gate station should be well within 200km
        let sf = (lat: 37.7749, lon: -122.4194)
        let station = (lat: 37.806305, lon: -122.465889)  // SF Golden Gate NOAA
        let distance = NOAAClient.haversineDistance(
            lat1: sf.lat, lon1: sf.lon,
            lat2: station.lat, lon2: station.lon
        )
        XCTAssertLessThan(distance, 200.0, "SF should be within 200km of NOAA station, got \(distance) km")
    }

    func testHaversineDistance_TokyoIsFarFromUS() {
        // Tokyo to nearest US NOAA station should be far outside 200km
        let tokyo = (lat: 35.6762, lon: 139.6503)
        let sfStation = (lat: 37.806305, lon: -122.465889)  // SF NOAA — closest major US station
        let distance = NOAAClient.haversineDistance(
            lat1: tokyo.lat, lon1: tokyo.lon,
            lat2: sfStation.lat, lon2: sfStation.lon
        )
        XCTAssertGreaterThan(distance, 200.0, "Tokyo should be >200km from any US NOAA station, got \(distance) km")
    }

    // MARK: - TideError cases

    func testTideErrorInternationalLocked_HasDescription() {
        let error = TideError.internationalLocked
        let description = error.errorDescription
        XCTAssertNotNil(description)
        let desc = description!.lowercased()
        XCTAssertTrue(
            desc.contains("unlock") || desc.contains("international"),
            "Error description should mention international or unlock, got: \(description!)"
        )
    }

    func testTideErrorPatternMatching() {
        let error: Error = TideError.internationalLocked
        var caughtLocked = false
        if let tideError = error as? TideError, case .internationalLocked = tideError {
            caughtLocked = true
        }
        XCTAssertTrue(caughtLocked, "TideError.internationalLocked should be matchable via pattern matching")
    }

    func testTideErrorNoData_HasDescription() {
        let error = TideError.noData("station offline")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("station offline"))
    }

    // MARK: - TideCache widget data availability

    func testWidgetDataAvailability_SaveAndLoad() {
        let station = TideStation(
            id: "widget-test-\(UUID().uuidString)",
            name: "Widget Test Station",
            latitude: 37.0,
            longitude: -122.0,
            dataSource: .noaa
        )
        TideCache.saveLastStation(station)
        let loaded = TideCache.loadLastStation()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.id, station.id)
        XCTAssertEqual(loaded?.name, "Widget Test Station")
        if let lat = loaded?.latitude {
            XCTAssertEqual(lat, 37.0, accuracy: 0.0001)
        }
        if let lon = loaded?.longitude {
            XCTAssertEqual(lon, -122.0, accuracy: 0.0001)
        }
        XCTAssertEqual(loaded?.dataSource, .noaa)
        // Cleanup
        let suite = UserDefaults(suiteName: "group.com.tideengine")!
        suite.removeObject(forKey: "lastStation")
    }

    func testWidgetDataAvailability_WorldTidesStation() {
        let station = TideStation(
            id: "wt-51.5-0.1",
            name: "Thames Estuary",
            latitude: 51.5,
            longitude: 0.1,
            dataSource: .worldTides
        )
        TideCache.saveLastStation(station)
        let loaded = TideCache.loadLastStation()
        XCTAssertEqual(loaded?.dataSource, .worldTides)
        XCTAssertEqual(loaded?.id, "wt-51.5-0.1")
        // Cleanup
        let suite = UserDefaults(suiteName: "group.com.tideengine")!
        suite.removeObject(forKey: "lastStation")
    }

    // MARK: - TidePrediction model

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
        let now = Date(timeIntervalSince1970: 1711108800)  // fixed date for determinism
        let prediction = TidePrediction(timestamp: now, heightMeters: 2.1, type: .high, station: station)

        let encoded = try JSONEncoder().encode(prediction)
        let decoded = try JSONDecoder().decode(TidePrediction.self, from: encoded)

        XCTAssertEqual(decoded.heightMeters, prediction.heightMeters, accuracy: 0.0001)
        XCTAssertEqual(decoded.type, prediction.type)
        XCTAssertEqual(decoded.station.id, prediction.station.id)
        XCTAssertEqual(decoded.timestamp.timeIntervalSince1970,
                       prediction.timestamp.timeIntervalSince1970,
                       accuracy: 0.001)
    }
}
