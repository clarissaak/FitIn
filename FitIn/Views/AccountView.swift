//
//  AccountView.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 8/10/26.
//
import SwiftUI

// Presented as a sheet from the account icon: account info, health
// details + goals, notification settings, and sign out
struct AccountView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var groupSetupViewModel: GroupSetupViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var birthDate = Date()
    @State private var isLoadingBirthDate = true
    @State private var isSavingBirthDate = false
    @State private var birthDateErrorMessage: String?
    @State private var isShowingSignOutConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let user = authViewModel.currentUser {
                        LabeledContent("Name", value: user.name ?? "—")
                        LabeledContent("Email", value: user.email ?? "—")
                    }
                }

                // Health details + goals section
                Section {
                    if isLoadingBirthDate {
                        ProgressView()
                    } else {
                        DatePicker("Birth Date", selection: $birthDate, in: ...Date(), displayedComponents: .date)
                        Button {
                            Task { await saveBirthDate() }
                        } label: {
                            if isSavingBirthDate {
                                ProgressView()
                            } else {
                                Text("Save Birth Date")
                            }
                        }
                        .disabled(isSavingBirthDate)
                    }
                    if let birthDateErrorMessage {
                        Text(birthDateErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    NavigationLink("Change Goals") {
                        GoalSettingView()
                    }
                }

                Section {
                    NavigationLink("Notifications") {
                        NotificationSettingsView()
                    }
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        isShowingSignOutConfirmation = true
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Sign out of FitIn?",
                isPresented: $isShowingSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    authViewModel.signOut()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .task {
            await loadBirthDate()
        }
    }

    private func loadBirthDate() async {
        guard let spreadsheetId = groupSetupViewModel.currentGroup?.spreadsheetId,
              let email = authViewModel.currentUser?.email else {
            isLoadingBirthDate = false
            return
        }
        do {
            let users = try await SheetsService.shared.fetchUsers(spreadsheetId: spreadsheetId)
            if let existing = users.first(where: { $0.email == email }),
               !existing.birthDate.isEmpty,
               let parsed = SheetsService.dateFormatter.date(from: existing.birthDate) {
                birthDate = parsed
            }
        } catch {
            birthDateErrorMessage = "Couldn't load birth date."
        }
        isLoadingBirthDate = false
    }

    private func saveBirthDate() async {
        guard let spreadsheetId = groupSetupViewModel.currentGroup?.spreadsheetId,
              let currentUser = authViewModel.currentUser else { return }
        birthDateErrorMessage = nil
        isSavingBirthDate = true
        do {
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
        } catch {
            birthDateErrorMessage = "Couldn't save. Please try again."
        }
        isSavingBirthDate = false
    }
}

#Preview {
    AccountView()
        .environmentObject(AuthViewModel())
        .environmentObject(GroupSetupViewModel())
}
