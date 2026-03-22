import Foundation
import CoreLocation

actor WorldTidesClient {
    static let shared = WorldTidesClient()
    private let session = URLSession.shared
    private static let baseURL = "https://www.worldtides.info/api/v3"

    /// Fetch 7-day tide extremes (high/low) for a coordinate.
    /// WorldTides only provides extremes — no hourly data.
    func fetchPredictions(coordinate: CLLocationCoordinate2D) async throws -> [TidePrediction] {
        guard let apiKey = KeychainHelper.loadWorldTidesKey() else {
            throw TideError.networkError("WorldTides API key not configured")
        }

        // length=604800 = 7 days in seconds
        let urlString = "\(Self.baseURL)?extremes&lat=\(coordinate.latitude)&lon=\(coordinate.longitude)&length=604800&key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw TideError.networkError("Invalid WorldTides URL")
        }

        #if DEBUG
        print("[WorldTides] Fetching for \(coordinate.latitude), \(coordinate.longitude)")
        // NOTE: Never log the full URL (contains API key)
        #endif

        let data: Data
        do {
            let (responseData, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw TideError.networkError("HTTP error from WorldTides API")
            }
            data = responseData
        } catch let error as TideError {
            throw error
        } catch {
            throw TideError.networkError(error.localizedDescription)
        }

        let decoded: WorldTidesResponse
        do {
            decoded = try JSONDecoder().decode(WorldTidesResponse.self, from: data)
        } catch {
            throw TideError.parseError("Failed to decode WorldTides response: \(error.localizedDescription)")
        }

        // Check API-level error
        if decoded.status != 200 {
            throw TideError.noData(decoded.error ?? "WorldTides API error (status \(decoded.status))")
        }

        guard let extremes = decoded.extremes, !extremes.isEmpty else {
            throw TideError.noData("No tide extremes returned from WorldTides")
        }

        // Create a virtual station from the coordinate
        let station = TideStation(
            id: "wt-\(coordinate.latitude)-\(coordinate.longitude)",
            name: "WorldTides (\(String(format: "%.1f", coordinate.latitude))°, \(String(format: "%.1f", coordinate.longitude))°)",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            dataSource: .worldTides
        )

        return extremes.compactMap { extreme in
            let tideType: TideType
            switch extreme.type {
            case "High": tideType = .high
            case "Low": tideType = .low
            default: return nil
            }
            return TidePrediction(
                timestamp: Date(timeIntervalSince1970: TimeInterval(extreme.dt)),
                heightMeters: extreme.height,
                type: tideType,
                station: station
            )
        }
    }
}
