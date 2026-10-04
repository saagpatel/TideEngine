import XCTest
@testable import TideEngine

final class TideAPITests: XCTestCase {

    // MARK: - Fixtures

    private let hiLoJSON = """
    {
      "predictions": [
        {"t":"2026-03-22 02:00", "v":"1.883", "type":"H"},
        {"t":"2026-03-22 08:34", "v":"-0.14", "type":"L"},
        {"t":"2026-03-22 15:35", "v":"1.335", "type":"H"},
        {"t":"2026-03-22 20:15", "v":"0.699", "type":"L"}
      ]
    }
    """

    private let hiLoErrorJSON = """
    {
      "error": {"message": "No data was found. This product may not be offered at this station."}
    }
    """

    private let hourlyJSON = """
    {
      "predictions": [
        {"t":"2026-03-22 00:00", "v":"1.575"},
        {"t":"2026-03-22 01:00", "v":"1.798"},
        {"t":"2026-03-22 02:00", "v":"1.883"},
        {"t":"2026-03-22 03:00", "v":"1.820"}
      ]
    }
    """

    private let stationsJSON = """
    {
      "count": 4,
      "stations": [
        {"id":"9414290","name":"SAN FRANCISCO","lat":37.806305,"lng":-122.465889,"type":"R","state":"CA","timezonecorr":"-8"},
        {"id":"9410660","name":"LOS ANGELES","lat":33.720,"lng":-118.272,"type":"R","state":"CA","timezonecorr":"-8"},
        {"id":"9999999","name":"SUBORDINATE STATION","lat":35.0,"lng":-120.0,"type":"S","state":"CA","timezonecorr":"-8"},
        {"id":"9413450","name":"MONTEREY","lat":36.605,"lng":-121.888,"type":"R","state":"CA","timezonecorr":"-8"}
      ]
    }
    """

    // MARK: - Hi/Lo Response Parsing

    func testHiLoResponseParsing_ValidResponse() throws {
        let data = Data(hiLoJSON.utf8)
        let decoded = try JSONDecoder().decode(NOAAHiLoResponse.self, from: data)

        XCTAssertNil(decoded.error)
        XCTAssertNotNil(decoded.predictions)
        XCTAssertEqual(decoded.predictions?.count, 4)
    }

    func testHiLoResponseParsing_FieldValues() throws {
        let data = Data(hiLoJSON.utf8)
        let decoded = try JSONDecoder().decode(NOAAHiLoResponse.self, from: data)

        let first = try XCTUnwrap(decoded.predictions?.first)
        XCTAssertEqual(first.t, "2026-03-22 02:00")
        XCTAssertEqual(first.v, "1.883")
        XCTAssertEqual(first.type, "H")

        let second = try XCTUnwrap(decoded.predictions?[1])
        XCTAssertEqual(second.type, "L")
        XCTAssertEqual(second.v, "-0.14")
    }

    func testHiLoResponseParsing_ErrorResponse() throws {
        let data = Data(hiLoErrorJSON.utf8)
        let decoded = try JSONDecoder().decode(NOAAHiLoResponse.self, from: data)

        XCTAssertNil(decoded.predictions)
        XCTAssertNotNil(decoded.error)
        XCTAssertTrue(decoded.error!.message.contains("No data was found"))
    }

    // MARK: - Hourly Response Parsing

    func testHourlyResponseParsing_ValidResponse() throws {
        let data = Data(hourlyJSON.utf8)
        let decoded = try JSONDecoder().decode(NOAAHourlyResponse.self, from: data)

        XCTAssertNil(decoded.error)
        XCTAssertNotNil(decoded.predictions)
        XCTAssertEqual(decoded.predictions?.count, 4)
    }

    func testHourlyResponseParsing_NoTypeField() throws {
        // Hourly predictions must decode even without a "type" field
        let data = Data(hourlyJSON.utf8)
        let decoded = try JSONDecoder().decode(NOAAHourlyResponse.self, from: data)

        let point = try XCTUnwrap(decoded.predictions?.first)
        XCTAssertEqual(point.t, "2026-03-22 00:00")
        XCTAssertEqual(point.v, "1.575")
    }

    func testHourlyResponseParsing_HeightValues() throws {
        let data = Data(hourlyJSON.utf8)
        let decoded = try JSONDecoder().decode(NOAAHourlyResponse.self, from: data)

        let heights = decoded.predictions?.compactMap { Double($0.v) } ?? []
        XCTAssertEqual(heights.count, 4)
        XCTAssertEqual(heights[0], 1.575, accuracy: 0.001)
        XCTAssertEqual(heights[1], 1.798, accuracy: 0.001)
    }

    // MARK: - Station List Parsing and Filtering

    func testStationListParsing_DecodesAllEntries() throws {
        let data = Data(stationsJSON.utf8)
        let decoded = try JSONDecoder().decode(NOAAStationsResponse.self, from: data)

        XCTAssertEqual(decoded.stations.count, 4)
    }

    func testStationListParsing_TypeRFilter() throws {
        let data = Data(stationsJSON.utf8)
        let decoded = try JSONDecoder().decode(NOAAStationsResponse.self, from: data)

        let harmonic = decoded.stations.filter { $0.type == "R" }
        XCTAssertEqual(harmonic.count, 3, "Should filter out the type==S subordinate station")
        XCTAssertTrue(harmonic.allSatisfy { $0.type == "R" })
    }

    func testStationListParsing_FieldValues() throws {
        let data = Data(stationsJSON.utf8)
        let decoded = try JSONDecoder().decode(NOAAStationsResponse.self, from: data)

        let sf = try XCTUnwrap(decoded.stations.first { $0.id == "9414290" })
        XCTAssertEqual(sf.name, "SAN FRANCISCO")
        XCTAssertEqual(sf.lat, 37.806305, accuracy: 0.0001)
        XCTAssertEqual(sf.lng, -122.465889, accuracy: 0.0001)
        XCTAssertEqual(sf.type, "R")
    }

    // MARK: - Haversine Distance

    func testHaversine_SFtoLA() {
        // San Francisco (37.7749, -122.4194) to Los Angeles (34.0522, -118.2437) ≈ 559 km
        let dist = NOAAClient.haversineDistance(
            lat1: 37.7749, lon1: -122.4194,
            lat2: 34.0522, lon2: -118.2437
        )
        XCTAssertEqual(dist, 559.0, accuracy: 10.0,
                       "SF→LA should be approximately 559 km, got \(dist) km")
    }

    func testHaversine_SamePoint() {
        let dist = NOAAClient.haversineDistance(
            lat1: 37.7749, lon1: -122.4194,
            lat2: 37.7749, lon2: -122.4194
        )
        XCTAssertEqual(dist, 0.0, accuracy: 0.001,
                       "Distance from a point to itself should be 0")
    }

    func testHaversine_AntipodalPoints() {
        // North Pole → South Pole: ≈ 20,015 km (half Earth circumference)
        let dist = NOAAClient.haversineDistance(
            lat1: 90.0, lon1: 0.0,
            lat2: -90.0, lon2: 0.0
        )
        XCTAssertEqual(dist, 20015.0, accuracy: 50.0,
                       "Antipodal distance should be ~20,015 km, got \(dist) km")
    }

    // MARK: - Date Formatting

    func testNOAATimestampsAndRequestDatesUseUTCRegardlessOfDeviceZone() throws {
        let originalZone = NSTimeZone.default
        defer { NSTimeZone.default = originalZone }
        // 2026-03-22 00:10 UTC is still March 21 in California.
        let expected = Date(timeIntervalSince1970: 1_774_138_200)
        XCTAssertEqual(TideDateFormatter.noaa.timeZone.secondsFromGMT(for: expected), 0)

        for identifier in ["America/Los_Angeles", "Asia/Tokyo", "UTC"] {
            NSTimeZone.default = try XCTUnwrap(TimeZone(identifier: identifier))
            let parsed = try XCTUnwrap(TideDateFormatter.noaa.date(from: "2026-03-22 00:10"))
            XCTAssertEqual(parsed, expected, identifier)
            XCTAssertEqual(NOAAClient.beginDateString(from: expected), "20260322", identifier)
        }
    }

    func testBothPredictionRequestsSpecifyGMT() throws {
        for interval in ["hilo", "h"] {
            let url = try NOAAClient.predictionsURL(
                stationID: "9414290", beginDate: "20260322", interval: interval
            )
            let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
            XCTAssertEqual(items.first(where: { $0.name == "time_zone" })?.value, "gmt")
            XCTAssertEqual(items.first(where: { $0.name == "interval" })?.value, interval)
        }
    }

    func testUpcomingFilteringAcrossUTCMidnight() throws {
        let station = TideStation(id: "test", name: "Test", latitude: 0, longitude: 0, dataSource: .noaa)
        let timestamps = try ["2026-03-21 23:55", "2026-03-22 00:00", "2026-03-22 00:10"].map {
            try XCTUnwrap(TideDateFormatter.noaa.date(from: $0))
        }
        let predictions = timestamps.map {
            TidePrediction(timestamp: $0, heightMeters: 1, type: .high, station: station)
        }
        let beforeMidnight = try XCTUnwrap(TideDateFormatter.noaa.date(from: "2026-03-21 23:59"))
        XCTAssertEqual(TidePrediction.upcoming(in: predictions, after: beforeMidnight).map(\.timestamp),
                       Array(timestamps.suffix(2)))
        XCTAssertEqual(TidePrediction.upcoming(in: predictions, after: timestamps[1]).map(\.timestamp),
                       [timestamps[2]])
    }

    func testTideDateFormatter_ParsesNOAAFormat() {
        let parsed = TideDateFormatter.noaa.date(from: "2026-03-22 06:14")
        XCTAssertNotNil(parsed, "Should parse NOAA date string '2026-03-22 06:14'")
    }

    func testTideDateFormatter_RejectsInvalidFormat() {
        let parsed = TideDateFormatter.noaa.date(from: "not-a-date")
        XCTAssertNil(parsed, "Should return nil for invalid date string")
    }

    func testTideDateFormatter_ParsedDateIsReasonable() throws {
        let parsed = try XCTUnwrap(TideDateFormatter.noaa.date(from: "2026-03-22 06:14"))
        // The timestamp should be in 2026 — Unix epoch is 1970-01-01 and 2026 ≈ 56 years later
        let secondsSince1970 = parsed.timeIntervalSince1970
        XCTAssertGreaterThan(secondsSince1970, 1_700_000_000,
                             "Parsed date should be after 2023 (epoch > 1.7B)")
        XCTAssertLessThan(secondsSince1970, 1_800_000_000,
                          "Parsed date should be before 2027 (epoch < 1.8B)")
    }

    // MARK: - Cache Round-Trip

    func testLegacyStationLocalCacheIsIgnoredByBothLoaders() throws {
        let stationId = "TEST-LEGACY-\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: "group.com.tideengine.TideEngine"))
        let legacyKey = "tideCache-\(stationId)"
        let currentKey = "tideCache-v2-gmt-\(stationId)"
        defer {
            suite.removeObject(forKey: legacyKey)
            suite.removeObject(forKey: currentKey)
        }
        let now = Date.now
        let entry = CachedTideData(
            stationId: stationId, stationName: "Legacy", predictions: [], hourlyCurve: [],
            fetchedAt: now, expiresAt: now.addingTimeInterval(86400)
        )
        suite.set(try JSONEncoder().encode(entry), forKey: legacyKey)
        XCTAssertNil(TideCache.loadPredictions(stationId: stationId))
        XCTAssertNil(TideCache.loadStalePredictions(stationId: stationId))

        TideCache.savePredictions(entry)
        XCTAssertEqual(TideCache.loadPredictions(stationId: stationId)?.stationId, stationId)
        XCTAssertEqual(TideCache.loadStalePredictions(stationId: stationId)?.stationId, stationId)
    }

    func testCacheRoundTrip_SaveAndLoad() {
        let testStationId = "TEST-\(UUID().uuidString)"
        let station = TideStation(
            id: testStationId,
            name: "Test Station",
            latitude: 37.8,
            longitude: -122.5,
            dataSource: .noaa
        )
        let now = Date.now
        let entry = CachedTideData(
            stationId: testStationId,
            stationName: "Test Station",
            predictions: [],
            hourlyCurve: [],
            fetchedAt: now,
            expiresAt: now.addingTimeInterval(86400)
        )

        TideCache.savePredictions(entry)
        let loaded = TideCache.loadPredictions(stationId: testStationId)

        XCTAssertNotNil(loaded, "Should load back the saved cache entry")
        XCTAssertEqual(loaded?.stationId, testStationId)
        XCTAssertEqual(loaded?.stationName, "Test Station")
        _ = station  // used for setup
    }

    func testCacheExpiry_ExpiredEntryReturnsNil() {
        let testStationId = "TEST-EXPIRED-\(UUID().uuidString)"
        let past = Date.now.addingTimeInterval(-1)  // already expired
        let entry = CachedTideData(
            stationId: testStationId,
            stationName: "Expired Station",
            predictions: [],
            hourlyCurve: [],
            fetchedAt: Date.now.addingTimeInterval(-86401),
            expiresAt: past
        )

        TideCache.savePredictions(entry)
        let loaded = TideCache.loadPredictions(stationId: testStationId)

        XCTAssertNil(loaded, "loadPredictions should return nil for expired cache entry")
    }

    func testCacheExpiry_StaleLoadReturnsExpiredEntry() {
        let testStationId = "TEST-STALE-\(UUID().uuidString)"
        let past = Date.now.addingTimeInterval(-1)
        let entry = CachedTideData(
            stationId: testStationId,
            stationName: "Stale Station",
            predictions: [],
            hourlyCurve: [],
            fetchedAt: Date.now.addingTimeInterval(-86401),
            expiresAt: past
        )

        TideCache.savePredictions(entry)
        let stale = TideCache.loadStalePredictions(stationId: testStationId)

        XCTAssertNotNil(stale, "loadStalePredictions should return expired entries for fallback")
        XCTAssertEqual(stale?.stationId, testStationId)
    }
}
