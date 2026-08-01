//
//  User.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 7/23/26.
//
import Foundation

// Represents one row in the "Users" sheet tab, including each user's
// personal goals: a daily step target, the heart rate threshold they're
// tracking, and how many minutes above that threshold they're aiming for.
// Age is derived from the stored birth date rather than saved directly,
// so it stays correct automatically once a birthday passes.
struct User: Identifiable, Equatable {
    var id: String { email }
    let email: String
    let name: String
    let sub: String
    let joinedDate: String // yyyy-MM-dd, stored as plain text in the sheet
    var birthDate: String // yyyy-MM-dd, empty string if not yet provided
    var stepsGoal: Int
    var heartRateGoal: Int // BPM threshold
    var elevatedMinutesGoal: Double // minutes per day above heartRateGoal

    static let defaultStepsGoal = 10_000
    static let defaultHeartRateGoal = 120
    static let defaultElevatedMinutesGoal: Double = 30

    // Column order as written to/read from the "Users" tab:
    // Email, Name, Sub, JoinedDate, BirthDate, StepsGoal, HeartRateGoal, ElevatedMinutesGoal
    static let headerRow = ["Email", "Name", "Sub", "JoinedDate", "BirthDate", "StepsGoal", "HeartRateGoal", "ElevatedMinutesGoal"]

    var asRow: [String] {
        [email, name, sub, joinedDate, birthDate, String(stepsGoal), String(heartRateGoal), String(elevatedMinutesGoal)]
    }

    // Current age computed from birthDate, or nil if birthDate hasn't
    // been provided yet. Computed fresh each time, so it's always
    // correct even after a birthday passes.
    var age: Int? {
        guard !birthDate.isEmpty, let date = SheetsService.dateFormatter.date(from: birthDate) else {
            return nil
        }
        let components = Calendar.current.dateComponents([.year], from: date, to: Date())
        return components.year
    }

    // Builds a user from a raw row returned by the Sheets API. Falls back
    // to defaults / empty birth date if the row predates these columns.
    static func from(row: [String]) -> User? {
        guard row.count >= 4 else { return nil }
        let birthDate = row.count > 4 ? row[4] : ""
        let stepsGoal = row.count > 5 ? (Int(row[5]) ?? defaultStepsGoal) : defaultStepsGoal
        let heartRateGoal = row.count > 6 ? (Int(row[6]) ?? defaultHeartRateGoal) : defaultHeartRateGoal
        let elevatedMinutesGoal = row.count > 7 ? (Double(row[7]) ?? defaultElevatedMinutesGoal) : defaultElevatedMinutesGoal
        return User(
            email: row[0],
            name: row[1],
            sub: row[2],
            joinedDate: row[3],
            birthDate: birthDate,
            stepsGoal: stepsGoal,
            heartRateGoal: heartRateGoal,
            elevatedMinutesGoal: elevatedMinutesGoal
        )
    }

    // Convenience for creating a brand-new user row with default goals
    // and no birth date yet (collected during onboarding).
    static func newUser(email: String, name: String, sub: String, joinedDate: String) -> User {
        User(
            email: email,
            name: name,
            sub: sub,
            joinedDate: joinedDate,
            birthDate: "",
            stepsGoal: defaultStepsGoal,
            heartRateGoal: defaultHeartRateGoal,
            elevatedMinutesGoal: defaultElevatedMinutesGoal
        )
    }
}
