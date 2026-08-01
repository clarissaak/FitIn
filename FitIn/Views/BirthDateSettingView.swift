//
//  BirthDateSettingView.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 7/29/26.
//
import SwiftUI

// Shown once, during onboarding, to collect the user's birth date. Checks
// the user's existing row first — if a birth date is already saved, this
// view completes immediately without showing any UI.
struct BirthDateSettingView: View {
    let spreadsheetId: String
    var onComplete: () -> Void

    @State private var birthDate = Date()
    @State private var isChecking = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isChecking {
                ProgressView()
            } else {
                VStack(spacing: 24) {
                    Spacer()

                    VStack(spacing: 8) {
                        Text("When's your birthday?")
                            .font(.title2.bold())
                        Text("Used to personalize your heart rate goal range. Stored once, never asked again.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    DatePicker(
                        "Birth date",
                        selection: $birthDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .padding(.horizontal, 32)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Continue").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 32)
                    .disabled(isSaving)

                    Spacer()
                }
                .padding()
            }
        }
        .task {
            await checkExistingBirthDate()
        }
    }

    private func checkExistingBirthDate() async {
        guard let email = GoogleAuthService.shared.currentUser?.email else {
            isChecking = false
            return
        }
        do {
            let users = try await SheetsService.shared.fetchUsers(spreadsheetId: spreadsheetId)
            if let existing = users.first(where: { $0.email == email }), !existing.birthDate.isEmpty {
                // Already provided during a previous session — skip straight through.
                isChecking = false
                onComplete()
                return
            }
        } catch {
            // If the check fails, just show the picker rather than blocking onboarding.
        }
        isChecking = false
    }

    private func save() {
        errorMessage = nil
        isSaving = true
        Task {
            do {
                guard let currentUser = GoogleAuthService.shared.currentUser else {
                    errorMessage = "No signed-in user found."
                    isSaving = false
                    return
                }
                let email = currentUser.email ?? "unknown"
                let existingUsers = try await SheetsService.shared.fetchUsers(spreadsheetId: spreadsheetId)
                let existing = existingUsers.first(where: { $0.email == email })

                let updatedUser = User(
                    email: email,
                    name: existing?.name ?? currentUser.name ?? "unknown",
                    sub: existing?.sub ?? currentUser.sub,
                    joinedDate: existing?.joinedDate ?? SheetsService.dateFormatter.string(from: Date()),
                    birthDate: SheetsService.dateFormatter.string(from: birthDate),
                    stepsGoal: existing?.stepsGoal ?? User.defaultStepsGoal,
                    heartRateGoal: existing?.heartRateGoal ?? User.defaultHeartRateGoal,
                    elevatedMinutesGoal: existing?.elevatedMinutesGoal ?? User.defaultElevatedMinutesGoal
                )
                try await SheetsService.shared.appendOrUpdateUser(spreadsheetId: spreadsheetId, user: updatedUser)
                isSaving = false
                onComplete()
            } catch {
                errorMessage = "Couldn't save. Please try again."
                isSaving = false
            }
        }
    }
}

#Preview {
    BirthDateSettingView(spreadsheetId: "preview", onComplete: {})
}
