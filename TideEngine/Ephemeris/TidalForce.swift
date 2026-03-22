import Foundation

// MARK: - TidalForce
// Computes the equilibrium tidal displacement heightfield (32 rows × 64 cols)
// from Moon and Sun positions computed by Ephemeris.

struct TidalForce {

    // Equilibrium tidal amplitude constants (metres)
    private static let aMoon = 0.54
    private static let aSun  = 0.25

    // Grid dimensions (must match TidalForceField constants)
    private static let rows = TidalForceField.rows       // 32
    private static let cols = TidalForceField.columns    // 64

    static func computeHeightField(
        moon: CelestialPosition,
        sun: CelestialPosition
    ) -> TidalForceField {
        // Use the Moon's timestamp (both bodies share the same instant)
        let date = moon.timestamp

        // GMST (degrees)
        let gmst = Ephemeris.gmstDegrees(at: date)

        // Convert Moon ecliptic → equatorial → sub-body geographic point
        let moonSubPoint = subBodyPoint(
            eclipticLon: moon.eclipticLongitude,
            eclipticLat: moon.eclipticLatitude,
            gmst: gmst
        )

        // Convert Sun ecliptic → equatorial → sub-body geographic point
        let sunSubPoint = subBodyPoint(
            eclipticLon: sun.eclipticLongitude,
            eclipticLat: sun.eclipticLatitude,
            gmst: gmst
        )

        let moonSubLatRad = moonSubPoint.lat * .pi / 180.0
        let moonSubLonRad = moonSubPoint.lon * .pi / 180.0
        let sunSubLatRad  = sunSubPoint.lat  * .pi / 180.0
        let sunSubLonRad  = sunSubPoint.lon  * .pi / 180.0

        // Build the raw displacement grid
        var rawGrid = [[Double]](
            repeating: [Double](repeating: 0.0, count: cols),
            count: rows
        )

        var globalMin = Double.greatestFiniteMagnitude
        var globalMax = -Double.greatestFiniteMagnitude

        for row in 0 ..< rows {
            // latitude index 0 = -90°, 31 = +90°
            let gridLatDeg = -90.0 + Double(row) * (180.0 / Double(rows - 1))
            let gridLatRad = gridLatDeg * .pi / 180.0

            for col in 0 ..< cols {
                let gridLonDeg = Double(col) * (360.0 / Double(cols))
                let gridLonRad = gridLonDeg * .pi / 180.0

                // cos(θ) between grid point and Moon's sub-body point
                let cosMoon = sin(gridLatRad) * sin(moonSubLatRad)
                           + cos(gridLatRad) * cos(moonSubLatRad) * cos(gridLonRad - moonSubLonRad)
                // cos(θ) between grid point and Sun's sub-body point
                let cosSun  = sin(gridLatRad) * sin(sunSubLatRad)
                           + cos(gridLatRad) * cos(sunSubLatRad)  * cos(gridLonRad - sunSubLonRad)

                // Equilibrium tidal displacement: A * (3·cos²θ - 1)
                let d = aMoon * (3.0 * cosMoon * cosMoon - 1.0)
                      + aSun  * (3.0 * cosSun  * cosSun  - 1.0)

                rawGrid[row][col] = d
                if d < globalMin { globalMin = d }
                if d > globalMax { globalMax = d }
            }
        }

        // Normalize to [-1, 1] by mapping to the largest absolute extremum
        let scale = max(abs(globalMin), abs(globalMax))
        let safeScale = scale > 0 ? scale : 1.0

        var floatGrid = [[Float]](
            repeating: [Float](repeating: 0.0, count: cols),
            count: rows
        )
        for row in 0 ..< rows {
            for col in 0 ..< cols {
                floatGrid[row][col] = Float(rawGrid[row][col] / safeScale)
            }
        }

        return TidalForceField(
            timestamp: date,
            heightField: floatGrid,
            maxDisplacementMeters: scale
        )
    }

    // MARK: - Coordinate transforms

    private struct GeographicPoint {
        let lat: Double  // degrees
        let lon: Double  // degrees
    }

    /// Ecliptic (lon, lat) → equatorial (RA, Dec) → sub-body geographic (lat, lon)
    private static func subBodyPoint(
        eclipticLon lonDeg: Double,
        eclipticLat latDeg: Double,
        gmst: Double
    ) -> GeographicPoint {
        // Mean obliquity of the ecliptic (degrees) — J2000 value, good enough for 64×32 grid
        let eps = 23.4393 * .pi / 180.0

        let lonRad = lonDeg * .pi / 180.0
        let latRad = latDeg * .pi / 180.0

        // Ecliptic → equatorial (standard formula)
        let ra  = atan2(
            sin(lonRad) * cos(eps) - tan(latRad) * sin(eps),
            cos(lonRad)
        )   // radians
        let dec = asin(
            sin(latRad) * cos(eps) + cos(latRad) * sin(eps) * sin(lonRad)
        )   // radians

        // RA → geographic longitude: subLon = RA_deg - GMST
        let raDeg    = ra * 180.0 / .pi
        var subLon   = raDeg - gmst
        // Normalize to [-180, 180) for consistency (not strictly needed)
        subLon = subLon.truncatingRemainder(dividingBy: 360.0)
        if subLon < -180.0 { subLon += 360.0 }
        if subLon >  180.0 { subLon -= 360.0 }

        let subLat = dec * 180.0 / .pi

        return GeographicPoint(lat: subLat, lon: subLon)
    }
}
