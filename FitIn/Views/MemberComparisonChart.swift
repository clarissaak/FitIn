//
//  MemberComparisonChart.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 8/7/26.
//
import Charts
import SwiftUI

// One metric's chart in the group comparison card: one line (with point
// markers) per member, colored by name, over the trailing 7-day window.
struct MemberComparisonChart: View {
    let icon: String
    let title: String
    let color: Color
    let unit: String
    let points: [MemberTrendPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }

            if points.isEmpty {
                Text("No data yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Chart(points) { point in
                    LineMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value(unit, point.value)
                    )
                    .foregroundStyle(by: .value("Member", point.displayName))
                    .interpolationMethod(.monotone)

                    PointMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value(unit, point.value)
                    )
                    .foregroundStyle(by: .value("Member", point.displayName))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                }
                .frame(height: 180)
            }
        }
    }
}
