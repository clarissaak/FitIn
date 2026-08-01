//
//  GroupSetupViewModel.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 7/28/26.
//
import Foundation
import Combine

// Drives state for GroupSetupView: creating a new group, joining an
// existing one via a pasted code, and exposing the resulting group so
// the app root can move on to the main flow.
@MainActor
final class GroupSetupViewModel: ObservableObject {

    @Published private(set) var currentGroup: UserGroup?
    @Published var joinCodeInput: String = ""
    @Published var isBusy = false
    @Published var errorMessage: String?

    private let groupService = GroupService.shared

    var hasGroup: Bool {
        currentGroup != nil
    }

    // Call once on launch to restore a previously created/joined group.
    func restoreGroupIfAvailable() {
        currentGroup = groupService.restoreCurrentGroup()
    }

    func createGroup(name: String) async {
        errorMessage = nil
        isBusy = true
        do {
            currentGroup = try await groupService.createGroup(name: name)
        } catch {
            errorMessage = "Couldn't create group. Please try again."
        }
        isBusy = false
    }

    func joinGroup() async {
        errorMessage = nil
        guard !joinCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Enter a group code first."
            return
        }
        isBusy = true
        do {
            currentGroup = try await groupService.joinGroup(code: joinCodeInput)
        } catch {
            errorMessage = "Couldn't join group. Check the code and try again."
        }
        isBusy = false
    }

    func leaveGroup() {
        groupService.clearCurrentGroup()
        currentGroup = nil
        joinCodeInput = ""
    }
}
