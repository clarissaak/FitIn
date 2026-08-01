//
//  SheetsTestView.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 7/23/26.
//
import SwiftUI
import UIKit

// Temporary debug view to manually trigger and verify each SheetsService
// call against the current group's spreadsheet. Replace with the real
// dashboard once that's designed.
struct SheetsTestView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var groupSetupViewModel: GroupSetupViewModel

    @State private var log: String = "No actions yet."
    @State private var isBusy = false

    // Always use the current group's spreadsheet, never a separate one.
    private var spreadsheetId: String? {
        groupSetupViewModel.currentGroup?.spreadsheetId
    }

    var body: some View {
        NavigationStack {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Sheets Test")
                    .font(.title2.bold())

                Button("Leave Group (debug)") {
                    groupSetupViewModel.leaveGroup()
                }
                .buttonStyle(.bordered)
                .tint(.red)

                if let group = groupSetupViewModel.currentGroup, let url = group.spreadsheetURL {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Group Spreadsheet:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Link(url.absoluteString, destination: url)
                            .font(.caption)
                        Button {
                            UIPasteboard.general.string = url.absoluteString
                        } label: {
                            Label("Copy Link", systemImage: "doc.on.doc")
                                .font(.caption)
                        }
                    }
                } else {
                    Text("No group spreadsheet found.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                NavigationLink("Set Your Goals") {
                    GoalSettingView()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                VStack(spacing: 10) {
                    actionButton("Upload Today's Steps", action: uploadSteps)
                    actionButton("Upload Today's Heart Rate", action: uploadHeartRate)
                    actionButton("Fetch Users", action: fetchUsers)
                    actionButton("Fetch Today's Steps", action: fetchSteps)
                    actionButton("Fetch Today's Heart Rate", action: fetchHeartRate)
                }

                if isBusy {
                    ProgressView()
                }

                Divider()

                Text("Log")
                    .font(.headline)
                Text(log)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
            }
            .padding()
        }
        }
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            .disabled(isBusy)
    }

    // MARK: - Actions

    private func uploadSteps() {
        run {
            let spreadsheetId = try requireSpreadsheetId()
            guard let currentUser = authViewModel.currentUser else {
                return "No signed-in user found."
            }
            let stepCount = try await HealthKitService.shared.todaysSteps()
            let entry = DailySteps(
                date: SheetsService.dateFormatter.string(from: Date()),
                email: currentUser.email ?? "unknown",
                steps: Int(stepCount)
            )
            try await SheetsService.shared.upsertTodaySteps(spreadsheetId: spreadsheetId, steps: entry)
            return "Uploaded steps: \(entry.steps) for \(entry.email)"
        }
    }

    private func uploadHeartRate() {
        run {
            let spreadsheetId = try requireSpreadsheetId()
            guard let currentUser = authViewModel.currentUser else {
                return "No signed-in user found."
            }
            let users = try await SheetsService.shared.fetchUsers(spreadsheetId: spreadsheetId)
            let threshold = users.first(where: { $0.email == currentUser.email })?.heartRateGoal ?? User.defaultHeartRateGoal
            let elevatedMinutes = try await HealthKitService.shared.elevatedHeartRateMinutesToday(threshold: Double(threshold))
            let entry = DailyHeartRate(
                date: SheetsService.dateFormatter.string(from: Date()),
                email: currentUser.email ?? "unknown",
                elevatedHRMinutes: elevatedMinutes
            )
            try await SheetsService.shared.upsertTodayHeartRate(spreadsheetId: spreadsheetId, metric: entry)
            return "Uploaded elevated HR: \(String(format: "%.1f", entry.elevatedHRMinutes)) min for \(entry.email)"
        }
    }

    private func fetchUsers() {
        run {
            let spreadsheetId = try requireSpreadsheetId()
            let users = try await SheetsService.shared.fetchUsers(spreadsheetId: spreadsheetId)
            return "Users:\n" + users.map { "\($0.name) — \($0.email)" }.joined(separator: "\n")
        }
    }

    private func fetchSteps() {
        run {
            let spreadsheetId = try requireSpreadsheetId()
            let steps = try await SheetsService.shared.fetchTodaySteps(spreadsheetId: spreadsheetId)
            return "Today's Steps:\n" + steps.map { "\($0.email): \($0.steps)" }.joined(separator: "\n")
        }
    }

    private func fetchHeartRate() {
        run {
            let spreadsheetId = try requireSpreadsheetId()
            let metrics = try await SheetsService.shared.fetchTodayHeartRate(spreadsheetId: spreadsheetId)
            return "Today's Heart Rate:\n" + metrics.map { "\($0.email): \(String(format: "%.1f", $0.elevatedHRMinutes)) min elevated" }.joined(separator: "\n")
        }
    }

    private func requireSpreadsheetId() throws -> String {
        guard let spreadsheetId else {
            throw NSError(domain: "SheetsTestView", code: 1, userInfo: [NSLocalizedDescriptionKey: "No group spreadsheet found."])
        }
        return spreadsheetId
    }

    // MARK: - Runner

    private func run(_ action: @escaping () async throws -> String) {
        isBusy = true
        Task {
            do {
                log = try await action()
            } catch {
                log = "Error: \(error.localizedDescription)"
            }
            isBusy = false
        }
    }
}

#Preview {
    SheetsTestView()
        .environmentObject(AuthViewModel())
        .environmentObject(GroupSetupViewModel())
}
