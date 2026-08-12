//
//  GoalViewModel.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 7/29/26.
//
import Foundation
import Combine

// Holds the current user's goals (steps, heart rate threshold, elevated
// minutes target) and saves changes back to their row in the Users tab.
// Also computes an age-appropriate heart rate range using the birth date
// collected during onboarding, so the threshold goal has realistic
// bounds instead of an arbitrary fixed range.
@MainActor
final class GoalViewModel: ObservableObject {

    @Published var stepsGoal: Int = User.defaultStepsGoal
    @Published var heartRateGoal: Int = User.defaultHeartRateGoal
    @Published var elevatedMinutesGoal: Double = User.defaultElevatedMinutesGoal

    @Published private(set) var age: Int?

    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let sheetsService = SheetsService.shared

    // Estimated maximum heart rate using the standard 220 - age formula.
    // nil if age isn't available.
    var estimatedMaxHeartRate: Int? {
        guard let age else { return nil }
        return 220 - age
    }

    // Recommended heart rate threshold range: roughly the moderate-to-
    // vigorous exercise target zone (50-85% of estimated max), per common
    // American Heart Association guidance. Falls back to a generic
    // fixed range if age isn't available.
    var heartRateRange: ClosedRange<Int> {
        guard let maxHR = estimatedMaxHeartRate else {
            return 80...200
        }
        let lower = Int(Double(maxHR) * 0.5)
        let upper = Int(Double(maxHR) * 0.85)
        guard lower < upper else { return 80...200 }
        return lower...upper
    }

    // Loads the signed-in user's current goals and birth date (for the
    // heart rate range) from their row in the Users tab. Falls back to
    // defaults if no row is found yet, or birth date isn't set.
    func loadGoals(spreadsheetId: String) async {
        errorMessage = nil
        isLoading = true

        do {
            guard let email = GoogleAuthService.shared.currentUser?.email else {
                isLoading = false
                return
            }
            let users = try await sheetsService.fetchUsers(spreadsheetId: spreadsheetId)
            if let existing = users.first(where: { $0.email == email }) {
                stepsGoal = existing.stepsGoal
                heartRateGoal = existing.heartRateGoal
                elevatedMinutesGoal = existing.elevatedMinutesGoal
                age = existing.age
            }
        } catch {
            errorMessage = "Couldn't load goals. Using defaults."
        }

        // Clamp the loaded/default heart rate goal into the age-based range,
        // so the stepper never starts outside its own bounds.
        heartRateGoal = min(max(heartRateGoal, heartRateRange.lowerBound), heartRateRange.upperBound)

        isLoading = false
    }

    // Saves the current goal values to the signed-in user's row in the
    // Users tab, keeping their existing name/sub/joinedDate/birthDate and
    // health details (sex/height/weight) intact.
    func saveGoals(spreadsheetId: String) async {
        errorMessage = nil
        isSaving = true
        do {
            guard let currentUser = GoogleAuthService.shared.currentUser else {
                isSaving = false
                return
            }
            let email = currentUser.email ?? "unknown"
            let existingUsers = try await sheetsService.fetchUsers(spreadsheetId: spreadsheetId)
            let existing = existingUsers.first(where: { $0.email == email })

            let updatedUser = User(
                email: email,
                name: existing?.name ?? currentUser.name ?? "unknown",
                sub: existing?.sub ?? currentUser.sub,
                joinedDate: existing?.joinedDate ?? SheetsService.dateFormatter.string(from: Date()),
                birthDate: existing?.birthDate ?? "",
                stepsGoal: stepsGoal,
                heartRateGoal: heartRateGoal,
                elevatedMinutesGoal: elevatedMinutesGoal,
                sex: existing?.sex ?? "",
                heightInches: existing?.heightInches ?? 0,
                weightLbs: existing?.weightLbs ?? 0
            )
            try await sheetsService.appendOrUpdateUser(spreadsheetId: spreadsheetId, user: updatedUser)
        } catch {
            errorMessage = "Couldn't save goals. Please try again."
        }
        isSaving = false
    }
}
