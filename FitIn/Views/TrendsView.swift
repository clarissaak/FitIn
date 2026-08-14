//
//  TrendsView.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 8/7/26.
//
import SwiftUI
import Charts

// Shows one member's steps and elevated heart rate minutes over time,
// each with a reference line for their goal and a simple trend label.
// Works for any member's email — used both for "my trends" and (once
// wired up from the dashboard) any other member's trends.
struct TrendsView: View {
    enum Metric {
        case steps
        case heartRate
    }

    let email: String
    var displayName: String = ""
    let spreadsheetId: String
    // nil shows both metrics (used for viewing another member's trends).
    // A specific metric shows just that one, in more detail (used when
    // tapping a Summary widget).
    var focusMetric: Metric? = nil

    @StateObject private var viewModel = TrendsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Picker("Range", selection: $viewModel.selectedRange) {
                    ForEach(TrendsViewModel.TimeRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if focusMetric == nil || focusMetric == .steps {
                    trendSection(
                        title: "Steps",
                        points: viewModel.stepsPoints,
                        goal: Double(viewModel.stepGoal),
                        trend: viewModel.stepsTrend,
                        valueFormatter: { "\(Int($0))" }
                    )
                }

                if focusMetric == nil || focusMetric == .heartRate {
                    trendSection(
                        title: "Elevated Heart Rate Minutes",
                        points: viewModel.heartRatePoints,
                        goal: viewModel.elevatedMinutesGoal,
                        trend: viewModel.heartRateTrend,
                        valueFormatter: { "\(Int($0)) min" }
                    )
                }
            }
            .padding()
        }
        .navigationTitle(navigationTitleText)
        .task {
            await viewModel.load(spreadsheetId: spreadsheetId, email: email)
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }

    private var navigationTitleText: String {
        switch focusMetric {
        case .steps: return "Steps"
        case .heartRate: return "Elevated Heart Rate"
        case nil: return displayName
        }
    }

    private func trendSection(
        title: String,
        points: [TrendPoint],
        goal: Double,
        trend: TrendsViewModel.Trend,
        valueFormatter: @escaping (Double) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                trendBadge(trend)
            }

            if points.isEmpty {
                Text("No data yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(points) { point in
                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value(title, point.value)
                        )
                        .interpolationMethod(.monotone)

                        PointMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value(title, point.value)
                        )
                    }
                    RuleMark(y: .value("Goal", goal))
                        .foregroundStyle(.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
                .frame(height: 180)

                if let latest = points.last {
                    Text("Latest: \(valueFormatter(latest.value)) · Goal: \(valueFormatter(goal))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func trendBadge(_ trend: TrendsViewModel.Trend) -> some View {
        let (text, icon, color): (String, String, Color) = {
            switch trend {
            case .improving: return ("Improving", "arrow.up.right", .green)
            case .declining: return ("Declining", "arrow.down.right", .red)
            case .steady: return ("Steady", "arrow.right", .secondary)
            case .notEnoughData: return ("Not enough data", "minus", .secondary)
            }
        }()

        return Label(text, systemImage: icon)
            .font(.caption.bold())
            .foregroundStyle(color)
    }
}

#Preview {
    NavigationStack {
        TrendsView(email: "preview@example.com", displayName: "Preview User", spreadsheetId: "preview")
    }
}
