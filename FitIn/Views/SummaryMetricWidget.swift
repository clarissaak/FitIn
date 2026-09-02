//
//  SummaryMetricWidget.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 8/7/26.
//
import SwiftUI
import Charts

// A single metric "widget" card, styled after Apple Fitness's Summary
// tab widgets: icon + title, big current value vs goal, a progress bar,
// and a small weekly line chart with colored dots for each day.
struct SummaryMetricWidget: View {
    let icon: String
    let title: String
    let color: Color
    let currentValueText: String
    let goalText: String
    let progress: Double // 0...1
    let points: [TrendPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(currentValueText)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("/ \(goalText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: min(progress, 1))
                .tint(color)

            if points.count >= 2 {
                Chart {
                    ForEach(points) { point in
                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value(title, point.value)
                        )
                        .foregroundStyle(color)
                        .interpolationMethod(.monotone)

                        PointMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value(title, point.value)
                        )
                        .foregroundStyle(color)
                    }
                }
                .frame(height: 48)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    SummaryMetricWidget(
        icon: "figure.walk",
        title: "Steps",
        color: .green,
        currentValueText: "6,482",
        goalText: "10,000",
        progress: 0.65,
        points: (0..<7).map {
            TrendPoint(dateString: "\($0)", date: Date().addingTimeInterval(Double($0) * 86400), value: Double.random(in: 2000...10000))
        }
    )
    .padding()
}
