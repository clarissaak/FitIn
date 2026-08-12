//
//  AccountView.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 8/10/26.
//
import SwiftUI

// Presented as a sheet from the account icon: account info, health
// details + goals, notification settings, and sign out.
struct AccountView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

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

                // Health details + goals together
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
    }
}

#Preview {
    AccountView()
        .environmentObject(AuthViewModel())
        .environmentObject(GroupSetupViewModel())
}
