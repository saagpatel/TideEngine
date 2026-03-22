import Foundation

// MARK: - Celestial Bodies

enum CelestialBody {
    case moon
    case sun
}

struct CelestialPosition {
    let body: CelestialBody
    let eclipticLongitude: Double   // degrees [0, 360)
    let eclipticLatitude: Double    // degrees [-90, 90]
    let distanceAU: Double          // astronomical units
    let timestamp: Date
}

// MARK: - Tidal Force

struct TidalForceField {
    let timestamp: Date
    /// Row-major [latitude][longitude], 64 cols × 32 rows
    /// latitude index 0 = -90°, 31 = +90° (step ~5.806°)
    /// longitude index 0 = 0°, 63 = 354.375° (step 5.625°)
    let heightField: [[Float]]      // values in [-1.0, 1.0]
    let maxDisplacementMeters: Double

    static let columns = 64
    static let rows = 32
}
