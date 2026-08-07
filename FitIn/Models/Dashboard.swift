//
//  Dashboard.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 8/6/26.
//
import Foundation

// A group member's display info plus their steps and elevated
// heart rate minutes for today, alongside their goals.
struct Dashboard: Identifiable {
    var id: String { email }
    let email: String
    let displayName: String

    let currentSteps: Int
    let stepGoal: Int

    let currentElevatedMinutes: Double
    let elevatedMinutesGoal: Double

    var stepsMet: Bool {
        currentSteps >= stepGoal
    }

    var heartRateMet: Bool {
        currentElevatedMinutes >= elevatedMinutesGoal
    }

    var stepsRemaining: Int {
        max(0, stepGoal - currentSteps)
    }

    var elevatedMinutesRemaining: Double {
        max(0, elevatedMinutesGoal - currentElevatedMinutes)
    }
}
