//
//  HealthDetailsSettingView.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 7/29/26.
//
import SwiftUI

// Shown once, during onboarding, to collect the user's birth date, sex,
// height, and weight. Checks the user's existing row first — if a birth
// date is already saved, this view completes immediately without showing
// any UI.
struct HealthDetailsSettingView: View {
    let spreadsheetId: String
    var onComplete: () -> Void

    private let sexOptions = ["Female", "Male", "Other"]

    @State private var birthDate = Date()
    @State private var sex = ""
    @State private var heightFeet = 5
    @State private var heightRemainderInches = 6
    @State private var weightLbs: Double = 150

    @State private var isChecking = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isChecking {
                ProgressView()
            } else {
                Form {
                    Section {
                        Text("Tell us about yourself")
                            .font(.title2.bold())
                        Text("Used to personalize your goals and heart rate range. Stored once, editable later from your account.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    Section {
                        DatePicker("Birth Date", selection: $birthDate, in: ...Date(), displayedComponents: .date)

                        Picker("Sex", selection: $sex) {
                            Text("Not Set").tag("")
                            ForEach(sexOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }

                        Stepper("Height: \(heightFeet) ft \(heightRemainderInches) in", value: $heightFeet, in: 3...7)

                        Stepper("Adjust inches: \(heightRemainderInches)", value: $heightRemainderInches, in: 0...11)

                        Stepper("Weight: \(Int(weightLbs)) lb", value: $weightLbs, in: 50...400, step: 1)
                    }

                    if let errorMessage {
                        Section {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }

                    Section {
                        Button {
                            save()
                        } label: {
                            if isSaving {
                                ProgressView().frame(maxWidth: .infinity)
                            } else {
                                Text("Continue").frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(isSaving)
                    }
                }
            }
        }
        .task {
            await checkExistingHealthDetails()
        }
    }

    private func checkExistingHealthDetails() async {
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

                let totalHeightInches = Double(heightFeet * 12 + heightRemainderInches)

                let updatedUser = User(
                    email: email,
                    name: existing?.name ?? currentUser.name ?? "unknown",
                    sub: existing?.sub ?? currentUser.sub,
                    joinedDate: existing?.joinedDate ?? SheetsService.dateFormatter.string(from: Date()),
                    birthDate: SheetsService.dateFormatter.string(from: birthDate),
                    stepsGoal: existing?.stepsGoal ?? User.defaultStepsGoal,
                    heartRateGoal: existing?.heartRateGoal ?? User.defaultHeartRateGoal,
                    elevatedMinutesGoal: existing?.elevatedMinutesGoal ?? User.defaultElevatedMinutesGoal,
                    sex: sex,
                    heightInches: totalHeightInches,
                    weightLbs: weightLbs
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
    HealthDetailsSettingView(spreadsheetId: "preview", onComplete: {})
}
