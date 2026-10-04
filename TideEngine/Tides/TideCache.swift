import Foundation

struct TideCache {
    private static var suite: UserDefaults { UserDefaults(suiteName: "group.com.tideengine.TideEngine") ?? .standard }
    private static var standard: UserDefaults { .standard }

    // MARK: - Predictions (App Group — widget-accessible)

    // v1 dates were parsed from station-local strings in the device zone. Never reuse them.
    private static func predictionKey(stationId: String) -> String {
        "tideCache-v2-gmt-\(stationId)"
    }

    static func loadPredictions(stationId: String) -> CachedTideData? {
#if DEBUG
        if AppStoreScreenshot.number != nil {
            return stationId == AppStoreScreenshot.station.id ? AppStoreScreenshot.predictions : nil
        }
#endif
        guard let data = suite.data(forKey: predictionKey(stationId: stationId)) else { return nil }
        guard let cached = try? JSONDecoder().decode(CachedTideData.self, from: data) else { return nil }
        guard cached.expiresAt > Date.now else { return nil }
        return cached
    }

    static func loadStalePredictions(stationId: String) -> CachedTideData? {
#if DEBUG
        if AppStoreScreenshot.number != nil {
            return loadPredictions(stationId: stationId)
        }
#endif
        // Returns even expired data for fallback
        guard let data = suite.data(forKey: predictionKey(stationId: stationId)) else { return nil }
        return try? JSONDecoder().decode(CachedTideData.self, from: data)
    }

    static func savePredictions(_ data: CachedTideData) {
#if DEBUG
        if AppStoreScreenshot.number != nil { return }
#endif
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        suite.set(encoded, forKey: predictionKey(stationId: data.stationId))
    }

    // MARK: - Last Station (App Group — widget reads)

    static func saveLastStation(_ station: TideStation) {
#if DEBUG
        if AppStoreScreenshot.number != nil { return }
#endif
        guard let data = try? JSONEncoder().encode(station) else { return }
        suite.set(data, forKey: "lastStation")
    }

    static func loadLastStation() -> TideStation? {
#if DEBUG
        if AppStoreScreenshot.number != nil { return AppStoreScreenshot.station }
#endif
        guard let data = suite.data(forKey: "lastStation") else { return nil }
        return try? JSONDecoder().decode(TideStation.self, from: data)
    }

    // MARK: - Station List (standard UserDefaults — not needed by widget)

    static func loadStationList() -> [NOAAStationEntry]? {
#if DEBUG
        if AppStoreScreenshot.number != nil { return AppStoreScreenshot.stations }
#endif
        guard let cachedAt = standard.object(forKey: "noaaStationListCachedAt") as? Date else { return nil }
        // 30-day expiry
        guard cachedAt.addingTimeInterval(30 * 86400) > Date.now else { return nil }
        guard let data = standard.data(forKey: "noaaStationList") else { return nil }
        return try? JSONDecoder().decode([NOAAStationEntry].self, from: data)
    }

    static func saveStationList(_ stations: [NOAAStationEntry]) {
#if DEBUG
        if AppStoreScreenshot.number != nil { return }
#endif
        guard let data = try? JSONEncoder().encode(stations) else { return }
        standard.set(data, forKey: "noaaStationList")
        standard.set(Date.now, forKey: "noaaStationListCachedAt")
    }
}

#if DEBUG
/// Immutable, in-memory cache overlay. Never writes fixtures into the user's or widget's cache.
enum AppStoreScreenshot {
    static let number: Int? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-AppStoreScreenshot"),
              arguments.indices.contains(index + 1),
              let number = Int(arguments[index + 1]), (1...3).contains(number) else { return nil }
        return number
    }()

    // 2026-03-22 00:10 UTC, matching TideAPITests' date and San Francisco fixtures.
    static let date = Date(timeIntervalSince1970: 1_774_138_200)
    static let station = TideStation(
        id: "9414290", name: "SAN FRANCISCO", latitude: 37.806305,
        longitude: -122.465889, dataSource: .noaa
    )
    static let stations = [NOAAStationEntry(
        id: station.id, name: station.name, lat: station.latitude, lng: station.longitude, type: "R"
    )]

    static let predictions: CachedTideData = {
        let midnight = date.addingTimeInterval(-600)
        // Reuse the four TideAPITests hi/lo values, repeating them for seven days.
        // This is a synthetic fixture, not a retained seven-day NOAA response.
        let daily: [(Int, Double, TideType)] = [
            (120, 1.883, .high), (514, -0.14, .low),
            (935, 1.335, .high), (1215, 0.699, .low)
        ]
        let anchors = (-1...7).flatMap { day in
            daily.map { minute, height, type in
                TidePrediction(
                    timestamp: midnight.addingTimeInterval(Double(day * 86400 + minute * 60)),
                    heightMeters: height, type: type, station: station
                )
            }
        }
        let initialHours = [1.575, 1.798, 1.883, 1.820] // TideAPITests hourly fixture
        let curve = (0..<168).map { hour in
            let timestamp = midnight.addingTimeInterval(Double(hour * 3600))
            let upper = anchors.firstIndex { $0.timestamp > timestamp }!
            let left = anchors[upper - 1]
            let right = anchors[upper]
            let fraction = timestamp.timeIntervalSince(left.timestamp)
                / right.timestamp.timeIntervalSince(left.timestamp)
            let weight = (1 - cos(.pi * fraction)) / 2
            let height = hour < initialHours.count ? initialHours[hour]
                : left.heightMeters + (right.heightMeters - left.heightMeters) * weight
            return TideDataPoint(timestamp: timestamp, heightMeters: height)
        }
        return CachedTideData(
            stationId: station.id, stationName: station.name,
            predictions: anchors.filter {
                $0.timestamp >= midnight && $0.timestamp < midnight.addingTimeInterval(7 * 86400)
            },
            hourlyCurve: curve, fetchedAt: date.addingTimeInterval(-3600),
            expiresAt: date.addingTimeInterval(86400)
        )
    }()
}
#endif
