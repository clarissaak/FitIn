//
//  SheetsTestView.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 7/23/26.
//
import SwiftUI

// Temporary debug view to manually trigger and verify each SheetsService
// call. 
struct SheetsTestView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var spreadsheetId: String = ""
    @State private var log: String = "No actions yet."
    @State private var isBusy = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Sheets Test")
                    .font(.title2.bold())

                if !spreadsheetId.isEmpty {
                    Text("Spreadsheet ID:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(spreadsheetId)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }

                VStack(spacing: 10) {
                    actionButton("1. Create Spreadsheet", action: createSpreadsheet)
                    actionButton("2. Share Anyone With Link", action: shareLink)
                    actionButton("3. Add Self As User", action: addSelfAsUser)
                    actionButton("4. Upload Today's Steps", action: uploadSteps)
                    actionButton("5. Fetch Users", action: fetchUsers)
                    actionButton("6. Fetch Today's Steps", action: fetchSteps)
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

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            .disabled(isBusy)
    }

    // MARK: - Actions

    private func createSpreadsheet() {
        run {
            let id = try await SheetsService.shared.createSpreadsheet(name: "FitIn Test Sheet")
            spreadsheetId = id
            return "Created spreadsheet: \(id)"
        }
    }

    private func shareLink() {
        run {
            try requireSpreadsheetId()
            try await SheetsService.shared.shareAnyoneWithLink(spreadsheetId: spreadsheetId)
            return "Shared with anyone-with-link access."
        }
    }

    private func addSelfAsUser() {
        run {
            try requireSpreadsheetId()
            guard let currentUser = authViewModel.currentUser else {
                return "No signed-in user found."
            }
            let user = User(
                email: currentUser.email ?? "unknown",
                name: currentUser.name ?? "unknown",
                sub: currentUser.sub,
                joinedDate: SheetsService.dateFormatter.string(from: Date())
            )
            try await SheetsService.shared.appendOrUpdateUser(spreadsheetId: spreadsheetId, user: user)
            return "Added/updated user: \(user.email)"
        }
    }

    private func uploadSteps() {
        run {
            try requireSpreadsheetId()
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

    private func fetchUsers() {
        run {
            try requireSpreadsheetId()
            let users = try await SheetsService.shared.fetchUsers(spreadsheetId: spreadsheetId)
            return "Users:\n" + users.map { "\($0.name) — \($0.email)" }.joined(separator: "\n")
        }
    }

    private func fetchSteps() {
        run {
            try requireSpreadsheetId()
            let steps = try await SheetsService.shared.fetchTodaySteps(spreadsheetId: spreadsheetId)
            return "Today's Steps:\n" + steps.map { "\($0.email): \($0.steps)" }.joined(separator: "\n")
        }
    }

    private func requireSpreadsheetId() throws {
        if spreadsheetId.isEmpty {
            throw NSError(domain: "SheetsTestView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Create a spreadsheet first (step 1)."])
        }
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
}
