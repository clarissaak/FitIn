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

    private enum ActiveField {
        case height
        case weight
    }

    @State private var birthDate = Date()
    @State private var sex = ""
    @State private var heightFeet = 5
    @State private var heightInches = 6
    @State private var weight = 150

    @State private var activeField: ActiveField? = nil

    @State private var isChecking = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isChecking {
                ProgressView()
            } else {
                VStack(spacing: 0) {
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
                        }

                        Section {
                            Button {
                                selectField(.height)
                            } label: {
                                LabeledContent("Height", value: "\(heightFeet) ft \(heightInches) in")
                            }
                            .foregroundStyle(.primary)

                            Button {
                                selectField(.weight)
                            } label: {
                                LabeledContent("Weight", value: "\(weight) lb")
                            }
                            .foregroundStyle(.primary)
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

                    if let activeField {
                        Divider()
                        Group {
                            switch activeField {
                            case .height:
                                heightWheel
                            case .weight:
                                weightWheel
                            }
                        }
                        .frame(height: 220)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.default, value: activeField)
            }
        }
        .task {
            await checkExistingHealthDetails()
        }
    }

    private func selectField(_ field: ActiveField) {
        // Tapping the already-open field collapses the wheel; tapping the
        // other field swaps to it.
        activeField = (activeField == field) ? nil : field
    }

    // Height wheel: feet | inches, edits the bound values live as it spins.
    private var heightWheel: some View {
        HStack(spacing: 0) {
            Picker("Feet", selection: $heightFeet) {
                ForEach(3...7, id: \.self) { value in
                    Text("\(value) ft").tag(value)
                }
            }
            .pickerStyle(.wheel)

            Picker("Inches", selection: $heightInches) {
                ForEach(0...11, id: \.self) { value in
                    Text("\(value) in").tag(value)
                }
            }
            .pickerStyle(.wheel)
        }
        .labelsHidden()
        .padding(.top, 8)
    }

    // Weight wheel: single lb column, edits the bound value live as it spins.
    private var weightWheel: some View {
        Picker("Weight", selection: $weight) {
            ForEach(50...400, id: \.self) { value in
                Text("\(value) lb").tag(value)
            }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
        .padding(.top, 8)
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

                let totalHeightInches = Double(heightFeet * 12 + heightInches)

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
                    weightLbs: Double(weight)
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
