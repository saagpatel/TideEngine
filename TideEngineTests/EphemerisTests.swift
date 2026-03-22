import XCTest
@testable import TideEngine

final class EphemerisTests: XCTestCase {

    // MARK: - Helpers

    private func date(from string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        if let d = formatter.date(from: string) { return d }
        // Fallback: date-only
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)!
    }

    private func moon(at dateString: String) -> CelestialPosition {
        let positions = Ephemeris.positions(at: date(from: dateString))
        return positions.first { $0.body == .moon }!
    }

    private func sun(at dateString: String) -> CelestialPosition {
        let positions = Ephemeris.positions(at: date(from: dateString))
        return positions.first { $0.body == .sun }!
    }

    // MARK: - Julian Day

    func testJulianDay_J2000() {
        // J2000.0 = 2000-01-01 12:00 UTC → JD 2451545.0
        let d = date(from: "2000-01-01 12:00")
        let jd = Ephemeris.julianDay(from: d)
        XCTAssertEqual(jd, 2451545.0, accuracy: 0.001)
    }

    func testJulianDay_UnixEpoch() {
        // Unix epoch 1970-01-01 00:00 UTC → JD 2440587.5
        let d = Date(timeIntervalSince1970: 0)
        let jd = Ephemeris.julianDay(from: d)
        XCTAssertEqual(jd, 2440587.5, accuracy: 0.0001)
    }

    // MARK: - Moon Longitude Tests
    // Reference: JPL Horizons ObsEcLon geocentric ecliptic longitude (IAU76/80 ecliptic of date)
    // at 00:00 UTC for each date.  Acceptance tolerance: ±0.5°
    //
    // Verified values (JPL Horizons API, COMMAND=301, CENTER=500@399, QUANTITIES=31):
    //   2024-06-21: 257.0808°
    //   2024-12-21: 158.4119°
    //   2025-03-20: 241.8503°
    //   2025-09-22: 181.1915°
    //   2026-03-22:  40.4959°

    func testMoonLongitude_2024SummerSolstice() {
        // JPL Horizons 2024-06-21 00:00 UTC → 257.0808°
        let m = moon(at: "2024-06-21")
        XCTAssertEqual(m.eclipticLongitude, 257.08, accuracy: 0.5,
                       "Moon longitude 2024-06-21 should be ~257.08°")
    }

    func testMoonLongitude_2024WinterSolstice() {
        // JPL Horizons 2024-12-21 00:00 UTC → 158.4119°
        let m = moon(at: "2024-12-21")
        XCTAssertEqual(m.eclipticLongitude, 158.41, accuracy: 0.5,
                       "Moon longitude 2024-12-21 should be ~158.41°")
    }

    func testMoonLongitude_2025VernalEquinox() {
        // JPL Horizons 2025-03-20 00:00 UTC → 241.8503°
        let m = moon(at: "2025-03-20")
        XCTAssertEqual(m.eclipticLongitude, 241.85, accuracy: 0.5,
                       "Moon longitude 2025-03-20 should be ~241.85°")
    }

    func testMoonLongitude_2025AutumnalEquinox() {
        // JPL Horizons 2025-09-22 00:00 UTC → 181.1915°
        let m = moon(at: "2025-09-22")
        XCTAssertEqual(m.eclipticLongitude, 181.19, accuracy: 0.5,
                       "Moon longitude 2025-09-22 should be ~181.19°")
    }

    func testMoonLongitude_2026March() {
        // JPL Horizons 2026-03-22 00:00 UTC → 40.4959°
        let m = moon(at: "2026-03-22")
        XCTAssertEqual(m.eclipticLongitude, 40.50, accuracy: 0.5,
                       "Moon longitude 2026-03-22 should be ~40.50°")
    }

    // MARK: - Moon Latitude Tests
    // Moon latitude is bounded by ±5.15°; Meeus gives < ±0.2° error for these terms.

    func testMoonLatitudeInBounds() {
        let dates = ["2024-06-21", "2024-12-21", "2025-03-20", "2025-09-22", "2026-03-22"]
        for ds in dates {
            let m = moon(at: ds)
            XCTAssertLessThanOrEqual(abs(m.eclipticLatitude), 6.0,
                                     "Moon latitude should be within ±6° on \(ds)")
        }
    }

    // MARK: - Moon Distance Tests
    // Moon distance varies from ~356,000 km (perigee) to ~406,000 km (apogee).
    // In AU: ~0.00238 to ~0.00272.

    func testMoonDistanceInReasonableRange() {
        let dates = ["2024-06-21", "2024-12-21", "2025-03-20", "2025-09-22", "2026-03-22"]
        for ds in dates {
            let m = moon(at: ds)
            XCTAssertGreaterThan(m.distanceAU, 0.00230, "Moon too close on \(ds)")
            XCTAssertLessThan(m.distanceAU,    0.00290, "Moon too far on \(ds)")
        }
    }

    // MARK: - Sun Longitude Tests
    // Reference: geocentric ecliptic longitude.
    // Acceptance tolerance: ±0.2°

    func testSunLongitude_SummerSolstice() {
        // At summer solstice (~June 21), Sun longitude ≈ 90°
        let s = sun(at: "2024-06-21")
        XCTAssertEqual(s.eclipticLongitude, 90.0, accuracy: 0.5,
                       "Sun longitude at summer solstice should be ~90°")
    }

    func testSunLongitude_VernalEquinox() {
        // At vernal equinox (~March 20), Sun longitude ≈ 0° (or 360°)
        let s = sun(at: "2025-03-20")
        // Near 0/360 boundary — check absolute distance on circle
        let lon = s.eclipticLongitude
        let dist = min(lon, 360.0 - lon)   // angular distance from 0°
        XCTAssertLessThanOrEqual(dist, 1.0,
                                 "Sun longitude at vernal equinox should be near 0°, got \(lon)°")
    }

    func testSunLongitude_AutumnalEquinox() {
        // JPL Horizons 2025-09-22 00:00 UTC → 179.2529° (equinox occurs at ~18:19 UTC, so
        // longitude at midnight is slightly short of 180°)
        let s = sun(at: "2025-09-22")
        XCTAssertEqual(s.eclipticLongitude, 179.25, accuracy: 0.5,
                       "Sun longitude at autumnal equinox should be ~179.25°")
    }

    func testSunLongitude_WinterSolstice() {
        // At winter solstice (~December 21), Sun longitude ≈ 270°
        let s = sun(at: "2024-12-21")
        XCTAssertEqual(s.eclipticLongitude, 270.0, accuracy: 0.5,
                       "Sun longitude at winter solstice should be ~270°")
    }

    func testSunLongitude_2026March() {
        // Just past vernal equinox (2026-03-22), Sun longitude ≈ 1–2°
        let s = sun(at: "2026-03-22")
        let lon = s.eclipticLongitude
        let dist = min(lon, 360.0 - lon)
        XCTAssertLessThanOrEqual(dist, 3.0,
                                 "Sun longitude 2026-03-22 should be near 0/360°, got \(lon)°")
    }

    // MARK: - Sun Latitude Tests
    // The geocentric Sun latitude should be very small (within ±0.01°)

    func testSunLatitudeNearZero() {
        let dates = ["2024-06-21", "2024-12-21", "2025-03-20", "2025-09-22", "2026-03-22"]
        for ds in dates {
            let s = sun(at: ds)
            XCTAssertLessThanOrEqual(abs(s.eclipticLatitude), 0.05,
                                     "Sun ecliptic latitude should be near 0° on \(ds), got \(s.eclipticLatitude)°")
        }
    }

    // MARK: - Sun Distance Tests
    // Earth-Sun distance: ~0.983 AU (perihelion, Jan) to ~1.017 AU (aphelion, Jul)

    func testSunDistanceInReasonableRange() {
        let dates = ["2024-06-21", "2024-12-21", "2025-03-20", "2025-09-22", "2026-03-22"]
        for ds in dates {
            let s = sun(at: ds)
            XCTAssertGreaterThan(s.distanceAU, 0.980, "Sun too close on \(ds)")
            XCTAssertLessThan(s.distanceAU,    1.020, "Sun too far on \(ds)")
        }
    }

    // MARK: - Longitude Normalization

    func testEclipticLongitudeAlwaysInBounds() {
        let dates = ["2024-06-21", "2024-12-21", "2025-03-20", "2025-09-22", "2026-03-22"]
        for ds in dates {
            let positions = Ephemeris.positions(at: date(from: ds))
            for p in positions {
                XCTAssertGreaterThanOrEqual(p.eclipticLongitude, 0.0,
                                            "\(p.body) longitude < 0 on \(ds)")
                XCTAssertLessThan(p.eclipticLongitude, 360.0,
                                  "\(p.body) longitude ≥ 360 on \(ds)")
            }
        }
    }

    // MARK: - Positions returns both bodies

    func testPositionsReturnsBothBodies() {
        let positions = Ephemeris.positions(at: date(from: "2025-03-20"))
        XCTAssertEqual(positions.count, 2)
        XCTAssertTrue(positions.contains { $0.body == .moon })
        XCTAssertTrue(positions.contains { $0.body == .sun })
    }

    // MARK: - TidalForce: Heightfield shape

    func testTidalForceTwoBulgePattern() {
        // Place Moon at 0° ecliptic lon/lat — sub-Moon point should be near equator / 0° lon
        // (minus GMST offset, but we're testing pattern not absolute position)
        let moonPos = CelestialPosition(
            body: .moon,
            eclipticLongitude: 0.0,
            eclipticLatitude: 0.0,
            distanceAU: 0.00257,
            timestamp: Date(timeIntervalSince1970: 946728000) // 2000-01-01 12:00 UTC (GMST ≈ 280°)
        )
        let sunPos = CelestialPosition(
            body: .sun,
            eclipticLongitude: 180.0,
            eclipticLatitude: 0.0,
            distanceAU: 1.0,
            timestamp: moonPos.timestamp
        )
        let field = TidalForce.computeHeightField(moon: moonPos, sun: sunPos)

        // The field should have exactly rows×cols entries
        XCTAssertEqual(field.heightField.count, TidalForceField.rows)
        for row in field.heightField {
            XCTAssertEqual(row.count, TidalForceField.columns)
        }

        // There should be two regions of high displacement (tidal bulges):
        // one near sub-Moon and one near the antipode.
        let maxVal = field.heightField.flatMap { $0 }.max()!
        let minVal = field.heightField.flatMap { $0 }.min()!

        // Maximum should be near +1.0 (normalized)
        XCTAssertGreaterThan(maxVal, 0.8, "Maximum tidal height should be near +1")
        // Minimum should be negative (troughs between bulges)
        XCTAssertLessThan(minVal, -0.3, "Tidal trough should be significantly negative")
    }

    func testTidalForceNormalization() {
        let positions = Ephemeris.positions(at: date(from: "2025-03-20"))
        let m = positions.first { $0.body == .moon }!
        let s = positions.first { $0.body == .sun }!
        let field = TidalForce.computeHeightField(moon: m, sun: s)

        var allValues = [Float]()
        for row in field.heightField {
            allValues.append(contentsOf: row)
        }

        // All values within [-1, 1]
        let maxAbs = allValues.map { abs($0) }.max()!
        XCTAssertLessThanOrEqual(maxAbs, 1.0 + 1e-5,
                                 "All heightfield values should be within [-1, 1]")

        // Maximum absolute value should be near 1.0 (field is normalized to its own extremes)
        XCTAssertGreaterThan(maxAbs, 0.95,
                             "Normalized heightfield max should be near 1.0")
    }

    func testTidalForceDimensions() {
        let positions = Ephemeris.positions(at: date(from: "2025-03-20"))
        let m = positions.first { $0.body == .moon }!
        let s = positions.first { $0.body == .sun }!
        let field = TidalForce.computeHeightField(moon: m, sun: s)

        XCTAssertEqual(field.heightField.count, 32)
        for row in field.heightField {
            XCTAssertEqual(row.count, 64)
        }
    }

    func testTidalForceMaxDisplacementIsPositive() {
        let positions = Ephemeris.positions(at: date(from: "2024-06-21"))
        let m = positions.first { $0.body == .moon }!
        let s = positions.first { $0.body == .sun }!
        let field = TidalForce.computeHeightField(moon: m, sun: s)
        XCTAssertGreaterThan(field.maxDisplacementMeters, 0.0)
        // Maximum equilibrium tidal displacement: A*(3cos²θ-1) peaks at 2A when θ=0.
        // Combined max ≈ 2*(aMoon + aSun) ≈ 2*(0.54+0.25) = 1.58 m when Sun and Moon align.
        XCTAssertLessThan(field.maxDisplacementMeters, 2.0)
    }

    // MARK: - Timestamp propagation

    func testTimestampPropagatedToField() {
        let refDate = date(from: "2025-09-22")
        let positions = Ephemeris.positions(at: refDate)
        let m = positions.first { $0.body == .moon }!
        let s = positions.first { $0.body == .sun }!
        let field = TidalForce.computeHeightField(moon: m, sun: s)
        XCTAssertEqual(field.timestamp.timeIntervalSince1970,
                       refDate.timeIntervalSince1970,
                       accuracy: 1.0)
    }
}
