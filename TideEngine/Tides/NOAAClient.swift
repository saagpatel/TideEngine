import Foundation
import CoreLocation

actor NOAAClient {
    static let shared = NOAAClient()

    private let session: URLSession
    private static let baseURL = "https://api.tidesandcurrents.noaa.gov"

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Station Discovery

    func fetchNearestStation(coordinate: CLLocationCoordinate2D) async throws -> TideStation {
        let stations = try await fetchStationList()

        guard let nearest = stations.min(by: { a, b in
            let dA = Self.haversineDistance(lat1: coordinate.latitude, lon1: coordinate.longitude,
                                            lat2: a.lat, lon2: a.lng)
            let dB = Self.haversineDistance(lat1: coordinate.latitude, lon1: coordinate.longitude,
                                            lat2: b.lat, lon2: b.lng)
            return dA < dB
        }) else {
            throw TideError.noStationFound
        }

        return TideStation(
            id: nearest.id,
            name: nearest.name,
            latitude: nearest.lat,
            longitude: nearest.lng,
            dataSource: .noaa
        )
    }

    private func fetchStationList() async throws -> [NOAAStationEntry] {
        // Try cache first
        if let cached = TideCache.loadStationList() {
            return cached
        }

        let urlString = "\(Self.baseURL)/mdapi/prod/webapi/stations.json?type=tidepredictions&units=english"
        guard let url = URL(string: urlString) else {
            throw TideError.networkError("Invalid station list URL")
        }

        let data: Data
        do {
            let (responseData, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                throw TideError.networkError("HTTP error fetching station list")
            }
            data = responseData
        } catch let error as TideError {
            throw error
        } catch {
            throw TideError.networkError(error.localizedDescription)
        }

        let decoded: NOAAStationsResponse
        do {
            decoded = try JSONDecoder().decode(NOAAStationsResponse.self, from: data)
        } catch {
            throw TideError.parseError("Failed to decode station list: \(error.localizedDescription)")
        }

        // Filter to harmonic/reference stations only
        let harmonicStations = decoded.stations.filter { $0.type == "R" }
        TideCache.saveStationList(harmonicStations)
        return harmonicStations
    }

    // MARK: - Hi/Lo Predictions

    func fetchHiLoPredictions(station: TideStation, startDate: Date) async throws -> [TidePrediction] {
        let beginDate = Self.beginDateString(from: startDate)
        let urlString = "\(Self.baseURL)/api/prod/datagetter?product=predictions&datum=MLLW&time_zone=lst_ldt&interval=hilo&units=metric&format=json&begin_date=\(beginDate)&range=168&station=\(station.id)"

        guard let url = URL(string: urlString) else {
            throw TideError.networkError("Invalid hi/lo predictions URL")
        }

        let data = try await fetchData(from: url)

        let decoded: NOAAHiLoResponse
        do {
            decoded = try JSONDecoder().decode(NOAAHiLoResponse.self, from: data)
        } catch {
            throw TideError.parseError("Failed to decode hi/lo response: \(error.localizedDescription)")
        }

        if let apiError = decoded.error {
            throw TideError.noData(apiError.message)
        }

        guard let rawPredictions = decoded.predictions, !rawPredictions.isEmpty else {
            throw TideError.noData("No hi/lo predictions returned for station \(station.id)")
        }

        return try rawPredictions.map { raw in
            guard let timestamp = TideDateFormatter.noaa.date(from: raw.t) else {
                throw TideError.parseError("Invalid timestamp format: \(raw.t)")
            }
            guard let height = Double(raw.v) else {
                throw TideError.parseError("Invalid height value: \(raw.v)")
            }
            guard let tideType = TideType(rawValue: raw.type) else {
                throw TideError.parseError("Unknown tide type: \(raw.type)")
            }
            return TidePrediction(
                timestamp: timestamp,
                heightMeters: height,
                type: tideType,
                station: station
            )
        }
    }

    // MARK: - Hourly Predictions

    func fetchHourlyPredictions(stationId: String, startDate: Date) async throws -> [TideDataPoint] {
        let beginDate = Self.beginDateString(from: startDate)
        let urlString = "\(Self.baseURL)/api/prod/datagetter?product=predictions&datum=MLLW&time_zone=lst_ldt&interval=h&units=metric&format=json&begin_date=\(beginDate)&range=168&station=\(stationId)"

        guard let url = URL(string: urlString) else {
            throw TideError.networkError("Invalid hourly predictions URL")
        }

        let data = try await fetchData(from: url)

        let decoded: NOAAHourlyResponse
        do {
            decoded = try JSONDecoder().decode(NOAAHourlyResponse.self, from: data)
        } catch {
            throw TideError.parseError("Failed to decode hourly response: \(error.localizedDescription)")
        }

        if let apiError = decoded.error {
            throw TideError.noData(apiError.message)
        }

        guard let rawPredictions = decoded.predictions, !rawPredictions.isEmpty else {
            throw TideError.noData("No hourly predictions returned for station \(stationId)")
        }

        return try rawPredictions.map { raw in
            guard let timestamp = TideDateFormatter.noaa.date(from: raw.t) else {
                throw TideError.parseError("Invalid timestamp format: \(raw.t)")
            }
            guard let height = Double(raw.v) else {
                throw TideError.parseError("Invalid height value: \(raw.v)")
            }
            return TideDataPoint(timestamp: timestamp, heightMeters: height)
        }
    }

    // MARK: - Helpers

    private func fetchData(from url: URL) async throws -> Data {
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                throw TideError.networkError("HTTP error from NOAA API")
            }
            return data
        } catch let error as TideError {
            throw error
        } catch {
            throw TideError.networkError(error.localizedDescription)
        }
    }

    static func beginDateString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    // MARK: - Haversine (static so tests can call without actor isolation)

    static func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = 6371.0  // km
        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLon = (lon2 - lon1) * .pi / 180.0
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180)
            * sin(dLon / 2) * sin(dLon / 2)
        return r * 2 * asin(sqrt(a))
    }
}
