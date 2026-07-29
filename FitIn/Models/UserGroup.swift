//
//  UserGroup.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 7/23/26.
//
import Foundation

// Represents a sharing group
struct UserGroup: Identifiable, Equatable {
    var id: String { code }
    let code: String
    let spreadsheetId: String
    
    // Direct link to the spreadsheet in Google Sheets.
    var spreadsheetURL: URL? {
        URL(string: "https://docs.google.com/spreadsheets/d/\(spreadsheetId)/edit")
    }
}
