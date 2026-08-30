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
    private let reminderHour = 22 // 10:30 PM local time
    private let reminderMinute = 30

    // Requests permission to show notifications. Safe to call repeatedly —
    // iOS only prompts once; afterward this just reports the current status.
    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    // Replaces today's scheduled missed-goal notification with a fresh one
    // based on the current dashboard rows and preferences.
    func rescheduleMissedGoalNotifications(rows: [Dashboard], preferences: NotificationPreferencesStore) async {
        let today = SheetsService.dateFormatter.string(from: Date())

        // Clear out any previously scheduled notification for today before
        // adding a fresh one — avoids duplicates as data changes throughout
        // the day, and also handles the case where the user just turned
        // notifications off 
        let pending = await center.pendingNotificationRequests()
        let todaysIdentifiers = pending
            .map(\.identifier)
            .filter { $0.hasPrefix("missedGoal-") && $0.hasSuffix("-\(today)") }
        center.removePendingNotificationRequests(withIdentifiers: todaysIdentifiers)

        guard preferences.allEnabled else { return }

        // The master toggle defaults to on, so the settings screen's
        // onChange (which normally triggers the permission prompt) may
        // never fire. Check status directly and request here if needed —
        // otherwise notifications can be "scheduled" but never delivered.
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            let granted = await requestAuthorization()
            guard granted else { return }
        } else if settings.authorizationStatus == .denied {
            return
        }

        guard let triggerDate = Self.reminderDate(hour: reminderHour, minute: reminderMinute), triggerDate > Date() else {
            return // Already past reminder time today — nothing more to schedule.
        }

        let missedRows = rows.filter { row in
            preferences.isEnabled(for: row.email) && (!row.stepsMet || !row.heartRateMet)
        }

        guard !missedRows.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = missedGoalsTitle(for: missedRows)
        content.body = "Haven't hit their goal for today yet."
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        // A single identifier per day (no longer per-member)
        let identifier = "missedGoal-\(today)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    // Joins display names into a list
    private func missedGoalsTitle(for rows: [Dashboard]) -> String {
        let names = rows.map(\.displayName)

        switch names.count {
        case 1:
            return "\(names[0]) hasn't hit their goal yet"
        case 2:
            return "\(names[0]) and \(names[1]) haven't hit their goals yet"
        default:
            let allButLast = names.dropLast().joined(separator: ", ")
            let last = names.last ?? ""
            return "\(allButLast), and \(last) haven't hit their goals yet"
        }
    }

    private static func reminderDate(hour: Int, minute: Int) -> Date? {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())
    }
}
