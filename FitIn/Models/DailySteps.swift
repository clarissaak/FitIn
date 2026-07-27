//
//  DailySteps.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 7/23/26.
//
import Foundation

// Represents one row in the "Steps" sheet tab.
struct DailySteps: Identifiable, Equatable {
    var id: String { "\(date)_\(email)" }
    let date: String // yyyy-MM-dd
    let email: String
    let steps: Int

    // Column order as written to/read from "Steps": Date, Email, Steps
    static let headerRow = ["Date", "Email", "Steps"]

    var asRow: [String] {
        [date, email, String(steps)]
    }

    // Builds a DailySteps entry from a raw row returned by the Sheets API.
    // Returns nil if the row doesn't have enough columns or steps isn't a valid integer.
    static func from(row: [String]) -> DailySteps? {
        guard row.count >= 3, let steps = Int(row[2]) else { return nil }
        return DailySteps(date: row[0], email: row[1], steps: steps)
    }
}
