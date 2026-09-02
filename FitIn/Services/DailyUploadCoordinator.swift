//
//  DailyUploadCoordinator.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 8/17/26.
//
import Foundation

// Uploads HealthKit data (steps + elevated heart rate minutes) to Sheets.
// Foreground refreshes (SummaryView, DashboardView) upload just today;
// the background task uploads the last several days, so a day the app
// wasn't opened still gets backfilled once a sync does happen.
//
// Single-flight per spreadsheetId: an upload already in progress is
// awaited instead of duplicated, to avoid racing duplicate rows.
@MainActor
final class DailyUploadCoordinator {

    static let shared = DailyUploadCoordinator()

    private init() {}

    private var inFlightTask: Task<Void, Never>?
    private var inFlightSpreadsheetId: String?

    // Uploads just today's data. Called by SummaryView/DashboardView on
    // every appear/refresh.
    func uploadTodayIfNeeded(spreadsheetId: String) async {
        await uploadRecentDaysIfNeeded(spreadsheetId: spreadsheetId, dayCount: 1)
    }

    // Uploads the last `dayCount` days (today back through dayCount - 1
    // days ago), overwriting any existing rows for those dates. Called by
    // the background refresh task to catch up on days that were missed.
    func uploadRecentDaysIfNeeded(spreadsheetId: String, dayCount: Int) async {
        if let inFlightTask, inFlightSpreadsheetId == spreadsheetId {
            await inFlightTask.value
            return
        }

        let task = Task {
            await Self.performUpload(spreadsheetId: spreadsheetId, dayCount: dayCount)
        }
        inFlightTask = task
        inFlightSpreadsheetId = spreadsheetId

        await task.value

        inFlightTask = nil
        inFlightSpreadsheetId = nil
    }

    private static func performUpload(spreadsheetId: String, dayCount: Int) async {
        guard let currentUser = GoogleAuthService.shared.currentUser else { return }
        let email = currentUser.email ?? "unknown"

        do {
            let users = try await SheetsService.shared.fetchUsers(spreadsheetId: spreadsheetId)
            let threshold = users.first(where: { $0.email == email })?.heartRateGoal ?? User.defaultHeartRateGoal

            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: Date())

            // Sequential, not parallel, to avoid hammering the Sheets API
            // with concurrent read-before-write requests.
            for daysAgo in 0..<dayCount {
                guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: startOfToday) else { continue }

                let stepCount = try await HealthKitService.shared.steps(on: day)
                let elevatedMinutes = try await HealthKitService.shared.elevatedHeartRateMinutes(on: day, threshold: Double(threshold))

                let dateString = SheetsService.dateFormatter.string(from: day)

                try await SheetsService.shared.upsertTodaySteps(
                    spreadsheetId: spreadsheetId,
                    steps: DailySteps(date: dateString, email: email, steps: Int(stepCount))
                )
                try await SheetsService.shared.upsertTodayHeartRate(
                    spreadsheetId: spreadsheetId,
                    metric: DailyHeartRate(date: dateString, email: email, elevatedHRMinutes: elevatedMinutes)
                )
            }
        } catch {
            // Non-fatal — views still show whatever's already on the
            // sheet, and the next successful upload will catch up.
        }
    }
}
