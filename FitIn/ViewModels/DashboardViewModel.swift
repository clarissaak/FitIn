//
//  DashboardViewModel.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 8/6/26.
//
import Foundation
import Combine

// Drives the dashboard: on appear / pull-to-refresh, reads today's steps
// and elevated heart rate minutes from HealthKit, upserts them for the
// current user, then fetches all members' goals and today's metrics to
// build the full set of rows.
@MainActor
final class DashboardViewModel: ObservableObject {

    @Published private(set) var rows: [Dashboard] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let sheetsService = SheetsService.shared
    private let healthKitService = HealthKitService.shared

    func refresh(spreadsheetId: String) async {
        guard !isLoading else { return }

        errorMessage = nil
        isLoading = true

        do {
            guard let currentUser = GoogleAuthService.shared.currentUser else {
                isLoading = false
                return
            }
            let email = currentUser.email ?? "unknown"

            // Need the current user's own heart rate threshold before
            // querying HealthKit, since the threshold is per-user.
            let users = try await sheetsService.fetchUsers(spreadsheetId: spreadsheetId)
            let myThreshold = users.first(where: { $0.email == email })?.heartRateGoal ?? User.defaultHeartRateGoal

            let stepCount = try await healthKitService.todaysSteps()
            let elevatedMinutes = try await healthKitService.elevatedHeartRateMinutesToday(threshold: Double(myThreshold))

            let today = SheetsService.dateFormatter.string(from: Date())

            try await sheetsService.upsertTodaySteps(
                spreadsheetId: spreadsheetId,
                steps: DailySteps(date: today, email: email, steps: Int(stepCount))
            )
            try await sheetsService.upsertTodayHeartRate(
                spreadsheetId: spreadsheetId,
                metric: DailyHeartRate(date: today, email: email, elevatedHRMinutes: elevatedMinutes)
            )

            let stepsToday = try await sheetsService.fetchTodaySteps(spreadsheetId: spreadsheetId)
            let heartRateToday = try await sheetsService.fetchTodayHeartRate(spreadsheetId: spreadsheetId)

            rows = users.map { user in
                let steps = stepsToday.first(where: { $0.email == user.email })?.steps ?? 0
                let elevated = heartRateToday.first(where: { $0.email == user.email })?.elevatedHRMinutes ?? 0
                return Dashboard(
                    email: user.email,
                    displayName: user.name,
                    currentSteps: steps,
                    stepGoal: user.stepsGoal,
                    currentElevatedMinutes: elevated,
                    elevatedMinutesGoal: user.elevatedMinutesGoal
                )
            }
            .sorted { $0.displayName < $1.displayName }
        } catch {
            if (error as NSError).code == NSURLErrorCancelled || error is CancellationError {
                isLoading = false
                return
            }
            errorMessage = "Couldn't refresh. Pull down to try again."
        }

        isLoading = false
    } 
}
