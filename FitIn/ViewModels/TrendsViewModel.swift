//
//  TrendsViewModel.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 8/7/26.
//
import Foundation
import Combine

// Loads one member's full history of steps and elevated heart rate
// minutes, alongside their goals, and computes a simple trend direction
// for each metric (improving / declining / steady) within the currently
// selected time range.
@MainActor
final class TrendsViewModel: ObservableObject {

    enum Trend {
        case improving
        case declining
        case steady
        case notEnoughData
    }

    enum TimeRange: String, CaseIterable, Identifiable {
        case week = "W"
        case month = "M"
        case sixMonths = "6M"
        case year = "Y"

        var id: String { rawValue }

        var dayCount: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .sixMonths: return 182
            case .year: return 365
            }
        }
    }

    @Published var selectedRange: TimeRange = .week

    @Published private(set) var stepGoal = User.defaultStepsGoal
    @Published private(set) var elevatedMinutesGoal = User.defaultElevatedMinutesGoal

    @Published var isLoading = false
    @Published var errorMessage: String?

    // Full, unfiltered history — loaded once. stepsPoints / heartRatePoints
    // below are what the view actually reads, filtered to selectedRange.
    private var allStepsPoints: [TrendPoint] = []
    private var allHeartRatePoints: [TrendPoint] = []

    private let sheetsService = SheetsService.shared

    var stepsPoints: [TrendPoint] {
        filtered(allStepsPoints)
    }

    var heartRatePoints: [TrendPoint] {
        filtered(allHeartRatePoints)
    }

    var stepsTrend: Trend {
        trend(for: stepsPoints)
    }

    var heartRateTrend: Trend {
        trend(for: heartRatePoints)
    }

    func load(spreadsheetId: String, email: String) async {
        errorMessage = nil
        isLoading = true

        do {
            let users = try await sheetsService.fetchUsers(spreadsheetId: spreadsheetId)
            if let user = users.first(where: { $0.email == email }) {
                stepGoal = user.stepsGoal
                elevatedMinutesGoal = user.elevatedMinutesGoal
            }

            let allSteps = try await sheetsService.fetchAllSteps(spreadsheetId: spreadsheetId)
            let allHeartRate = try await sheetsService.fetchAllHeartRate(spreadsheetId: spreadsheetId)

            allStepsPoints = allSteps
                .filter { $0.email == email }
                .compactMap { entry -> TrendPoint? in
                    guard let date = SheetsService.dateFormatter.date(from: entry.date) else { return nil }
                    return TrendPoint(dateString: entry.date, date: date, value: Double(entry.steps))
                }
                .sorted { $0.date < $1.date }

            allHeartRatePoints = allHeartRate
                .filter { $0.email == email }
                .compactMap { entry -> TrendPoint? in
                    guard let date = SheetsService.dateFormatter.date(from: entry.date) else { return nil }
                    return TrendPoint(dateString: entry.date, date: date, value: entry.elevatedHRMinutes)
                }
                .sorted { $0.date < $1.date }
        } catch {
            errorMessage = "Couldn't load trend data."
        }

        isLoading = false
    }

    private func filtered(_ points: [TrendPoint]) -> [TrendPoint] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -selectedRange.dayCount, to: Date()) else {
            return points
        }
        return points.filter { $0.date >= cutoff }
    }

    // Simple trend heuristic: compares the average of the first half of
    // points against the second half, within the selected range. Needs
    // at least 4 points to say anything more specific than "not enough
    // data" — fewer than that is too noisy to call a real trend.
    private func trend(for points: [TrendPoint]) -> Trend {
        guard points.count >= 4 else { return .notEnoughData }

        let midpoint = points.count / 2
        let firstHalf = points[0..<midpoint]
        let secondHalf = points[midpoint...]

        let firstAverage = firstHalf.map(\.value).reduce(0, +) / Double(firstHalf.count)
        let secondAverage = secondHalf.map(\.value).reduce(0, +) / Double(secondHalf.count)

        let percentChange = firstAverage == 0 ? 0 : (secondAverage - firstAverage) / firstAverage

        if percentChange > 0.05 {
            return .improving
        } else if percentChange < -0.05 {
            return .declining
        } else {
            return .steady
        }
    }
}
