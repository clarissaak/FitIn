//
//  GroupSettingsView.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 8/28/26.
//
import SwiftUI

// Group-level settings, reached from the Sharing tab. Currently just
// holds Leave Group, with a confirmation before actually leaving.
struct GroupSettingsView: View {
    @EnvironmentObject var groupSetupViewModel: GroupSetupViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isShowingLeaveConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button("Leave Group", role: .destructive) {
                        isShowingLeaveConfirmation = true
                    }
                } footer: {
                    Text("You'll need to be re-invited or approved again to rejoin this group.")
                }
            }
            .navigationTitle("Group Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Leave this group?",
                isPresented: $isShowingLeaveConfirmation,
                titleVisibility: .visible
            ) {
                Button("Leave Group", role: .destructive) {
                    groupSetupViewModel.leaveGroup()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

#Preview {
    GroupSettingsView()
        .environmentObject(GroupSetupViewModel())
}
