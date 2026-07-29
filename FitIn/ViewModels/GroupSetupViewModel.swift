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
//
// hasGroup and hasConfirmedSetup are separate on purpose: right after
// creating a group, currentGroup is set immediately (so the shareable
// link can be shown), but the app shouldn't navigate away until the
// user has actually seen that link and tapped Continue. A restored
// group (from a previous launch) skips that confirmation step, since
// there's nothing new to show.
@MainActor
final class GroupSetupViewModel: ObservableObject {

    @Published private(set) var currentGroup: UserGroup?
    @Published private(set) var hasConfirmedSetup = false
    @Published var joinCodeInput: String = ""
    @Published var isBusy = false
    @Published var errorMessage: String?

    private let groupService = GroupService.shared

    var hasGroup: Bool {
        currentGroup != nil
    }

    // The app root should only move past group setup once both a group
    // exists and the user has confirmed they've seen the shareable link.
    var isReadyToProceed: Bool {
        hasGroup && hasConfirmedSetup
    }

    // Call once on launch to restore a previously created/joined group.
    func restoreGroupIfAvailable() {
        currentGroup = groupService.restoreCurrentGroup()
        if currentGroup != nil {
            hasConfirmedSetup = true
        }
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

    // Called when the user taps Continue after seeing the shareable link
    // (or right after joining, where there's nothing to show).
    func confirmSetup() {
        hasConfirmedSetup = true
    }

    func leaveGroup() {
        groupService.clearCurrentGroup()
        currentGroup = nil
        hasConfirmedSetup = false
        joinCodeInput = ""
    }
}
