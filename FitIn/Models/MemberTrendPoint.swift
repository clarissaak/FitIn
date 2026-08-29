//
//  MemberTrendPoint.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 8/29/26.
//


// MemberTrendPoint.swift
import Foundation

struct MemberTrendPoint: Identifiable {
    let id = UUID()
    let email: String
    let displayName: String
    let date: Date
    let value: Double
}