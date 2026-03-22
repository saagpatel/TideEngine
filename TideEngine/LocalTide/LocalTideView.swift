import SwiftUI
import CoreLocation

// MARK: - Tidal strength computed locally from ephemeris (no network required)

private struct LocalTidalStrength {
    let pullPercent: Int          // 0–100
    let displacement: Double      // metres, signed
    let moonAngleDeg: Double      // angle between coordinate and Moon sub-point

    static func compute(for coordinate: CLLocationCoordinate2D, at date: Date) -> LocalTidalStrength {
        let positions = Ephemeris.positions(at: date)
        guard
            let moon = positions.first(where: { $0.body == .moon }),
            let sun  = positions.first(where: { $0.body == .sun })
        else {
            return LocalTidalStrength(pullPercent: 0, displacement: 0, moonAngleDeg: 90)
        }

        let field = TidalForce.computeHeightField(moon: moon, sun: sun)

        // Map coordinate to nearest grid cell
        let latIdx = clampIndex(
            Int(round((coordinate.latitude + 90.0) / (180.0 / Double(TidalForceField.rows - 1)))),
            TidalForceField.rows
        )
        let lonNorm = coordinate.longitude < 0 ? coordinate.longitude + 360.0 : coordinate.longitude
        let lonIdx  = clampIndex(
            Int(round(lonNorm / (360.0 / Double(TidalForceField.columns)))),
            TidalForceField.columns
        )

        let normalized = Double(field.heightField[latIdx][lonIdx])  // –1 … +1
        let displacementM = normalized * field.maxDisplacementMeters

        // Gravitational pull strength: map [-1, +1] to [0, 100], peaks at ±1
        let pullPercent = Int(round(abs(normalized) * 100.0))

        // Angle between tapped point and Moon sub-point (for display)
        let gmst = Ephemeris.gmstDegrees(at: date)
        let moonRaRad = (moon.eclipticLongitude - gmst) * .pi / 180.0
        let moonDecRad = moon.eclipticLatitude * .pi / 180.0
        let pointLatRad = coordinate.latitude * .pi / 180.0
        let pointLonRad = coordinate.longitude * .pi / 180.0
        let cosTheta = sin(pointLatRad) * sin(moonDecRad)
                     + cos(pointLatRad) * cos(moonDecRad) * cos(pointLonRad - moonRaRad)
        let angleDeg = acos(max(-1, min(1, cosTheta))) * 180.0 / .pi

        return LocalTidalStrength(
            pullPercent: pullPercent,
            displacement: displacementM,
            moonAngleDeg: angleDeg
        )
    }
}

// MARK: - Clamp helper

private func clampIndex(_ value: Int, _ upperExclusive: Int) -> Int {
    Swift.max(0, Swift.min(value, upperExclusive - 1))
}

// MARK: - View

struct LocalTideView: View {
    let coordinate: CLLocationCoordinate2D

    @State private var strength: LocalTidalStrength?
    @State private var tideResult: TideDataService.TideResult?
    @State private var tideError: Error?
    @State private var isLoadingTides = true

    private let teal = Color(red: 0, green: 0.9, blue: 1.0)
    private let background = Color(red: 0.04, green: 0.055, blue: 0.10)
    private let cardBackground = Color(red: 0.07, green: 0.09, blue: 0.15)

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // ── Station header ────────────────────────────────────────
                stationHeader

                Divider()
                    .overlay(teal.opacity(0.2))
                    .padding(.horizontal, 24)

                // ── Gravitational pull card ───────────────────────────────
                if let s = strength {
                    pullCard(s)
                } else {
                    pullCardPlaceholder
                }

                Divider()
                    .overlay(teal.opacity(0.2))
                    .padding(.horizontal, 24)

                // ── Tide chart ────────────────────────────────────────────
                chartSection

                Divider()
                    .overlay(teal.opacity(0.2))
                    .padding(.horizontal, 24)

                // ── Next tide cards ───────────────────────────────────────
                nextTidesSection

                // ── Error / stale banner ──────────────────────────────────
                statusBanner
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            strength = LocalTidalStrength.compute(for: coordinate, at: .now)
            do {
                tideResult = try await TideDataService.shared.loadTideData(for: coordinate)
            } catch {
                tideError = error
            }
            isLoadingTides = false
        }
    }

    // MARK: - Station header

    private var stationHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "water.waves")
                .font(.system(size: 40))
                .foregroundStyle(teal)
                .padding(.top, 32)

            if let station = tideResult?.station {
                Text(station.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    stationDistanceBadge(station: station)

                    if let result = tideResult {
                        dataSourceBadge(result: result)
                    }
                }
            } else {
                Text(formatCoordinate())
                    .font(.title3.monospaced())
                    .foregroundStyle(teal)

                Text("Tidal Conditions")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.bottom, 24)
    }

    private func stationDistanceBadge(station: TideStation) -> some View {
        let distanceKm = distanceKilometers(to: station)
        return Text(String(format: "%.0f km away", distanceKm))
            .font(.caption.weight(.medium))
            .foregroundStyle(.gray)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(cardBackground)
            .clipShape(Capsule())
    }

    private func dataSourceBadge(result: TideDataService.TideResult) -> some View {
        let isLive = !result.isFromCache
        let label = isLive ? "Live NOAA" : "Cached"
        let color: Color = isLive ? .green : .orange

        return HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Gravitational pull card

    private func pullCard(_ s: LocalTidalStrength) -> some View {
        VStack(spacing: 20) {
            HStack(alignment: .top, spacing: 32) {
                tidalMetric(
                    label: "Gravitational Pull",
                    value: "\(s.pullPercent)%",
                    icon: "moon.stars.fill"
                )
                tidalMetric(
                    label: "Surface Displacement",
                    value: displacementText(s.displacement),
                    icon: "arrow.up.and.down.circle.fill"
                )
                tidalMetric(
                    label: "Moon Angle",
                    value: String(format: "%.0f°", s.moonAngleDeg),
                    icon: "angle"
                )
            }

            // Pull strength gauge bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(teal.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [teal.opacity(0.6), teal],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(s.pullPercent) / 100.0, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(24)
    }

    private var pullCardPlaceholder: some View {
        VStack(spacing: 8) {
            ProgressView()
                .tint(teal)
            Text("Computing tidal forces…")
                .font(.caption)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    // MARK: - Chart section

    @ViewBuilder
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("7-Day Tide Heights")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.top, 24)

            if isLoadingTides {
                chartSkeleton
            } else if let result = tideResult, !result.hourlyCurve.isEmpty {
                TideChartView(
                    hourlyCurve: result.hourlyCurve,
                    extremes: result.predictions
                )
                .padding(.horizontal, 24)
            } else if tideError != nil {
                Text("Chart unavailable")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .padding(.horizontal, 24)
            }
        }
        .padding(.bottom, 24)
    }

    private var chartSkeleton: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(cardBackground)
            .frame(height: 200)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .fill(teal.opacity(0.05))
            )
            .padding(.horizontal, 24)
            .redacted(reason: .placeholder)
    }

    // MARK: - Next tides section

    private var nextTidesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Tide Predictions")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("NOAA · 7 days")
                    .font(.caption)
                    .foregroundStyle(teal.opacity(0.7))
            }

            if upcomingTides.isEmpty {
                skeletonTideRows
            } else {
                TimelineView(.periodic(from: .now, by: 60)) { _ in
                    VStack(spacing: 0) {
                        ForEach(upcomingTides) { prediction in
                            tideRow(prediction)
                        }
                    }
                }
            }
        }
        .padding(24)
    }

    private var skeletonTideRows: some View {
        let slots = [
            ("Next High Tide",   "arrow.up.circle.fill",   teal),
            ("Next Low Tide",    "arrow.down.circle.fill", Color(red: 0.4, green: 0.7, blue: 1.0)),
            ("Following High",   "arrow.up.circle.fill",   teal.opacity(0.6)),
            ("Following Low",    "arrow.down.circle.fill", Color(red: 0.4, green: 0.7, blue: 1.0).opacity(0.6)),
        ]

        return VStack(spacing: 0) {
            ForEach(slots, id: \.0) { slot in
                HStack(spacing: 16) {
                    Image(systemName: slot.1)
                        .font(.title3)
                        .foregroundStyle(slot.2)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(slot.0)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        Text(isLoadingTides ? "Loading…" : "No data available")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("—")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.4))
                        Text("— m")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func tideRow(_ prediction: TidePrediction) -> some View {
        let isHigh = prediction.type == .high
        let iconName = isHigh ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
        let iconColor: Color = isHigh
            ? teal
            : Color(red: 0.4, green: 0.7, blue: 1.0)
        let label = isHigh ? "High Tide" : "Low Tide"

        return HStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Text(relativeTime(to: prediction.timestamp))
                    .font(.caption)
                    .foregroundStyle(.gray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(prediction.timestamp, format: .dateTime.hour().minute())
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.white)
                Text(String(format: "%.2f m", prediction.heightMeters))
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Status banner

    @ViewBuilder
    private var statusBanner: some View {
        if let result = tideResult, result.isFromCache, let cachedAt = result.cachedAt {
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.caption)
                Text("Cached data from \(cachedAt, format: .relative(presentation: .named))")
                    .font(.caption)
            }
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.top, 8)
        } else if let error = tideError, tideResult == nil {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(error.localizedDescription)
                        .font(.caption)
                }
                .foregroundStyle(.red)

                Button("Retry") {
                    Task {
                        tideError = nil
                        isLoadingTides = true
                        do {
                            tideResult = try await TideDataService.shared.loadTideData(for: coordinate)
                        } catch {
                            tideError = error
                        }
                        isLoadingTides = false
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(teal)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.top, 8)
        }
    }

    // MARK: - Computed properties

    private var upcomingTides: [TidePrediction] {
        guard let predictions = tideResult?.predictions else { return [] }
        return predictions
            .filter { $0.timestamp > Date.now }
            .prefix(4)
            .map { $0 }
    }

    // MARK: - Helpers

    private func tidalMetric(label: String, value: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(teal)
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatCoordinate() -> String {
        let latDir = coordinate.latitude  >= 0 ? "N" : "S"
        let lonDir = coordinate.longitude >= 0 ? "E" : "W"
        return String(format: "%.2f°%@ %.2f°%@",
                      abs(coordinate.latitude),  latDir,
                      abs(coordinate.longitude), lonDir)
    }

    private func displacementText(_ metres: Double) -> String {
        let cm = metres * 100.0
        if abs(cm) >= 10 {
            return String(format: "%.0f cm", cm)
        } else {
            return String(format: "%.1f cm", cm)
        }
    }

    private func relativeTime(to date: Date) -> String {
        let seconds = date.timeIntervalSince(Date.now)
        guard seconds > 0 else { return "now" }
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 { return "in \(hours)h \(minutes)m" }
        return "in \(minutes)m"
    }

    private func distanceKilometers(to station: TideStation) -> Double {
        let earthRadiusKm = 6371.0
        let lat1 = coordinate.latitude * .pi / 180.0
        let lat2 = station.latitude * .pi / 180.0
        let dLat = (station.latitude - coordinate.latitude) * .pi / 180.0
        let dLon = (station.longitude - coordinate.longitude) * .pi / 180.0
        let a = sin(dLat / 2) * sin(dLat / 2)
              + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusKm * c
    }
}

#Preview {
    NavigationStack {
        LocalTideView(coordinate: CLLocationCoordinate2D(latitude: 37.78, longitude: -122.42))
    }
}
