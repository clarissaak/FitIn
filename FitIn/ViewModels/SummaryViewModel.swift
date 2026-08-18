//
//  SummaryViewModel.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 8/7/26.
//
import Foundation
import Combine

// Drives the Summary tab: uploads today's HealthKit data (via the shared
// DailyUploadCoordinator, so concurrent refreshes from other views don't
// race and create duplicate rows), then loads a short recent history per
// metric for the widget sparklines.
@MainActor
final class SummaryViewModel: ObservableObject {

    @Published private(set) var todaySteps: Int = 0
    @Published private(set) var stepGoal: Int = User.defaultStepsGoal
    @Published private(set) var stepsSparkline: [TrendPoint] = []

    @Published private(set) var todayElevatedMinutes: Double = 0
    @Published private(set) var elevatedMinutesGoal: Double = User.defaultElevatedMinutesGoal
    @Published private(set) var heartRateSparkline: [TrendPoint] = []

    @Published var isLoading = false
    @Published var errorMessage: String?

    private let sheetsService = SheetsService.shared

    private let sparklineDayCount = 7

    func refresh(spreadsheetId: String) async {
        guard !isLoading else { return }

        errorMessage = nil
        isLoading = true

        await DailyUploadCoordinator.shared.uploadTodayIfNeeded(spreadsheetId: spreadsheetId)

        do {
            guard let email = GoogleAuthService.shared.currentUser?.email else {
                isLoading = false
                return
            }

            let users = try await sheetsService.fetchUsers(spreadsheetId: spreadsheetId)
            if let user = users.first(where: { $0.email == email }) {
                stepGoal = user.stepsGoal
                elevatedMinutesGoal = user.elevatedMinutesGoal
            }

            let allSteps = try await sheetsService.fetchAllSteps(spreadsheetId: spreadsheetId)
            let allHeartRate = try await sheetsService.fetchAllHeartRate(spreadsheetId: spreadsheetId)

            let mySteps = allSteps.filter { $0.email == email }
            let myHeartRate = allHeartRate.filter { $0.email == email }

            let today = SheetsService.dateFormatter.string(from: Date())
            todaySteps = mySteps.first(where: { $0.date == today })?.steps ?? 0
            todayElevatedMinutes = myHeartRate.first(where: { $0.date == today })?.elevatedHRMinutes ?? 0

            stepsSparkline = recentPoints(from: mySteps.map { ($0.date, Double($0.steps)) })
            heartRateSparkline = recentPoints(from: myHeartRate.map { ($0.date, $0.elevatedHRMinutes) })
        } catch {
            if (error as NSError).code == NSURLErrorCancelled || error is CancellationError {
                isLoading = false
                return
            }
            errorMessage = "Couldn't refresh. Pull down to try again."
        }

        isLoading = false
    }

    private func recentPoints(from raw: [(String, Double)]) -> [TrendPoint] {
        // Dedupe by date first (defensive — a stray duplicate row shouldn't
        // throw off the sparkline), keeping the last entry per date.
        var byDate: [String: Double] = [:]
        for (dateString, value) in raw {
            byDate[dateString] = value
        }

        return byDate
            .compactMap { dateString, value -> TrendPoint? in
                guard let date = SheetsService.dateFormatter.date(from: dateString) else { return nil }
                return TrendPoint(dateString: dateString, date: date, value: value)
            }
            .sorted { $0.date < $1.date }
            .suffix(sparklineDayCount)
            .map { $0 }
    }
}
