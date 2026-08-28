//
//  GroupSetupViewModel.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 7/28/26.
//
import Foundation
import Combine

// Drives state for GroupSetupView: creating a new group, requesting to
// join an existing one via a pasted code, and tracking whether that
// request is still pending approval from the group's creator.
@MainActor
final class GroupSetupViewModel: ObservableObject {

    @Published private(set) var currentGroup: UserGroup?
    @Published private(set) var isPendingApproval = false
    @Published var joinCodeInput: String = ""
    @Published var isBusy = false
    @Published var errorMessage: String?

    private let groupService = GroupService.shared

    var hasGroup: Bool {
        currentGroup != nil
    }

    // Call once on launch to restore a previously created/joined group.
    // Also re-checks actual membership status in case a pending request
    // was approved, rejected, or never successfully submitted while the
    // app was closed.
    func restoreGroupIfAvailable() async {
        currentGroup = groupService.restoreCurrentGroup()
        guard let group = currentGroup else { return }
        await refreshApprovalStatus(spreadsheetId: group.spreadsheetId)
    }

    func createGroup(name: String) async {
        errorMessage = nil
        isBusy = true
        do {
            currentGroup = try await groupService.createGroup(name: name)
            isPendingApproval = false
        } catch {
            errorMessage = "Couldn't create group. Please try again."
        }
        isBusy = false
    }

    func requestToJoinGroup() async {
        errorMessage = nil
        guard !joinCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Enter a group code or link first."
            return
        }
        isBusy = true
        do {
            let (group, outcome) = try await groupService.requestToJoinGroup(code: joinCodeInput)
            currentGroup = group
            isPendingApproval = (outcome == .pendingApproval)
        } catch {
            errorMessage = "Couldn't request to join. Check the code and try again."
        }
        isBusy = false
    }

    // Re-checks actual membership status: approved (proceed into the
    // app), still pending (keep waiting), or neither — which means the
    // request was rejected, or never actually went through, so we clear
    // the group locally and send the user back to group setup rather
    // than leaving them stuck waiting forever.
    func refreshApprovalStatus(spreadsheetId: String) async {
        let status = await groupService.membershipStatus(spreadsheetId: spreadsheetId)
        switch status {
        case .approved:
            isPendingApproval = false
        case .pending:
            isPendingApproval = true
        case .none:
            leaveGroup()
        }
    }

    func leaveGroup() {
        groupService.clearCurrentGroup()
        currentGroup = nil
        isPendingApproval = false
        joinCodeInput = ""
    }
}
