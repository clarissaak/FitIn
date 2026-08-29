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
    @Published private(set) var weeklyStepsPoints: [MemberTrendPoint] = []
    @Published private(set) var weeklyHeartRatePoints: [MemberTrendPoint] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let sheetsService = SheetsService.shared
    private let trendDayCount = 7

    func refresh(spreadsheetId: String) async {
        guard !isLoading else { return }

        errorMessage = nil
        isLoading = true

        await DailyUploadCoordinator.shared.uploadTodayIfNeeded(spreadsheetId: spreadsheetId)

        do {
            let users = try await sheetsService.fetchUsers(spreadsheetId: spreadsheetId)
            let nameByEmail = Dictionary(uniqueKeysWithValues: users.map { ($0.email, $0.name) })
            let allSteps = try await sheetsService.fetchAllSteps(spreadsheetId: spreadsheetId)
            let allHeartRate = try await sheetsService.fetchAllHeartRate(spreadsheetId: spreadsheetId)

            let today = SheetsService.dateFormatter.string(from: Date())

            rows = users.map { user in
                let steps = allSteps.first(where: { $0.email == user.email && $0.date == today })?.steps ?? 0
                let elevated = allHeartRate.first(where: { $0.email == user.email && $0.date == today })?.elevatedHRMinutes ?? 0
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

            weeklyStepsPoints = recentPoints(
                from: allSteps.map { ($0.email, $0.date, Double($0.steps)) },
                nameByEmail: nameByEmail
            )
            weeklyHeartRatePoints = recentPoints(
                from: allHeartRate.map { ($0.email, $0.date, $0.elevatedHRMinutes) },
                nameByEmail: nameByEmail
            )
        } catch {
            if (error as NSError).code == NSURLErrorCancelled || error is CancellationError {
                isLoading = false
                return
            }
            errorMessage = "Couldn't refresh. Pull down to try again."
        }

        isLoading = false
    }

    // Filters to an actual trailing calendar-day window (today minus 6 days
    // through today)
    private func recentPoints(
        from raw: [(email: String, date: String, value: Double)],
        nameByEmail: [String: String]
    ) -> [MemberTrendPoint] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        guard let cutoff = calendar.date(byAdding: .day, value: -(trendDayCount - 1), to: startOfToday) else {
            return []
        }

        let byEmail = Dictionary(grouping: raw, by: { $0.email })

        let points = byEmail.flatMap { email, entries -> [MemberTrendPoint] in
            guard let displayName = nameByEmail[email] else { return [] }
            var byDate: [String: Double] = [:]
            for entry in entries {
                byDate[entry.date] = entry.value
            }

            return byDate.compactMap { dateString, value -> MemberTrendPoint? in
                guard let date = SheetsService.dateFormatter.date(from: dateString), date >= cutoff else {
                    return nil
                }
                return MemberTrendPoint(email: email, displayName: displayName, date: date, value: value)
            }
        }

        return points.sorted {
            if $0.displayName != $1.displayName {
                return $0.displayName < $1.displayName
            }
            return $0.date < $1.date
        }
    }
}
