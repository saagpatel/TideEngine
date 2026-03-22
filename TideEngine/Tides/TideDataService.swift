import Foundation
import CoreLocation

actor TideDataService {
    static let shared = TideDataService()

    struct TideResult: Sendable {
        let station: TideStation
        let predictions: [TidePrediction]
        let hourlyCurve: [TideDataPoint]
        let isFromCache: Bool
        let cachedAt: Date?
    }

    func loadTideData(for coordinate: CLLocationCoordinate2D) async throws -> TideResult {
        // 1. Find nearest NOAA station to determine US vs international
        let noaaStation = try await NOAAClient.shared.fetchNearestStation(coordinate: coordinate)
        let distance = NOAAClient.haversineDistance(
            lat1: coordinate.latitude, lon1: coordinate.longitude,
            lat2: noaaStation.latitude, lon2: noaaStation.longitude
        )

        // 2. Close to US station → use NOAA
        if distance < 200.0 {
            TideCache.saveLastStation(noaaStation)
            return try await loadNOAAData(station: noaaStation)
        }

        // 3. International — check unlock
        let suite = UserDefaults(suiteName: "group.com.tideengine")!
        guard suite.bool(forKey: "internationalUnlocked") else {
            throw TideError.internationalLocked
        }

        // 4. Fetch from WorldTides
        return try await loadWorldTidesData(coordinate: coordinate)
    }

    private func loadNOAAData(station: TideStation) async throws -> TideResult {
        // Check cache first
        if let cached = TideCache.loadPredictions(stationId: station.id) {
            return TideResult(
                station: station,
                predictions: cached.predictions,
                hourlyCurve: cached.hourlyCurve,
                isFromCache: true,
                cachedAt: cached.fetchedAt
            )
        }

        // Fetch both concurrently, fall back to stale cache on failure
        do {
            async let hiLo = NOAAClient.shared.fetchHiLoPredictions(station: station, startDate: .now)
            async let hourly = NOAAClient.shared.fetchHourlyPredictions(stationId: station.id, startDate: .now)

            let predictions = try await hiLo
            let curve = try await hourly

            let now = Date.now
            let cacheEntry = CachedTideData(
                stationId: station.id,
                stationName: station.name,
                predictions: predictions,
                hourlyCurve: curve,
                fetchedAt: now,
                expiresAt: now.addingTimeInterval(86400)
            )
            TideCache.savePredictions(cacheEntry)

            return TideResult(
                station: station,
                predictions: predictions,
                hourlyCurve: curve,
                isFromCache: false,
                cachedAt: nil
            )
        } catch {
            // Fallback to stale cache rather than surfacing an error if we have any data at all
            if let stale = TideCache.loadStalePredictions(stationId: station.id) {
                return TideResult(
                    station: station,
                    predictions: stale.predictions,
                    hourlyCurve: stale.hourlyCurve,
                    isFromCache: true,
                    cachedAt: stale.fetchedAt
                )
            }
            throw error
        }
    }

    private func loadWorldTidesData(coordinate: CLLocationCoordinate2D) async throws -> TideResult {
        let stationId = "wt-\(coordinate.latitude)-\(coordinate.longitude)"

        // Check cache first
        if let cached = TideCache.loadPredictions(stationId: stationId) {
            let station = TideStation(
                id: stationId,
                name: cached.stationName,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                dataSource: .worldTides
            )
            return TideResult(
                station: station,
                predictions: cached.predictions,
                hourlyCurve: cached.hourlyCurve,
                isFromCache: true,
                cachedAt: cached.fetchedAt
            )
        }

        // Fetch from WorldTides (extremes only — no hourly data available)
        let predictions = try await WorldTidesClient.shared.fetchPredictions(coordinate: coordinate)
        guard let firstPred = predictions.first else {
            throw TideError.noData("No predictions from WorldTides")
        }

        let station = firstPred.station
        TideCache.saveLastStation(station)

        let now = Date.now
        let cacheEntry = CachedTideData(
            stationId: station.id,
            stationName: station.name,
            predictions: predictions,
            hourlyCurve: [],  // WorldTides has no hourly
            fetchedAt: now,
            expiresAt: now.addingTimeInterval(86400)
        )
        TideCache.savePredictions(cacheEntry)

        return TideResult(
            station: station,
            predictions: predictions,
            hourlyCurve: [],
            isFromCache: false,
            cachedAt: nil
        )
    }
}
