//
//  NotificationService.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 8/11/26.
//
import Foundation
import UserNotifications

// Schedules local notifications for group members who haven't met their
// goals yet today. Since this app has no server/push infrastructure,
// notifications are rescheduled from scratch every time the Sharing tab
// refreshes — each call replaces the previous day's pending requests
// with fresh ones based on the latest known data.
@MainActor
final class NotificationService {

    static let shared = NotificationService()

    private init() {}

    private let center = UNUserNotificationCenter.current()
    private let reminderHour = 22 // 10 PM local time
    private let reminderMinute = 00
    // Requests permission to show notifications. Safe to call repeatedly —
    // iOS only prompts once; afterward this just reports the current status.
    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    // Replaces today's scheduled missed-goal notifications with a fresh
    // set based on the current dashboard rows and preferences. Members who
    // have already met both goals, or who are disabled in preferences,
    // don't get a notification.
    func rescheduleMissedGoalNotifications(rows: [Dashboard], preferences: NotificationPreferencesStore) async {
        let today = SheetsService.dateFormatter.string(from: Date())

        // Clear out any previously scheduled notifications for today before
        // adding fresh ones — avoids duplicates as data changes throughout the day.
        let pending = await center.pendingNotificationRequests()
        let todaysIdentifiers = pending
            .map(\.identifier)
            .filter { $0.hasPrefix("missedGoal-") && $0.hasSuffix("-\(today)") }
        center.removePendingNotificationRequests(withIdentifiers: todaysIdentifiers)

        guard preferences.allEnabled else { return }

        guard let triggerDate = Self.reminderDate(hour: reminderHour, minute: reminderMinute), triggerDate > Date() else {
            return // Already past reminder time today — nothing more to schedule.
        }

        for row in rows {
            guard preferences.isEnabled(for: row.email) else { continue }
            guard !row.stepsMet || !row.heartRateMet else { continue }

            let content = UNMutableNotificationContent()
            content.title = "\(row.displayName) hasn't hit their goal yet"
            content.body = missedGoalsSummary(for: row)
            content.sound = .default

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let identifier = "missedGoal-\(row.email)-\(today)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    private func missedGoalsSummary(for row: Dashboard) -> String {
        var parts: [String] = []
        if !row.stepsMet {
            parts.append("\(row.stepsRemaining) steps to go")
        }
        if !row.heartRateMet {
            parts.append("\(Int(row.elevatedMinutesRemaining)) elevated HR min to go")
        }
        return parts.joined(separator: " · ")
    }

    private static func reminderDate(hour: Int, minute: Int) -> Date? {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())
    }
}
