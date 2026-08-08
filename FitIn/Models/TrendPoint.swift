//
//  TrendPoint.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 8/7/26.
//
import Foundation

// One point in a trend chart: a date and a numeric value (steps count,
// or elevated heart rate minutes).
struct TrendPoint: Identifiable {
    var id: String { dateString }
    let dateString: String // yyyy-MM-dd
    let date: Date
    let value: Double
}
