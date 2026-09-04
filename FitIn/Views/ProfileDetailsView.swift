//
//  ProfileDetailsView.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 9/3/26.
//
import SwiftUI

// Lets the user edit their display name (shown to other group members).
// Reached from Account.
struct ProfileDetailsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var groupSetupViewModel: GroupSetupViewModel

    @State private var name = ""
    @State private var originalName = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            if isLoading {
                Section {
                    ProgressView()
                }
            } else {
                Section {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Name", text: $name)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                    }
                    if let email = authViewModel.currentUser?.email {
                        LabeledContent("Email", value: email)
                    }
                } footer: {
                    Text("Your email is tied to your Google account and cannot be edited here.")
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
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty || name.trimmingCharacters(in: .whitespaces) == originalName)
                }
            }
        }
        .navigationTitle("Profile Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
    }

    private func load() async {
        guard let spreadsheetId = groupSetupViewModel.currentGroup?.spreadsheetId else {
            isLoading = false
            return
        }
        if let email = authViewModel.currentUser?.email,
           let users = try? await SheetsService.shared.fetchUsers(spreadsheetId: spreadsheetId),
           let existing = users.first(where: { $0.email == email }) {
            name = existing.name
            originalName = existing.name
        } else {
            name = authViewModel.currentUser?.name ?? ""
            originalName = name
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

            let trimmedName = name.trimmingCharacters(in: .whitespaces)
            let updatedUser = User(
                email: email,
                name: trimmedName,
                sub: existing?.sub ?? currentUser.sub,
                joinedDate: existing?.joinedDate ?? SheetsService.dateFormatter.string(from: Date()),
                birthDate: existing?.birthDate ?? "",
                stepsGoal: existing?.stepsGoal ?? User.defaultStepsGoal,
                heartRateGoal: existing?.heartRateGoal ?? User.defaultHeartRateGoal,
                elevatedMinutesGoal: existing?.elevatedMinutesGoal ?? User.defaultElevatedMinutesGoal,
                sex: existing?.sex ?? "",
                heightInches: existing?.heightInches ?? 0,
                weightLbs: existing?.weightLbs ?? 0
            )
            try await SheetsService.shared.appendOrUpdateUser(spreadsheetId: spreadsheetId, user: updatedUser)
            name = trimmedName
            originalName = trimmedName
        } catch {
            errorMessage = "Couldn't save. Please try again."
        }
        isSaving = false
    }
}

#Preview {
    NavigationStack {
        ProfileDetailsView()
            .environmentObject(AuthViewModel())
            .environmentObject(GroupSetupViewModel())
    }
}
