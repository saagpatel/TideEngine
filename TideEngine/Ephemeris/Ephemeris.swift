import Foundation

// MARK: - Ephemeris
// Moon: Meeus ELP 2000/82 truncated (Chapter 47, Astronomical Algorithms 2nd ed.)
// Sun:  VSOP87 truncated (Earth heliocentric L/B/R series)

struct Ephemeris {

    // MARK: - Public API

    static func positions(at date: Date) -> [CelestialPosition] {
        let jde = julianDay(from: date)
        let t = (jde - 2451545.0) / 36525.0
        return [
            moonPosition(t: t, jde: jde, date: date),
            sunPosition(t: t, jde: jde, date: date),
        ]
    }

    // MARK: - Julian Day

    static func julianDay(from date: Date) -> Double {
        // J2000.0 = 2451545.0 = 2000-01-01 12:00 TT
        // Unix epoch (1970-01-01 00:00 UTC) = JD 2440587.5
        return date.timeIntervalSince1970 / 86400.0 + 2440587.5
    }

    // MARK: - Moon (Meeus Chapter 47, ELP 2000/82 truncated)

    private static func moonPosition(t: Double, jde: Double, date: Date) -> CelestialPosition {
        // Five fundamental arguments (degrees)
        var lp = 218.3165 + 481267.8813 * t - 0.0013268 * t * t + t * t * t / 538841.0 - t * t * t * t / 65194000.0
        var d  = 297.8502 + 445267.1115 * t - 0.0016300 * t * t + t * t * t / 545868.0 - t * t * t * t / 113065000.0
        var m  = 357.5291 + 35999.0503  * t - 0.0001559 * t * t - t * t * t / 24490000.0
        var mp = 134.9634 + 477198.8676 * t + 0.0089970 * t * t + t * t * t / 69699.0   - t * t * t * t / 14712000.0
        var f  = 93.2720  + 483202.0175 * t - 0.0034029 * t * t - t * t * t / 3526000.0 + t * t * t * t / 863310000.0

        // Normalize to [0, 360)
        lp = normalizeAngle(lp)
        d  = normalizeAngle(d)
        m  = normalizeAngle(m)
        mp = normalizeAngle(mp)
        f  = normalizeAngle(f)

        // Additional arguments
        let a1 = normalizeAngle(119.75 + 131.849 * t)
        let a2 = normalizeAngle(53.09  + 479264.290 * t)
        let a3 = normalizeAngle(313.45 + 481266.484 * t)

        // E correction for terms involving Sun's mean anomaly M
        let e = 1.0 - 0.002516 * t - 0.0000074 * t * t

        // Convert fundamental arguments to radians for trig
        let dpRad = d  * .pi / 180.0
        let mRad  = m  * .pi / 180.0
        let mpRad = mp * .pi / 180.0
        let fRad  = f  * .pi / 180.0

        // Periodic terms table: (D, M, M', F, l_coeff, r_coeff)
        let lonRadTerms: [(Int, Int, Int, Int, Double, Double)] = [
            ( 0,  0,  1,  0,  6288774.0, -20905355.0),
            ( 2,  0, -1,  0,  1274027.0,  -3699111.0),
            ( 2,  0,  0,  0,   658314.0,  -2955968.0),
            ( 0,  0,  2,  0,   213618.0,   -569925.0),
            ( 0,  1,  0,  0,  -185116.0,     48888.0),
            ( 0,  0,  0,  2,  -114332.0,     -3149.0),
            ( 2,  0, -2,  0,    58793.0,    246158.0),
            ( 2, -1, -1,  0,    57066.0,   -152138.0),
            ( 2,  0,  1,  0,    53322.0,   -170733.0),
            ( 2, -1,  0,  0,    45758.0,   -204586.0),
            ( 0,  1, -1,  0,   -40923.0,   -129620.0),
            ( 1,  0,  0,  0,   -34720.0,    108743.0),
            ( 0,  1,  1,  0,   -30383.0,    104755.0),
            ( 2,  0,  0, -2,    15327.0,     10321.0),
            ( 0,  0,  1,  2,   -12528.0,         0.0),
            ( 0,  0,  1, -2,    10980.0,     79661.0),
            ( 4,  0, -1,  0,    10675.0,    -34782.0),
            ( 0,  0,  3,  0,    10034.0,    -23210.0),
            ( 4,  0, -2,  0,     8548.0,    -21636.0),
            ( 2,  1, -1,  0,    -7888.0,     24208.0),
            ( 2,  1,  0,  0,    -6766.0,     30824.0),
            ( 1,  0, -1,  0,    -5163.0,     -8379.0),
            ( 1,  1,  0,  0,     4987.0,    -16675.0),
            ( 2, -1,  1,  0,     4036.0,    -12831.0),
            ( 2,  0,  2,  0,     3994.0,    -10445.0),
            ( 4,  0,  0,  0,     3861.0,    -11650.0),
            ( 2,  0, -3,  0,     3665.0,     14403.0),
            ( 0,  1, -2,  0,    -2689.0,     -7003.0),
            ( 2,  0, -1,  2,    -2602.0,         0.0),
            ( 2, -1, -2,  0,     2390.0,     10056.0),
            ( 1,  0,  1,  0,    -2348.0,      6322.0),
            ( 2, -2,  0,  0,     2236.0,     -9884.0),
            ( 0,  1,  2,  0,    -2120.0,      5751.0),
            ( 0,  2,  0,  0,    -2069.0,         0.0),
            ( 2, -2, -1,  0,     2048.0,     -4950.0),
            ( 2,  0,  1, -2,    -1773.0,      4130.0),
            ( 2,  0,  0,  2,    -1595.0,         0.0),
            ( 4, -1, -1,  0,     1215.0,     -3958.0),
            ( 0,  0,  2,  2,    -1110.0,         0.0),
            ( 3,  0, -1,  0,     -892.0,      3258.0),
            ( 2,  1,  1,  0,     -810.0,      2616.0),
            ( 4, -1, -2,  0,      759.0,     -1897.0),
            ( 0,  2, -1,  0,     -713.0,     -2117.0),
            ( 2,  2, -1,  0,     -700.0,      2354.0),
            ( 2,  1, -2,  0,      691.0,         0.0),
            ( 2, -1,  0, -2,      596.0,         0.0),
            ( 4,  0,  1,  0,      549.0,     -1423.0),
            ( 0,  0,  4,  0,      537.0,     -1117.0),
            ( 4, -1,  0,  0,      520.0,     -1571.0),
            ( 1,  0, -2,  0,     -487.0,     -1739.0),
            ( 2,  1,  0, -2,     -399.0,         0.0),
            ( 0,  0,  2, -2,     -381.0,     -4421.0),
            ( 1,  1,  1,  0,      351.0,         0.0),
            ( 3,  0, -2,  0,     -340.0,         0.0),
            ( 4,  0, -3,  0,      330.0,         0.0),
            ( 2, -1,  2,  0,      327.0,         0.0),
            ( 0,  2,  1,  0,     -323.0,      1165.0),
            ( 1,  1, -1,  0,      299.0,         0.0),
            ( 2,  0,  3,  0,      294.0,         0.0),
            ( 2,  0, -1, -2,        0.0,      8752.0),
        ]

        var sigmaL = 0.0
        var sigmaR = 0.0

        for term in lonRadTerms {
            let (dCoef, mCoef, mpCoef, fCoef, lCoeff, rCoeff) = term
            let arg = Double(dCoef) * dpRad + Double(mCoef) * mRad + Double(mpCoef) * mpRad + Double(fCoef) * fRad
            let eFactor: Double
            switch abs(mCoef) {
            case 1: eFactor = e
            case 2: eFactor = e * e
            default: eFactor = 1.0
            }
            sigmaL += lCoeff * eFactor * sin(arg)
            sigmaR += rCoeff * eFactor * cos(arg)
        }

        // Additional longitude corrections (Meeus §47, additive terms)
        let a1Rad = a1 * .pi / 180.0
        let a2Rad = a2 * .pi / 180.0
        let lpRad = lp * .pi / 180.0
        sigmaL += 3958.0 * sin(a1Rad)
             + 1962.0 * sin(lpRad - fRad)
             + 318.0  * sin(a2Rad)

        // Latitude terms table: (D, M, M', F, b_coeff)
        let latTerms: [(Int, Int, Int, Int, Double)] = [
            ( 0,  0,  0,  1,  5128122.0),
            ( 0,  0,  1,  1,   280602.0),
            ( 0,  0,  1, -1,   277693.0),
            ( 2,  0,  0, -1,   173237.0),
            ( 2,  0, -1,  1,    55413.0),
            ( 2,  0, -1, -1,    46271.0),
            ( 2,  0,  0,  1,    32573.0),
            ( 0,  0,  2,  1,    17198.0),
            ( 2,  0,  1, -1,     9266.0),
            ( 0,  0,  2, -1,     8822.0),
            ( 2, -1,  0, -1,     8216.0),
            ( 2,  0, -2, -1,     4324.0),
            ( 2,  0,  1,  1,     4200.0),
            ( 2,  1,  0, -1,    -3359.0),
            ( 2, -1, -1,  1,     2463.0),
            ( 2, -1,  0,  1,     2211.0),
            ( 2, -1, -1, -1,     2065.0),
            ( 0,  1, -1, -1,    -1870.0),
            ( 4,  0, -1, -1,     1828.0),
            ( 0,  1,  0,  1,    -1794.0),
            ( 0,  0,  0,  3,    -1749.0),
            ( 0,  1, -1,  1,    -1565.0),
            ( 1,  0,  0,  1,    -1491.0),
            ( 0,  1,  1,  1,    -1475.0),
            ( 0,  1,  1, -1,    -1410.0),
            ( 0,  1,  0, -1,    -1344.0),
            ( 1,  0,  0, -1,    -1335.0),
            ( 0,  0,  3,  1,     1107.0),
            ( 4,  0,  0, -1,     1021.0),
            ( 4,  0, -1,  1,      833.0),
        ]

        var sigmaB = 0.0
        for term in latTerms {
            let (dCoef, mCoef, mpCoef, fCoef, bCoeff) = term
            let arg = Double(dCoef) * dpRad + Double(mCoef) * mRad + Double(mpCoef) * mpRad + Double(fCoef) * fRad
            let eFactor: Double
            switch abs(mCoef) {
            case 1: eFactor = e
            case 2: eFactor = e * e
            default: eFactor = 1.0
            }
            sigmaB += bCoeff * eFactor * sin(arg)
        }

        // Additional latitude corrections (Meeus §47)
        let a3Rad = a3 * .pi / 180.0
        sigmaB += -2235.0 * sin(lpRad)
              + 382.0  * sin(a3Rad)
              + 175.0  * sin(a1Rad - fRad)
              + 175.0  * sin(a1Rad + fRad)
              + 127.0  * sin(lpRad - mpRad)
              - 115.0  * sin(lpRad + mpRad)

        // Ecliptic coordinates
        let lambda = normalizeAngle(lp + sigmaL / 1_000_000.0)        // degrees
        let beta   = sigmaB / 1_000_000.0                              // degrees
        let distKm = 385000.56 + sigmaR / 1000.0                      // km
        let distAU = distKm / 149_597_870.7                            // AU

        return CelestialPosition(
            body: .moon,
            eclipticLongitude: lambda,
            eclipticLatitude: beta,
            distanceAU: distAU,
            timestamp: date
        )
    }

    // MARK: - Sun (VSOP87 truncated — Earth heliocentric L/B/R)

    private static func sunPosition(t: Double, jde: Double, date: Date) -> CelestialPosition {
        // VSOP87 series: sum = Σ A·cos(B + C·τ) where τ = JDE/365250 — Julian millennia
        // For the truncated series used here we work in Julian centuries τ = T (Julian centuries from J2000)
        let tau = t / 10.0  // Julian millennia from J2000.0

        // --- L0 terms ---
        let l0Terms: [(Double, Double, Double)] = [
            (175347046.0, 0.0000000, 0.0000000),
            (  3341656.0, 4.6692568, 6283.0758500),
            (    34894.0, 4.6261000, 12566.1517000),
            (     3497.0, 2.7441000,  5753.3849000),
            (     3418.0, 2.8289000,     3.5232000),
            (     3136.0, 3.6277000, 77713.7715000),
            (     2676.0, 4.4181000,  7860.4194000),
            (     2343.0, 6.1352000,  3930.2097000),
            (     1324.0, 0.7425000, 11506.7698000),
            (     1273.0, 2.0371000,   529.6910000),
            (     1199.0, 1.1096000,  1577.3435000),
            (      990.0, 5.2330000,  5884.9268000),
            (      902.0, 2.0450000,    26.2983000),
            (      857.0, 3.5080000,   398.1490000),
            (      780.0, 1.1790000,  5223.6940000),
            (      753.0, 2.5330000,  5507.5534000),
            (      505.0, 4.5830000, 18849.2275000),
            (      492.0, 4.2050000,   775.5226000),
            (      357.0, 2.9200000,     0.0671000),
            (      317.0, 5.8490000, 11790.6291000),
            (      284.0, 1.8990000,   796.2983000),
            (      271.0, 0.3150000, 10977.0789000),
            (      243.0, 0.3450000,  5486.7778000),
        ]

        // --- L1 terms ---
        let l1Terms: [(Double, Double, Double)] = [
            (628331966747.0, 0.000000, 0.000000),
            (      206059.0, 2.678235, 6283.075850),
            (        4303.0, 2.635100, 12566.151700),
            (         425.0, 1.590000,    3.523000),
            (         119.0, 5.796000,   26.298000),
        ]

        // --- L2 terms ---
        let l2Terms: [(Double, Double, Double)] = [
            (8722.0, 1.0725, 6283.0759),
            ( 991.0, 3.1416,    0.0000),
            ( 295.0, 0.4370, 12566.1517),
            (  27.0, 0.0500,    3.0000),
            (  16.0, 5.1900,   26.3000),
        ]

        let l0 = vsop87Sum(terms: l0Terms, tau: tau)
        let l1 = vsop87Sum(terms: l1Terms, tau: tau)
        let l2 = vsop87Sum(terms: l2Terms, tau: tau)

        // Earth heliocentric longitude (radians)
        let l = (l0 + l1 * tau + l2 * tau * tau) / 1.0e8

        // Geocentric Sun longitude (add π, flip to geocentric)
        var sunLon = l + .pi   // radians
        // Normalize to [0, 2π)
        sunLon = sunLon.truncatingRemainder(dividingBy: 2.0 * .pi)
        if sunLon < 0 { sunLon += 2.0 * .pi }

        // --- B0 terms (Earth heliocentric latitude) ---
        let b0Terms: [(Double, Double, Double)] = [
            (280.0, 3.199, 84334.662),
            (102.0, 5.422,  5507.553),
            ( 80.0, 3.880,  5223.694),
            ( 44.0, 3.700,  2352.866),
            ( 32.0, 4.000,  1577.344),
        ]
        let b0 = vsop87Sum(terms: b0Terms, tau: tau)
        let b = b0 / 1.0e8   // radians — very small
        let sunLat = -b      // geocentric latitude (radians)

        // --- R0 terms (Earth-Sun distance, AU) ---
        let r0Terms: [(Double, Double, Double)] = [
            (100013989.0, 0.000000, 0.000000),
            (  1670700.0, 3.098464, 6283.075850),
            (    13956.0, 3.055250, 12566.151700),
            (     3084.0, 5.198500, 77713.771500),
            (     1628.0, 1.173900,  5753.385000),
            (     1576.0, 2.846900,  7860.419000),
            (      925.0, 5.453000, 11506.770000),
            (      542.0, 4.564000,  3930.210000),
            (      472.0, 3.661000,  5884.927000),
            (      346.0, 0.964000,  5507.553000),
            (      329.0, 5.900000,  5223.694000),
            (      307.0, 0.299000,  5573.143000),
            (      243.0, 4.273000, 11790.629000),
        ]
        let r0 = vsop87Sum(terms: r0Terms, tau: tau)
        let distAU = r0 / 1.0e8

        // Aberration correction (degrees)
        let aberration = 20.4898 / (3600.0 * distAU)

        // Convert to degrees, apply aberration, normalize
        var lonDeg = sunLon * 180.0 / .pi - aberration
        lonDeg = normalizeAngle(lonDeg)
        let latDeg = sunLat * 180.0 / .pi

        return CelestialPosition(
            body: .sun,
            eclipticLongitude: lonDeg,
            eclipticLatitude: latDeg,
            distanceAU: distAU,
            timestamp: date
        )
    }

    // MARK: - GMST

    /// Greenwich Mean Sidereal Time in degrees [0, 360) for a given Date.
    static func gmstDegrees(at date: Date) -> Double {
        let jd = julianDay(from: date)
        let gmst = 280.46061837 + 360.98564736629 * (jd - 2451545.0)
        return normalizeAngle(gmst)
    }

    // MARK: - Helpers

    /// Evaluate a VSOP87 sub-series: Σ A·cos(B + C·τ)
    private static func vsop87Sum(terms: [(Double, Double, Double)], tau: Double) -> Double {
        terms.reduce(0.0) { sum, term in
            let (a, b, c) = term
            return sum + a * cos(b + c * tau)
        }
    }

    /// Reduce an angle (degrees) to [0, 360)
    static func normalizeAngle(_ deg: Double) -> Double {
        var result = deg.truncatingRemainder(dividingBy: 360.0)
        if result < 0 { result += 360.0 }
        return result
    }
}
