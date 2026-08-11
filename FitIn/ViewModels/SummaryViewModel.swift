//
//  SummaryViewModel.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 8/7/26.
//
import Foundation
import Combine

// Drives the Summary tab: uploads today's HealthKit data (same as the
// dashboard refresh), then loads a short recent history per metric for
// the widget sparklines.
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
    private let healthKitService = HealthKitService.shared

    private let sparklineDayCount = 7

    func refresh(spreadsheetId: String) async {
        // Prevent overlapping refreshes — e.g. the initial .task load and a
        // near-simultaneous scenePhase-triggered refresh on launch — which
        // otherwise race and cancel each other's in-flight requests.
        guard !isLoading else { return }

        errorMessage = nil
        isLoading = true

        do {
            guard let currentUser = GoogleAuthService.shared.currentUser else {
                isLoading = false
                return
            }
            let email = currentUser.email ?? "unknown"

            var heartRateThreshold = User.defaultHeartRateGoal
            let users = try await sheetsService.fetchUsers(spreadsheetId: spreadsheetId)
            if let user = users.first(where: { $0.email == email }) {
                stepGoal = user.stepsGoal
                elevatedMinutesGoal = user.elevatedMinutesGoal
                heartRateThreshold = user.heartRateGoal
            }

            let stepCount = try await healthKitService.todaysSteps()
            let elevatedMinutes = try await healthKitService.elevatedHeartRateMinutesToday(threshold: Double(heartRateThreshold))

            let today = SheetsService.dateFormatter.string(from: Date())

            try await sheetsService.upsertTodaySteps(
                spreadsheetId: spreadsheetId,
                steps: DailySteps(date: today, email: email, steps: Int(stepCount))
            )
            try await sheetsService.upsertTodayHeartRate(
                spreadsheetId: spreadsheetId,
                metric: DailyHeartRate(date: today, email: email, elevatedHRMinutes: elevatedMinutes)
            )

            todaySteps = Int(stepCount)
            todayElevatedMinutes = elevatedMinutes

            let allSteps = try await sheetsService.fetchAllSteps(spreadsheetId: spreadsheetId)
            let allHeartRate = try await sheetsService.fetchAllHeartRate(spreadsheetId: spreadsheetId)

            stepsSparkline = recentPoints(from: allSteps.filter { $0.email == email }.map { ($0.date, Double($0.steps)) })
            heartRateSparkline = recentPoints(from: allHeartRate.filter { $0.email == email }.map { ($0.date, $0.elevatedHRMinutes) })
        } catch {
            // A cancelled request (e.g. from SwiftUI's .task being torn down
            // and restarted during normal view lifecycle changes) isn't a
            // real failure — the next refresh will succeed. Don't show it
            // as an error.
            if (error as NSError).code == NSURLErrorCancelled || error is CancellationError {
                isLoading = false
                return
            }
            print("SummaryViewModel refresh error: \(error)")
            errorMessage = "Couldn't refresh. Pull down to try again."
        }

        isLoading = false
    }

    private func recentPoints(from raw: [(String, Double)]) -> [TrendPoint] {
        raw
            .compactMap { dateString, value -> TrendPoint? in
                guard let date = SheetsService.dateFormatter.date(from: dateString) else { return nil }
                return TrendPoint(dateString: dateString, date: date, value: value)
            }
            .sorted { $0.date < $1.date }
            .suffix(sparklineDayCount)
            .map { $0 }
    }
}
