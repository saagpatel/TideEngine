import SwiftUI
import WidgetKit

// MARK: - Entry

struct TideWidgetEntry: TimelineEntry {
    let date: Date
    let gravitationalPullPercent: Int   // 0–100
    let nextTide: TidePrediction?       // from cache
    let stationName: String
}

// MARK: - Provider

struct TideProvider: TimelineProvider {
    func placeholder(in context: Context) -> TideWidgetEntry {
        TideWidgetEntry(date: .now, gravitationalPullPercent: 65, nextTide: nil, stationName: "Loading...")
    }

    func getSnapshot(in context: Context, completion: @escaping (TideWidgetEntry) -> Void) {
        let entry = buildEntry(for: .now)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TideWidgetEntry>) -> Void) {
        let now = Date.now
        var entries: [TideWidgetEntry] = []

        // Generate 48 entries over 24 hours (every 30 minutes)
        for i in 0..<48 {
            let entryDate = now.addingTimeInterval(Double(i) * 1800)
            entries.append(buildEntry(for: entryDate))
        }

        // Refresh after 1 hour (WidgetKit's practical refresh budget)
        let timeline = Timeline(entries: entries, policy: .after(now.addingTimeInterval(3600)))
        completion(timeline)
    }

    private func buildEntry(for date: Date) -> TideWidgetEntry {
        // Load last station from App Group cache
        let station = TideCache.loadLastStation()
        let stationName = station?.name ?? "No Station"

        // Load cached predictions
        let predictions: [TidePrediction]
        if let stationId = station?.id,
           let cached = TideCache.loadPredictions(stationId: stationId) {
            predictions = cached.predictions
        } else if let stationId = station?.id,
                  let stale = TideCache.loadStalePredictions(stationId: stationId) {
            predictions = stale.predictions  // use stale if fresh expired
        } else {
            predictions = []
        }

        // Next tide after this entry's date
        let nextTide = predictions.first(where: { $0.timestamp > date })

        // Gravitational pull from ephemeris (offline, no network)
        let pullPercent = computeGravitationalPull(at: date, station: station)

        return TideWidgetEntry(
            date: date,
            gravitationalPullPercent: pullPercent,
            nextTide: nextTide,
            stationName: stationName
        )
    }

    private func computeGravitationalPull(at date: Date, station: TideStation?) -> Int {
        guard let station else { return 50 }  // default if no station

        let positions = Ephemeris.positions(at: date)
        guard let moon = positions.first(where: { $0.body == .moon }),
              let sun = positions.first(where: { $0.body == .sun }) else { return 50 }

        let field = TidalForce.computeHeightField(moon: moon, sun: sun)

        // Map station lat/lon to heightfield grid cell
        let latIdx = max(0, min(TidalForceField.rows - 1,
            Int(round((station.latitude + 90.0) / (180.0 / Double(TidalForceField.rows - 1))))
        ))
        let lonNorm = station.longitude < 0 ? station.longitude + 360.0 : station.longitude
        let lonIdx = max(0, min(TidalForceField.columns - 1,
            Int(round(lonNorm / (360.0 / Double(TidalForceField.columns))))
        ))

        let normalized = abs(Double(field.heightField[latIdx][lonIdx]))
        return Int(round(normalized * 100.0))
    }
}

// MARK: - View

struct TideWidgetView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: TideWidgetEntry

    private let teal = Color(red: 0, green: 0.9, blue: 1.0)

    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    // MARK: - Small (Gauge only)

    private var smallView: some View {
        Group {
            if entry.stationName == "No Station" {
                VStack(spacing: 8) {
                    Image(systemName: "globe.americas.fill")
                        .font(.title2)
                        .foregroundStyle(teal)
                    Text("Open Tide Engine")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                    Text("to get started")
                        .font(.caption2)
                        .foregroundStyle(.gray.opacity(0.7))
                }
            } else {
                VStack(spacing: 8) {
                    Gauge(value: Double(entry.gravitationalPullPercent), in: 0...100) {
                        Image(systemName: "moon.stars.fill")
                            .foregroundStyle(teal)
                    } currentValueLabel: {
                        Text("\(entry.gravitationalPullPercent)%")
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(.white)
                    }
                    .gaugeStyle(.accessoryCircular)
                    .tint(teal)

                    Text(truncatedStationName)
                        .font(.caption2)
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                }
            }
        }
        .containerBackground(.black, for: .widget)
    }

    // MARK: - Medium (Gauge + Next Tide)

    private var mediumView: some View {
        Group {
            if entry.stationName == "No Station" {
                VStack(spacing: 8) {
                    Image(systemName: "globe.americas.fill")
                        .font(.title2)
                        .foregroundStyle(teal)
                    Text("Open Tide Engine")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                    Text("to get started")
                        .font(.caption2)
                        .foregroundStyle(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 16) {
                    // Left: gauge
                    VStack(spacing: 4) {
                        Gauge(value: Double(entry.gravitationalPullPercent), in: 0...100) {
                            Image(systemName: "moon.stars.fill")
                        } currentValueLabel: {
                            Text("\(entry.gravitationalPullPercent)%")
                                .font(.body.weight(.bold).monospacedDigit())
                                .foregroundStyle(.white)
                        }
                        .gaugeStyle(.accessoryCircular)
                        .tint(teal)

                        Text("Pull")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }

                    // Right: station + next tide
                    VStack(alignment: .leading, spacing: 6) {
                        Text(truncatedStationName)
                            .font(.caption)
                            .foregroundStyle(.gray)
                            .lineLimit(1)

                        if let tide = entry.nextTide {
                            HStack(spacing: 4) {
                                Image(systemName: tide.type == .high ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                    .foregroundStyle(teal)
                                Text(tide.type == .high ? "High" : "Low")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                            }

                            Text(tide.timestamp, style: .relative)
                                .font(.title3.weight(.bold).monospacedDigit())
                                .foregroundStyle(.white)

                            Text(String(format: "%.2f m", tide.heightMeters))
                                .font(.caption)
                                .foregroundStyle(teal)
                        } else {
                            Text("No tide data")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                            Text("Open app to load")
                                .font(.caption2)
                                .foregroundStyle(.gray.opacity(0.7))
                        }
                    }

                    Spacer()
                }
            }
        }
        .containerBackground(.black, for: .widget)
    }

    private var truncatedStationName: String {
        let name = entry.stationName
        return name.count > 20 ? String(name.prefix(18)) + "\u{2026}" : name
    }
}

// MARK: - Widget

struct TideWidget: Widget {
    let kind = "TideWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TideProvider()) { entry in
            TideWidgetView(entry: entry)
        }
        .configurationDisplayName("Tide Engine")
        .description("Current gravitational pull and next tide.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
