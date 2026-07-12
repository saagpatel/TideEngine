import Foundation

struct TideCache {
    private static var suite: UserDefaults { UserDefaults(suiteName: "group.com.tideengine") ?? .standard }
    private static var standard: UserDefaults { .standard }

    // MARK: - Predictions (App Group — widget-accessible)

    static func loadPredictions(stationId: String) -> CachedTideData? {
        guard let data = suite.data(forKey: "tideCache-\(stationId)") else { return nil }
        guard let cached = try? JSONDecoder().decode(CachedTideData.self, from: data) else { return nil }
        guard cached.expiresAt > Date.now else { return nil }
        return cached
    }

    static func loadStalePredictions(stationId: String) -> CachedTideData? {
        // Returns even expired data for fallback
        guard let data = suite.data(forKey: "tideCache-\(stationId)") else { return nil }
        return try? JSONDecoder().decode(CachedTideData.self, from: data)
    }

    static func savePredictions(_ data: CachedTideData) {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        suite.set(encoded, forKey: "tideCache-\(data.stationId)")
    }

    // MARK: - Last Station (App Group — widget reads)

    static func saveLastStation(_ station: TideStation) {
        guard let data = try? JSONEncoder().encode(station) else { return }
        suite.set(data, forKey: "lastStation")
    }

    static func loadLastStation() -> TideStation? {
        guard let data = suite.data(forKey: "lastStation") else { return nil }
        return try? JSONDecoder().decode(TideStation.self, from: data)
    }

    // MARK: - Station List (standard UserDefaults — not needed by widget)

    static func loadStationList() -> [NOAAStationEntry]? {
        guard let cachedAt = standard.object(forKey: "noaaStationListCachedAt") as? Date else { return nil }
        // 30-day expiry
        guard cachedAt.addingTimeInterval(30 * 86400) > Date.now else { return nil }
        guard let data = standard.data(forKey: "noaaStationList") else { return nil }
        return try? JSONDecoder().decode([NOAAStationEntry].self, from: data)
    }

    static func saveStationList(_ stations: [NOAAStationEntry]) {
        guard let data = try? JSONEncoder().encode(stations) else { return }
        standard.set(data, forKey: "noaaStationList")
        standard.set(Date.now, forKey: "noaaStationListCachedAt")
    }
}
