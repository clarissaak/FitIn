//
//  PendingRequestsView.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 8/26/26.
//
import SwiftUI

// Lets the group's creator review and approve/reject pending join
// requests. Access to this screen should be gated by checking
// GroupService.isCurrentUserCreator before showing the entry point.
struct PendingRequestsView: View {
    @EnvironmentObject var groupSetupViewModel: GroupSetupViewModel

    @State private var requests: [JoinRequest] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var processingEmail: String?

    var body: some View {
        List {
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if !isLoading && requests.isEmpty && errorMessage == nil {
                Text("No pending requests.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(requests) { request in
                VStack(alignment: .leading, spacing: 8) {
                    Text(request.name)
                        .font(.headline)
                    Text(request.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button("Approve") {
                            Task { await respond(to: request, approve: true) }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Reject", role: .destructive) {
                            Task { await respond(to: request, approve: false) }
                        }
                        .buttonStyle(.bordered)
                    }
                    .disabled(processingEmail == request.email)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Pending Requests")
        .refreshable {
            await load()
        }
        .task {
            await load()
        }
        .overlay {
            if isLoading && requests.isEmpty {
                ProgressView()
            }
        }
    }

    private func load() async {
        guard let spreadsheetId = groupSetupViewModel.currentGroup?.spreadsheetId else {
            isLoading = false
            return
        }
        errorMessage = nil
        isLoading = true
        do {
            requests = try await SheetsService.shared.fetchJoinRequests(spreadsheetId: spreadsheetId)
        } catch {
            errorMessage = "Couldn't load requests."
        }
        isLoading = false
    }

    private func respond(to request: JoinRequest, approve: Bool) async {
        guard let spreadsheetId = groupSetupViewModel.currentGroup?.spreadsheetId else { return }
        processingEmail = request.email
        do {
            if approve {
                try await SheetsService.shared.approveJoinRequest(spreadsheetId: spreadsheetId, request: request)
            } else {
                try await SheetsService.shared.rejectJoinRequest(spreadsheetId: spreadsheetId, request: request)
            }
            requests.removeAll { $0.email == request.email }
        } catch {
            errorMessage = "Couldn't update that request. Please try again."
        }
        processingEmail = nil
    }
}

#Preview {
    NavigationStack {
        PendingRequestsView()
            .environmentObject(GroupSetupViewModel())
    }
}
