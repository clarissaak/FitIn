//
//  GroupService.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 7/28/26.
//
import Foundation

// Handles creating a new group (new spreadsheet, creator recorded, self
// added as a member) or requesting to join an existing one (submits a
// join request — the creator must approve before the requester becomes
// a member). Persists which group the current device is part of.
@MainActor
final class GroupService {

    static let shared = GroupService()

    private init() {}

    private let currentGroupCodeKey = "currentGroupCode"

    enum GroupError: Error {
        case noCurrentUser
    }

    // MARK: - Create

    // Creates a new spreadsheet, shares it as anyone-with-link editable
    // (so join requests can be submitted before the requester is a
    // member), records the current user as creator, adds them as the
    // first member, and persists the resulting spreadsheet ID as the
    // current group's code.
    func createGroup(name: String) async throws -> UserGroup {
        guard let currentUser = GoogleAuthService.shared.currentUser else {
            throw GroupError.noCurrentUser
        }

        let spreadsheetId = try await SheetsService.shared.createSpreadsheet(name: name)
        try await SheetsService.shared.shareAnyoneWithLink(spreadsheetId: spreadsheetId)
        try await SheetsService.shared.setCreatorEmail(spreadsheetId: spreadsheetId, email: currentUser.email ?? "unknown")
        try await addSelfAsUser(spreadsheetId: spreadsheetId)

        let group = UserGroup(code: spreadsheetId, spreadsheetId: spreadsheetId)
        persistCurrentGroupCode(group.code)
        return group
    }

    // MARK: - Join (request-based)

    enum JoinOutcome {
        case pendingApproval
        case alreadyApproved // rare: rejoining a group they were already a member of
    }

    // Submits a join request for the pasted spreadsheet ID (or full
    // link — the ID is extracted either way). Does NOT add the user as
    // a member; the group's creator must approve first. Persists the
    // group code locally right away so the app can poll for approval.
    func requestToJoinGroup(code: String) async throws -> (group: UserGroup, outcome: JoinOutcome) {
        guard let currentUser = GoogleAuthService.shared.currentUser else {
            throw GroupError.noCurrentUser
        }

        let spreadsheetId = Self.extractSpreadsheetId(from: code)
        let email = currentUser.email ?? "unknown"

        let existingUsers = try await SheetsService.shared.fetchUsers(spreadsheetId: spreadsheetId)
        let group = UserGroup(code: spreadsheetId, spreadsheetId: spreadsheetId)
        persistCurrentGroupCode(group.code)

        if existingUsers.contains(where: { $0.email == email }) {
            // Already a member (e.g. reinstalled the app) — no request needed.
            return (group, .alreadyApproved)
        }

        let request = JoinRequest(
            email: email,
            name: currentUser.name ?? "unknown",
            sub: currentUser.sub,
            requestedDate: SheetsService.dateFormatter.string(from: Date())
        )
        try await SheetsService.shared.submitJoinRequest(spreadsheetId: spreadsheetId, request: request)

        return (group, .pendingApproval)
    }

    enum MembershipStatus {
        case approved
        case pending
        case none
    }

    // Checks the requester's actual status against the sheet: a full
    // member (in Users), a pending request (in Requests), or neither
    // (e.g. rejected, or a request that never successfully submitted).
    // Used on restore and on the waiting screen's refresh, so rejection
    // and failed-submission edge cases resolve correctly instead of
    // leaving the app stuck on a stale local flag.
    func membershipStatus(spreadsheetId: String) async -> MembershipStatus {
        guard let email = GoogleAuthService.shared.currentUser?.email else { return .none }
        if let users = try? await SheetsService.shared.fetchUsers(spreadsheetId: spreadsheetId),
           users.contains(where: { $0.email == email }) {
            return .approved
        }
        if let requests = try? await SheetsService.shared.fetchJoinRequests(spreadsheetId: spreadsheetId),
           requests.contains(where: { $0.email == email }) {
            return .pending
        }
        return .none
    }

    // Whether the current signed-in user is this group's creator —
    // gates access to the pending-requests approval screen.
    func isCurrentUserCreator(spreadsheetId: String) async -> Bool {
        guard let email = GoogleAuthService.shared.currentUser?.email else { return false }
        let creatorEmail = try? await SheetsService.shared.fetchCreatorEmail(spreadsheetId: spreadsheetId)
        return creatorEmail == email
    }

    // Accepts either a raw spreadsheet ID or a full
    // "https://docs.google.com/spreadsheets/d/{id}/edit..." link, and
    // returns just the ID either way.
    static func extractSpreadsheetId(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("/d/") else { return trimmed }

        let components = trimmed.components(separatedBy: "/d/")
        guard components.count > 1 else { return trimmed }
        let remainder = components[1]
        return remainder.components(separatedBy: "/").first ?? trimmed
    }

    private func addSelfAsUser(spreadsheetId: String) async throws {
        guard let currentUser = GoogleAuthService.shared.currentUser else {
            throw GroupError.noCurrentUser
        }
        let user = User.newUser(
            email: currentUser.email ?? "unknown",
            name: currentUser.name ?? "unknown",
            sub: currentUser.sub,
            joinedDate: SheetsService.dateFormatter.string(from: Date())
        )
        try await SheetsService.shared.appendOrUpdateUser(spreadsheetId: spreadsheetId, user: user)
    }

    // MARK: - Persistence

    private func persistCurrentGroupCode(_ code: String) {
        UserDefaults.standard.set(code, forKey: currentGroupCodeKey)
    }

    // Restores the current group, if one was previously created or
    // requested/joined on this device.
    func restoreCurrentGroup() -> UserGroup? {
        guard let code = UserDefaults.standard.string(forKey: currentGroupCodeKey) else {
            return nil
        }
        return UserGroup(code: code, spreadsheetId: code)
    }

    // Clears the persisted group, e.g. to let the user leave/switch groups.
    func clearCurrentGroup() {
        UserDefaults.standard.removeObject(forKey: currentGroupCodeKey)
    }
}
