//
//  AccountView.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 8/10/26.
//
import SwiftUI

// Presented as a sheet from the account icon: account info, health
// details + goals, notification settings, group management (creator
// only), and sign out — styled after Apple Fitness's account/profile
// screen.
struct AccountView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var groupSetupViewModel: GroupSetupViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isShowingSignOutConfirmation = false
    @State private var isCreator = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let user = authViewModel.currentUser {
                        LabeledContent("Name", value: user.name ?? "—")
                        LabeledContent("Email", value: user.email ?? "—")
                    }
                }

                // Health details + goals together, matching Fitness's
                // account layout.
                Section {
                    NavigationLink("Health Details") {
                        HealthDetailsView()
                    }
                    NavigationLink("Edit Goals") {
                        GoalSettingView()
                    }
                } header: {
                    Text("Health Details & Goals")
                }

                Section {
                    NavigationLink("Notifications") {
                        NotificationSettingsView()
                    }
                } header: {
                    Text("Notifications")
                }

                if isCreator {
                    Section {
                        NavigationLink("Pending Requests") {
                            PendingRequestsView()
                        }
                    } header: {
                        Text("Group Management")
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
            if let spreadsheetId = groupSetupViewModel.currentGroup?.spreadsheetId {
                isCreator = await GroupService.shared.isCurrentUserCreator(spreadsheetId: spreadsheetId)
            }
        }
    }
}

#Preview {
    AccountView()
        .environmentObject(AuthViewModel())
        .environmentObject(GroupSetupViewModel())
}
