//
//  AwaitingApprovalView.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 8/26/26.
//
import SwiftUI

// Shown after submitting a join request, until the group's creator
// approves it. Pull to refresh checks whether approval has happened yet.
struct AwaitingApprovalView: View {
    @EnvironmentObject var groupSetupViewModel: GroupSetupViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 80)

                    Image(systemName: "hourglass")
                        .font(.system(size: 56))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 8) {
                        Text("Waiting for Approval")
                            .font(.title2.bold())
                        Text("The group creator needs to approve your request before you can join. Pull down to check again.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    Button("Cancel Request", role: .destructive) {
                        groupSetupViewModel.leaveGroup()
                    }
                    .padding(.top, 8)

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .refreshable {
                await refresh()
            }
            .task {
                await refresh()
            }
        }
    }

    private func refresh() async {
        guard let spreadsheetId = groupSetupViewModel.currentGroup?.spreadsheetId else { return }
        await groupSetupViewModel.refreshApprovalStatus(spreadsheetId: spreadsheetId)
    }
}

#Preview {
    AwaitingApprovalView()
        .environmentObject(GroupSetupViewModel())
}
