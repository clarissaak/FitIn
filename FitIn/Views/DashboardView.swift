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
    @EnvironmentObject var notificationPreferences: NotificationPreferencesStore
    @StateObject private var dashboardViewModel = DashboardViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var isShowingGroupSettings = false

    var body: some View {
        NavigationStack {
            List {
                header
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                if let errorMessage = dashboardViewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(dashboardViewModel.rows) { row in
                        NavigationLink {
                            if let spreadsheetId = groupSetupViewModel.currentGroup?.spreadsheetId {
                                TrendsView(email: row.email, displayName: row.displayName, spreadsheetId: spreadsheetId)
                            }
                        } label: {
                            memberRow(row)
                        }
                    }

                    if !dashboardViewModel.isLoading && dashboardViewModel.rows.isEmpty && dashboardViewModel.errorMessage == nil {
                        VStack(spacing: 8) {
                            Image(systemName: "person.2")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No members yet")
                                .font(.headline)
                            Text("Invite others to your group, or pull down to refresh.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    }
                }
            }
            .compactListSectionSpacingIfAvailable()
            .navigationBarHidden(true)
            .sheet(isPresented: $isShowingGroupSettings) {
                GroupSettingsView()
            }
            .refreshable {
                await refresh()
            }
            .task {
                await refresh()
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    Task { await refresh() }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            Text("Sharing")
                .font(.largeTitle.bold())

            Spacer()

            Button {
                isShowingGroupSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.title)
            }
        }
    }

    private func refresh() async {
        guard let spreadsheetId = groupSetupViewModel.currentGroup?.spreadsheetId else { return }
        await dashboardViewModel.refresh(spreadsheetId: spreadsheetId)
        await NotificationService.shared.rescheduleMissedGoalNotifications(
            rows: dashboardViewModel.rows,
            preferences: notificationPreferences
        )
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
        .environmentObject(NotificationPreferencesStore())
}

private extension View {
    // .listSectionSpacing is iOS 17+; this no-ops on iOS 16 rather than
    // failing to compile, since the app's deployment target is 16.
    @ViewBuilder
    func compactListSectionSpacingIfAvailable() -> some View {
        if #available(iOS 17.0, *) {
            self.listSectionSpacing(.compact)
        } else {
            self
        }
    }
}
