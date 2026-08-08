//
//  DashboardView.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 8/6/26.
//
import SwiftUI

// Main dashboard: a list of group members with today's steps and elevated
// heart rate minutes, each with a clear met/not-met indicator. Pull down
// to refresh (also re-uploads the current user's latest HealthKit data).
struct DashboardView: View {
    @EnvironmentObject var groupSetupViewModel: GroupSetupViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var dashboardViewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage = dashboardViewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                ForEach(dashboardViewModel.rows) { row in
                    NavigationLink {
                        if let spreadsheetId = groupSetupViewModel.currentGroup?.spreadsheetId {
                            TrendsView(email: row.email, displayName: row.displayName, spreadsheetId: spreadsheetId)
                        }
                    } label: {
                        memberRow(row)
                    }
                }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink("Debug") {
                        SheetsTestView()
                    }
                    .font(.footnote)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        if let currentUser = authViewModel.currentUser, let spreadsheetId = groupSetupViewModel.currentGroup?.spreadsheetId {
                            NavigationLink("My Trends") {
                                TrendsView(email: currentUser.email ?? "", displayName: "My Trends", spreadsheetId: spreadsheetId)
                            }
                        }
                        NavigationLink("Goals") {
                            GoalSettingView()
                        }
                    }
                }
            }
            .refreshable {
                await refresh()
            }
            .task {
                await refresh()
            }
            .overlay {
                if dashboardViewModel.isLoading && dashboardViewModel.rows.isEmpty {
                    ProgressView()
                }
            }
        }
    }

    private func refresh() async {
        guard let spreadsheetId = groupSetupViewModel.currentGroup?.spreadsheetId else { return }
        await dashboardViewModel.refresh(spreadsheetId: spreadsheetId)
    }

    private func memberRow(_ row: Dashboard) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(row.displayName)
                .font(.headline)

            metricLine(
                icon: "figure.walk",
                label: "Steps",
                current: "\(row.currentSteps)",
                goal: "\(row.stepGoal)",
                met: row.stepsMet,
                remainingText: row.stepsMet ? nil : "\(row.stepsRemaining) to go"
            )

            metricLine(
                icon: "heart.fill",
                label: "Elevated HR",
                current: "\(Int(row.currentElevatedMinutes)) min",
                goal: "\(Int(row.elevatedMinutesGoal)) min",
                met: row.heartRateMet,
                remainingText: row.heartRateMet ? nil : "\(Int(row.elevatedMinutesRemaining)) min to go"
            )
        }
        .padding(.vertical, 4)
    }

    private func metricLine(icon: String, label: String, current: String, goal: String, met: Bool, remainingText: String?) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(label): \(current) / \(goal)")
                    .font(.subheadline)
                if let remainingText {
                    Text(remainingText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(met ? .green : .secondary)
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(GroupSetupViewModel())
        .environmentObject(AuthViewModel())
}
