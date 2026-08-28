//
//  JoinRequest.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 8/26/26.
//
import Foundation

// Represents one row in the "Requests" sheet tab: someone who has asked
// to join the group and is waiting for the creator to approve or reject.
struct JoinRequest: Identifiable, Equatable {
    var id: String { email }
    let email: String
    let name: String
    let sub: String
    let requestedDate: String // yyyy-MM-dd

    static let headerRow = ["Email", "Name", "Sub", "RequestedDate"]

    var asRow: [String] {
        [email, name, sub, requestedDate]
    }

    static func from(row: [String]) -> JoinRequest? {
        // A cleared (approved/rejected) row has an empty email — skip it.
        guard row.count >= 4, !row[0].isEmpty else { return nil }
        return JoinRequest(email: row[0], name: row[1], sub: row[2], requestedDate: row[3])
    }
}
