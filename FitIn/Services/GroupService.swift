//
//  GroupService.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 7/28/26.
//
import Foundation

// Handles creating a new group (new spreadsheet) or joining an existing
// one (pasted spreadsheet ID), and persists which group the current
// device is part of.
@MainActor
final class GroupService {

    static let shared = GroupService()

    private init() {}

    private let currentGroupCodeKey = "currentGroupCode"

    enum GroupError: Error {
        case noCurrentUser
    }

    // MARK: - Create

    // Creates a new spreadsheet, shares it as anyone-with-link editable,
    // adds the current user as a member, and persists the resulting
    // spreadsheet ID as the current group's code.
    func createGroup(name: String) async throws -> UserGroup {
        let spreadsheetId = try await SheetsService.shared.createSpreadsheet(name: name)
        try await SheetsService.shared.shareAnyoneWithLink(spreadsheetId: spreadsheetId)
        try await addSelfAsUser(spreadsheetId: spreadsheetId)

        let group = UserGroup(code: spreadsheetId, spreadsheetId: spreadsheetId)
        persistCurrentGroupCode(group.code)
        return group
    }

    // MARK: - Join

    // Stores the pasted spreadsheet ID (or full spreadsheet link) as the
    // current group's code, and adds the current user as a member of
    // that spreadsheet.
    func joinGroup(code: String) async throws -> UserGroup {
        let spreadsheetId = Self.extractSpreadsheetId(from: code)
        try await addSelfAsUser(spreadsheetId: spreadsheetId)

        let group = UserGroup(code: spreadsheetId, spreadsheetId: spreadsheetId)
        persistCurrentGroupCode(group.code)
        return group
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

    // Restores the current group, if one was previously created or joined
    // on this device.
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
