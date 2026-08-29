//
//  NotificationSettingsView.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 8/11/26.
//
import SwiftUI

// Lets the user turn missed-goal notifications on/off globally, and
// individually per group member. Defaults to on for everyone.
struct NotificationSettingsView: View {
    @EnvironmentObject var groupSetupViewModel: GroupSetupViewModel
    @EnvironmentObject var preferences: NotificationPreferencesStore

    @State private var members: [User] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Toggle("Missed Goals", isOn: $preferences.allEnabled)
                    .onChange(of: preferences.allEnabled) { oldValue, newValue in
                        if newValue {
                            Task { await NotificationService.shared.requestAuthorization() }
                        }
                    }
            }

            if preferences.allEnabled {
                Section("Members") {
                    if isLoading {
                        ProgressView()
                    } else if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    } else {
                        ForEach(members) { member in
                            Toggle(member.name, isOn: Binding(
                                get: { preferences.isEnabled(for: member.email) },
                                set: { preferences.setEnabled($0, for: member.email) }
                            ))
                        }
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .task {
            await loadMembers()
        }
    }

    private func loadMembers() async {
        guard let spreadsheetId = groupSetupViewModel.currentGroup?.spreadsheetId else {
            isLoading = false
            return
        }
        do {
            members = try await SheetsService.shared.fetchUsers(spreadsheetId: spreadsheetId)
        } catch {
            errorMessage = "Couldn't load members."
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
            .environmentObject(GroupSetupViewModel())
            .environmentObject(NotificationPreferencesStore())
    }
}
