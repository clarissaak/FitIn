//
//  DailyHeartRate.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 7/27/26.
//
import Foundation

// Represents one row in the "HeartRate" sheet tab.
struct DailyHeartRate: Identifiable, Equatable {
    var id: String { "\(date)_\(email)" }
    let date: String // yyyy-MM-dd
    let email: String
    let elevatedHRMinutes: Double

    // Column order as written to/read from "HeartRate": Date, Email, ElevatedHRMinutes
    static let headerRow = ["Date", "Email", "ElevatedHRMinutes"]

    var asRow: [String] {
        [date, email, String(elevatedHRMinutes)]
    }

    // Builds a DailyHeartRate entry from a raw row returned by the Sheets API.
    // Returns nil if the row doesn't have enough columns or steps isn't a valid integer.
    static func from(row: [String]) -> DailyHeartRate? {
        guard row.count >= 3,
                let elevatedHRMinutes = Double(row[2]) else { return nil }
        return DailyHeartRate(date: row[0], email: row[1], elevatedHRMinutes: elevatedHRMinutes)
    }
}
