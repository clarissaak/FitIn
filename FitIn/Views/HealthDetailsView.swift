//
//  HealthDetailsView.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 8/12/26.
//
import SwiftUI
import UIKit

// Lets the user view and edit all their health details in one place:
// birth date, biological sex, height, and weight.
struct HealthDetailsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var groupSetupViewModel: GroupSetupViewModel

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

    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Form {
                if isLoading {
                    Section {
                        ProgressView()
                    }
                } else {
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
                            Task { await save() }
                        } label: {
                            if isSaving {
                                ProgressView().frame(maxWidth: .infinity)
                            } else {
                                Text("Save").frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(isSaving)
                    }
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
                .background(Color(.systemBackground))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.default, value: activeField)
        .navigationTitle("Health Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
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

    private func load() async {
        guard let spreadsheetId = groupSetupViewModel.currentGroup?.spreadsheetId,
              let email = authViewModel.currentUser?.email else {
            isLoading = false
            return
        }
        do {
            let users = try await SheetsService.shared.fetchUsers(spreadsheetId: spreadsheetId)
            if let existing = users.first(where: { $0.email == email }) {
                if !existing.birthDate.isEmpty, let parsed = SheetsService.dateFormatter.date(from: existing.birthDate) {
                    birthDate = parsed
                }
                sex = existing.sex
                if existing.heightInches > 0 {
                    heightFeet = Int(existing.heightInches) / 12
                    heightInches = Int(existing.heightInches) % 12
                }
                if existing.weightLbs > 0 {
                    weight = Int(existing.weightLbs.rounded())
                }
            }
        } catch {
            errorMessage = "Couldn't load health details."
        }
        isLoading = false
    }

    private func save() async {
        guard let spreadsheetId = groupSetupViewModel.currentGroup?.spreadsheetId,
              let currentUser = authViewModel.currentUser else { return }
        errorMessage = nil
        isSaving = true
        do {
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
        } catch {
            errorMessage = "Couldn't save. Please try again."
        }
        isSaving = false
    }
}

#Preview {
    NavigationStack {
        HealthDetailsView()
            .environmentObject(AuthViewModel())
            .environmentObject(GroupSetupViewModel())
    }
}
