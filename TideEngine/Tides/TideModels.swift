import Foundation

// MARK: - Domain Types

enum TideType: String, Codable, Sendable {
    case high = "H"
    case low = "L"
}

enum DataSource: String, Codable, Sendable {
    case noaa
}

struct TideStation: Codable, Sendable, Hashable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let dataSource: DataSource
}

struct TidePrediction: Codable, Sendable, Identifiable {
    let timestamp: Date
    let heightMeters: Double
    let type: TideType
    let station: TideStation

    var id: Date { timestamp }
}

struct TideDataPoint: Codable, Sendable, Identifiable {
    let timestamp: Date
    let heightMeters: Double

    var id: Date { timestamp }
}

struct CachedTideData: Codable, Sendable {
    let stationId: String
    let stationName: String
    let predictions: [TidePrediction]
    let hourlyCurve: [TideDataPoint]
    let fetchedAt: Date
    let expiresAt: Date  // fetchedAt + 86400
}

// MARK: - NOAA API Response Types

struct NOAAStationsResponse: Codable, Sendable {
    let stations: [NOAAStationEntry]
}

struct NOAAStationEntry: Codable, Sendable {
    let id: String
    let name: String
    let lat: Double
    let lng: Double
    let type: String  // "R" = reference/harmonic, "S" = subordinate

    enum CodingKeys: String, CodingKey {
        case id, name, lat, lng
        case type
    }
}

struct NOAAHiLoResponse: Codable, Sendable {
    let predictions: [NOAAHiLoPrediction]?
    let error: NOAAErrorBody?
}

struct NOAAHiLoPrediction: Codable, Sendable {
    let t: String     // "2026-03-22 06:14"
    let v: String     // "1.234"
    let type: String  // "H" or "L"
}

struct NOAAHourlyResponse: Codable, Sendable {
    let predictions: [NOAAHourlyPrediction]?
    let error: NOAAErrorBody?
}

struct NOAAHourlyPrediction: Codable, Sendable {
    let t: String  // "2026-03-22 00:00"
    let v: String  // "1.575"
}

struct NOAAErrorBody: Codable, Sendable {
    let message: String
}

// MARK: - Errors

enum TideError: Error, LocalizedError, Sendable {
    case noStationFound
    case noData(String)
    case networkError(String)
    case parseError(String)
    case unsupportedRegion

    var errorDescription: String? {
        switch self {
        case .noStationFound: return "No tide station found nearby"
        case .noData(let msg): return "No tide data available: \(msg)"
        case .networkError(let msg): return "Network error: \(msg)"
        case .parseError(let msg): return "Data parsing error: \(msg)"
        case .unsupportedRegion: return "NOAA tide predictions are currently available near supported U.S. stations only"
        }
    }
}

// MARK: - Date Formatting

enum TideDateFormatter {
    /// NOAA date format: "2026-03-22 06:14"
    static let noaa: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
