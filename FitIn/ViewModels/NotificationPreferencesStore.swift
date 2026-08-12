//
//  NotificationPreferencesStore.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 8/11/26.
//
import Foundation
import Combine

// Holds notification preferences: a master on/off switch, plus a
// per-member override (keyed by email). Defaults to "on" for everyone
// unless explicitly turned off. Persisted to UserDefaults.
@MainActor
final class NotificationPreferencesStore: ObservableObject {

    @Published var allEnabled: Bool {
        didSet { UserDefaults.standard.set(allEnabled, forKey: Keys.allEnabled) }
    }

    @Published private var perMemberEnabled: [String: Bool] {
        didSet {
            if let data = try? JSONEncoder().encode(perMemberEnabled) {
                UserDefaults.standard.set(data, forKey: Keys.perMember)
            }
        }
    }

    private enum Keys {
        static let allEnabled = "notifications.allEnabled"
        static let perMember = "notifications.perMember"
    }

    init() {
        allEnabled = UserDefaults.standard.object(forKey: Keys.allEnabled) as? Bool ?? true
        if let data = UserDefaults.standard.data(forKey: Keys.perMember),
           let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) {
            perMemberEnabled = decoded
        } else {
            perMemberEnabled = [:]
        }
    }

    // Whether a specific member's missed-goal notifications should fire —
    // true unless the master switch is off, or they've been individually
    // turned off. Defaults to true (not yet set) for any member.
    func isEnabled(for email: String) -> Bool {
        allEnabled && (perMemberEnabled[email] ?? true)
    }

    func setEnabled(_ enabled: Bool, for email: String) {
        perMemberEnabled[email] = enabled
    }
}
