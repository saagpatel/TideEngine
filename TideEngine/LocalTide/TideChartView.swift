import SwiftUI
import Charts

struct TideChartView: View {
    let hourlyCurve: [TideDataPoint]       // ~168 hourly points
    let extremes: [TidePrediction]          // ~28 hi/lo markers

    private let teal = Color(red: 0, green: 0.9, blue: 1.0)

    var body: some View {
        Chart {
            // Area fill under curve
            ForEach(hourlyCurve) { point in
                AreaMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Height", point.heightMeters)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [teal.opacity(0.3), teal.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            // Line on top
            ForEach(hourlyCurve) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Height", point.heightMeters)
                )
                .foregroundStyle(teal)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }

            // Hi/Lo extreme markers
            ForEach(extremes) { pred in
                PointMark(
                    x: .value("Time", pred.timestamp),
                    y: .value("Height", pred.heightMeters)
                )
                .foregroundStyle(pred.type == .high ? .white : teal.opacity(0.6))
                .symbolSize(pred.type == .high ? 40 : 30)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.gray.opacity(0.3))
                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    .foregroundStyle(.gray)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.gray.opacity(0.2))
                AxisValueLabel()
                    .foregroundStyle(.gray)
            }
        }
        .chartYAxisLabel("meters", alignment: .leading)
        .frame(height: 200)
    }
}
