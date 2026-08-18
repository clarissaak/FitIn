//
//  DailyUploadCoordinator.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 8/17/26.
//
import Foundation

// Uploads today's HealthKit data (steps + elevated heart rate minutes) to
// Sheets. Both SummaryView and DashboardView trigger refreshes that each
// want to do this upload — without coordination, two near-simultaneous
// calls can both read "no row for today yet" and both append, creating
// duplicate rows. This coordinator serializes uploads: if one is already
// in flight, callers await that same one instead of starting a new one.
@MainActor
final class DailyUploadCoordinator {

    static let shared = DailyUploadCoordinator()

    private init() {}

    private var inFlightTask: Task<Void, Never>?
    private var inFlightSpreadsheetId: String?

    // Uploads today's steps + elevated heart rate minutes for the current
    // user, if no upload for this spreadsheet is already running. Safe to
    // call from multiple views without risking duplicate rows.
    func uploadTodayIfNeeded(spreadsheetId: String) async {
        if let inFlightTask, inFlightSpreadsheetId == spreadsheetId {
            await inFlightTask.value
            return
        }

        let task = Task {
            await Self.performUpload(spreadsheetId: spreadsheetId)
        }
        inFlightTask = task
        inFlightSpreadsheetId = spreadsheetId

        await task.value

        inFlightTask = nil
        inFlightSpreadsheetId = nil
    }

    private static func performUpload(spreadsheetId: String) async {
        guard let currentUser = GoogleAuthService.shared.currentUser else { return }
        let email = currentUser.email ?? "unknown"

        do {
            let users = try await SheetsService.shared.fetchUsers(spreadsheetId: spreadsheetId)
            let threshold = users.first(where: { $0.email == email })?.heartRateGoal ?? User.defaultHeartRateGoal

            let stepCount = try await HealthKitService.shared.todaysSteps()
            let elevatedMinutes = try await HealthKitService.shared.elevatedHeartRateMinutesToday(threshold: Double(threshold))

            let today = SheetsService.dateFormatter.string(from: Date())

            try await SheetsService.shared.upsertTodaySteps(
                spreadsheetId: spreadsheetId,
                steps: DailySteps(date: today, email: email, steps: Int(stepCount))
            )
            try await SheetsService.shared.upsertTodayHeartRate(
                spreadsheetId: spreadsheetId,
                metric: DailyHeartRate(date: today, email: email, elevatedHRMinutes: elevatedMinutes)
            )
        } catch {
            // Upload failures here are non-fatal — each view's own refresh
            // will still show whatever was already on the sheet, and the
            // next successful upload will catch up.
        }
    }
}
