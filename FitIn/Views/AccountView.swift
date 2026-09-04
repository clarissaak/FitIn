//
//  AccountView.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 8/10/26.
//
import SwiftUI

// A tab in the main nav bar: account info, health details + goals,
// notification settings, group management (creator only), and sign out
// — styled after Apple Fitness's account/profile screen.
struct AccountView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var groupSetupViewModel: GroupSetupViewModel

    @State private var isShowingSignOutConfirmation = false
    @State private var isCreator = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink("Profile Details") {
                        ProfileDetailsView()
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
                }

                Section {
                    NavigationLink("Notifications") {
                        NotificationSettingsView()
                    }
                }

                if isCreator {
                    Section {
                        NavigationLink("Pending Requests") {
                            PendingRequestsView()
                        }
                    }
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        isShowingSignOutConfirmation = true
                    }
                }
            }
            .navigationTitle("Account")
            .confirmationDialog(
                "Sign out of FitIn?",
                isPresented: $isShowingSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    authViewModel.signOut()
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
