//
//  User.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 7/23/26.
//
import Foundation

// Represents one row in the "Users" sheet tab.
struct User: Identifiable, Equatable {
    var id: String { email }
    let email: String
    let name: String
    let sub: String
    let joinedDate: String // yyyy-MM-dd

    // Column order as written to/read from "Users": Email, Name, Sub, JoinedDate
    static let headerRow = ["Email", "Name", "Sub", "JoinedDate"]

    var asRow: [String] {
        [email, name, sub, joinedDate]
    }

    // Builds a user from a raw row returned by the Sheets API.
    // Returns nil if the row doesn't have enough columns to be valid.
    static func from(row: [String]) -> User? {
        guard row.count >= 4 else { return nil }
        return User(email: row[0], name: row[1], sub: row[2], joinedDate: row[3])
    }
}
