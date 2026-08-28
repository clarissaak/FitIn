//
//  SheetsService.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 7/23/26.
//
import Foundation

// Wraps the Google Sheets v4 REST API and the Drive v3 permissions endpoint
// needed to create and share a group's backing spreadsheet, and to read/
// write Users, Steps, HeartRate, and join-Requests data. All requests are
// authenticated with the current user's Google access token as a Bearer
// token.
@MainActor
final class SheetsService {

    static let shared = SheetsService()

    private init() {}

    private let sheetsBase = "https://sheets.googleapis.com/v4/spreadsheets"
    private let driveBase = "https://www.googleapis.com/drive/v3/files"

    enum SheetsError: Error {
        case invalidURL
        case requestFailed(statusCode: Int, body: String)
        case decodingFailed
        case missingSpreadsheetId
    }

    // MARK: - Shared request helpers

    private func authorizedRequest(url: URL, method: String, jsonBody: [String: Any]? = nil) async throws -> URLRequest {
        let token = try await GoogleAuthService.shared.validAccessToken()
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let jsonBody {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)
        }
        return request
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SheetsError.requestFailed(statusCode: -1, body: "No HTTP response")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw SheetsError.requestFailed(statusCode: httpResponse.statusCode, body: body)
        }
        return data
    }

    private func performJSON(_ request: URLRequest) async throws -> [String: Any] {
        let data = try await perform(request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SheetsError.decodingFailed
        }
        return json
    }

    // MARK: - Create spreadsheet

    // Creates a new spreadsheet with "Users", "Steps", "HeartRate",
    // "Requests", and "Meta" tabs, writes their header rows, and returns
    // the new spreadsheet's ID.
    func createSpreadsheet(name: String) async throws -> String {
        guard let url = URL(string: sheetsBase) else { throw SheetsError.invalidURL }

        let body: [String: Any] = [
            "properties": ["title": name],
            "sheets": [
                ["properties": ["title": "Users"]],
                ["properties": ["title": "Steps"]],
                ["properties": ["title": "HeartRate"]],
                ["properties": ["title": "Requests"]],
                ["properties": ["title": "Meta"]]
            ]
        ]

        let request = try await authorizedRequest(url: url, method: "POST", jsonBody: body)
        let json = try await performJSON(request)

        guard let spreadsheetId = json["spreadsheetId"] as? String else {
            throw SheetsError.missingSpreadsheetId
        }

        try await writeHeaderRows(spreadsheetId: spreadsheetId)

        return spreadsheetId
    }

    private func writeHeaderRows(spreadsheetId: String) async throws {
        try await updateRange(
            spreadsheetId: spreadsheetId,
            range: "Users!A1:K1",
            values: [User.headerRow]
        )
        try await updateRange(
            spreadsheetId: spreadsheetId,
            range: "Steps!A1:C1",
            values: [DailySteps.headerRow]
        )
        try await updateRange(
            spreadsheetId: spreadsheetId,
            range: "HeartRate!A1:C1",
            values: [DailyHeartRate.headerRow]
        )
        try await updateRange(
            spreadsheetId: spreadsheetId,
            range: "Requests!A1:D1",
            values: [JoinRequest.headerRow]
        )
    }

    // MARK: - Share

    // Grants "anyone with the link" write access to the spreadsheet via Drive.
    func shareAnyoneWithLink(spreadsheetId: String) async throws {
        guard let url = URL(string: "\(driveBase)/\(spreadsheetId)/permissions") else {
            throw SheetsError.invalidURL
        }
        let body: [String: Any] = [
            "role": "writer",
            "type": "anyone"
        ]
        let request = try await authorizedRequest(url: url, method: "POST", jsonBody: body)
        _ = try await perform(request)
    }

    // MARK: - Meta (creator tracking)

    // Records who created the group. Called once, right after the
    // spreadsheet is created. Used to gate who can approve/reject join
    // requests.
    func setCreatorEmail(spreadsheetId: String, email: String) async throws {
        try await updateRange(
            spreadsheetId: spreadsheetId,
            range: "Meta!A1:B1",
            values: [["CreatorEmail", email]]
        )
    }

    // Returns the group creator's email, or nil if not set.
    func fetchCreatorEmail(spreadsheetId: String) async throws -> String? {
        let rows = try await fetchRawValues(spreadsheetId: spreadsheetId, range: "Meta!A1:B1")
        guard let row = rows.first, row.count >= 2, row[0] == "CreatorEmail" else {
            return nil
        }
        return row[1]
    }

    // MARK: - Join Requests

    // Submits a join request, unless one is already pending for this
    // email (avoids duplicate requests from repeated taps).
    func submitJoinRequest(spreadsheetId: String, request: JoinRequest) async throws {
        let existing = try await fetchJoinRequests(spreadsheetId: spreadsheetId)
        guard !existing.contains(where: { $0.email == request.email }) else { return }
        try await appendRange(
            spreadsheetId: spreadsheetId,
            range: "Requests!A:D",
            values: [request.asRow]
        )
    }

    // Fetches all pending join requests.
    func fetchJoinRequests(spreadsheetId: String) async throws -> [JoinRequest] {
        let rows = try await fetchRawValues(spreadsheetId: spreadsheetId, range: "Requests!A2:D")
        return rows.compactMap { JoinRequest.from(row: $0) }
    }

    // Approves a join request: adds the requester as a full member with
    // default goals, then clears their row from Requests.
    func approveJoinRequest(spreadsheetId: String, request: JoinRequest) async throws {
        let newUser = User.newUser(
            email: request.email,
            name: request.name,
            sub: request.sub,
            joinedDate: Self.dateFormatter.string(from: Date())
        )
        try await appendOrUpdateUser(spreadsheetId: spreadsheetId, user: newUser)
        try await clearJoinRequestRow(spreadsheetId: spreadsheetId, email: request.email)
    }

    // Rejects a join request: just clears their row from Requests,
    // without adding them as a member.
    func rejectJoinRequest(spreadsheetId: String, request: JoinRequest) async throws {
        try await clearJoinRequestRow(spreadsheetId: spreadsheetId, email: request.email)
    }

    private func clearJoinRequestRow(spreadsheetId: String, email: String) async throws {
        let rows = try await fetchRawValues(spreadsheetId: spreadsheetId, range: "Requests!A2:D")
        guard let index = rows.firstIndex(where: { $0.first == email }) else { return }
        let rowNumber = index + 2
        try await clearRange(spreadsheetId: spreadsheetId, range: "Requests!A\(rowNumber):D\(rowNumber)")
    }

    // MARK: - Users

    // Adds a new user row, or updates the existing row if the email
    // already exists in the Users sheet.
    func appendOrUpdateUser(spreadsheetId: String, user: User) async throws {
        let rows = try await fetchRawValues(spreadsheetId: spreadsheetId, range: "Users!A2:K")

        if let existingIndex = rows.firstIndex(where: { $0.first == user.email }) {
            let rowNumber = existingIndex + 2 // +2: header row + 1-indexed
            try await updateRange(
                spreadsheetId: spreadsheetId,
                range: "Users!A\(rowNumber):K\(rowNumber)",
                values: [user.asRow]
            )
        } else {
            try await appendRange(
                spreadsheetId: spreadsheetId,
                range: "Users!A:K",
                values: [user.asRow]
            )
        }
    }

    // Fetches all users from the Users sheet.
    func fetchUsers(spreadsheetId: String) async throws -> [User] {
        let rows = try await fetchRawValues(spreadsheetId: spreadsheetId, range: "Users!A2:K")
        return rows.compactMap { User.from(row: $0) }
    }

    // MARK: - Steps

    // Adds today's step entry, or updates it if one already exists for
    // this email + date combination.
    func upsertTodaySteps(spreadsheetId: String, steps: DailySteps) async throws {
        let rows = try await fetchRawValues(spreadsheetId: spreadsheetId, range: "Steps!A2:C")

        if let existingIndex = rows.firstIndex(where: { $0.count >= 2 && $0[0] == steps.date && $0[1] == steps.email }) {
            let rowNumber = existingIndex + 2
            try await updateRange(
                spreadsheetId: spreadsheetId,
                range: "Steps!A\(rowNumber):C\(rowNumber)",
                values: [steps.asRow]
            )
        } else {
            try await appendRange(
                spreadsheetId: spreadsheetId,
                range: "Steps!A:C",
                values: [steps.asRow]
            )
        }
    }

    // Fetches all step entries for today's date (device-local calendar day).
    func fetchTodaySteps(spreadsheetId: String) async throws -> [DailySteps] {
        let all = try await fetchAllSteps(spreadsheetId: spreadsheetId)
        let today = Self.dateFormatter.string(from: Date())
        return all.filter { $0.date == today }
    }

    // Fetches every step entry in the sheet, regardless of date.
    func fetchAllSteps(spreadsheetId: String) async throws -> [DailySteps] {
        let rows = try await fetchRawValues(spreadsheetId: spreadsheetId, range: "Steps!A2:C")
        return rows.compactMap { DailySteps.from(row: $0) }
    }

    // MARK: - Heart Rate

    // Adds today's elevated heart rate minutes entry, or updates it if one
    // already exists for this email + date combination.
    func upsertTodayHeartRate(spreadsheetId: String, metric: DailyHeartRate) async throws {
        let rows = try await fetchRawValues(spreadsheetId: spreadsheetId, range: "HeartRate!A2:C")

        if let existingIndex = rows.firstIndex(where: { $0.count >= 2 && $0[0] == metric.date && $0[1] == metric.email }) {
            let rowNumber = existingIndex + 2
            try await updateRange(
                spreadsheetId: spreadsheetId,
                range: "HeartRate!A\(rowNumber):C\(rowNumber)",
                values: [metric.asRow]
            )
        } else {
            try await appendRange(
                spreadsheetId: spreadsheetId,
                range: "HeartRate!A:C",
                values: [metric.asRow]
            )
        }
    }

    // Fetches all heart rate entries for today's date (device-local calendar day).
    func fetchTodayHeartRate(spreadsheetId: String) async throws -> [DailyHeartRate] {
        let all = try await fetchAllHeartRate(spreadsheetId: spreadsheetId)
        let today = Self.dateFormatter.string(from: Date())
        return all.filter { $0.date == today }
    }

    // Fetches every heart rate entry in the sheet, regardless of date.
    func fetchAllHeartRate(spreadsheetId: String) async throws -> [DailyHeartRate] {
        let rows = try await fetchRawValues(spreadsheetId: spreadsheetId, range: "HeartRate!A2:C")
        return rows.compactMap { DailyHeartRate.from(row: $0) }
    }

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter
    }()

    // MARK: - Low-level values helpers

    private func fetchRawValues(spreadsheetId: String, range: String) async throws -> [[String]] {
        guard let encodedRange = range.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(sheetsBase)/\(spreadsheetId)/values/\(encodedRange)") else {
            throw SheetsError.invalidURL
        }
        let request = try await authorizedRequest(url: url, method: "GET")
        let json = try await performJSON(request)
        guard let values = json["values"] as? [[String]] else {
            return [] // empty range legitimately has no "values" key
        }
        return values
    }

    private func updateRange(spreadsheetId: String, range: String, values: [[String]]) async throws {
        guard let encodedRange = range.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(sheetsBase)/\(spreadsheetId)/values/\(encodedRange)?valueInputOption=USER_ENTERED") else {
            throw SheetsError.invalidURL
        }
        let body: [String: Any] = ["values": values]
        let request = try await authorizedRequest(url: url, method: "PUT", jsonBody: body)
        _ = try await perform(request)
    }

    private func appendRange(spreadsheetId: String, range: String, values: [[String]]) async throws {
        guard let encodedRange = range.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(sheetsBase)/\(spreadsheetId)/values/\(encodedRange):append?valueInputOption=USER_ENTERED") else {
            throw SheetsError.invalidURL
        }
        let body: [String: Any] = ["values": values]
        let request = try await authorizedRequest(url: url, method: "POST", jsonBody: body)
        _ = try await perform(request)
    }

    // Clears the values in a range without deleting the row itself —
    // simpler than a true row-delete (which requires knowing the tab's
    // internal numeric sheetId via a separate metadata call). A cleared
    // row is treated as absent by JoinRequest.from(row:), which skips
    // rows with an empty email.
    private func clearRange(spreadsheetId: String, range: String) async throws {
        guard let encodedRange = range.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(sheetsBase)/\(spreadsheetId)/values/\(encodedRange):clear") else {
            throw SheetsError.invalidURL
        }
        let request = try await authorizedRequest(url: url, method: "POST", jsonBody: [:])
        _ = try await perform(request)
    }
}
