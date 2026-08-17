//
//  FitInApp.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 7/20/26.
//
import SwiftUI
import GoogleSignIn

@main
struct FitInApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var groupSetupViewModel = GroupSetupViewModel()
    @StateObject private var notificationPreferences = NotificationPreferencesStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authViewModel)
                .environmentObject(groupSetupViewModel)
                .environmentObject(notificationPreferences)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .task {
                    await authViewModel.restoreSessionIfAvailable()
                    groupSetupViewModel.restoreGroupIfAvailable()
                }
        }
    }
}

// Switches between sign-in, health permission, group setup, health
// details, goal setting, notification permission, and the main app
// based on current state. Each onboarding step's "handled" flag is
// persisted via @AppStorage so it only shows once ever, not on every
// launch.
private struct RootView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var groupSetupViewModel: GroupSetupViewModel
    @AppStorage("hasHandledHealthPermission") private var hasHandledHealthPermission = false
    @State private var hasHandledHealthDetails = false
    @AppStorage("hasHandledGoalSetting") private var hasHandledGoalSetting = false
    @AppStorage("hasHandledNotificationPermission") private var hasHandledNotificationPermission = false

    var body: some View {
        switch authViewModel.state {
        case .checkingSession:
            LaunchLoadingView()
        case .signedOut:
            SignInView()
        case .signedIn:
            if !hasHandledHealthPermission {
                HealthPermissionView {
                    hasHandledHealthPermission = true
                }
            } else if !groupSetupViewModel.hasGroup {
                GroupSetupView()
            } else if !hasHandledHealthDetails, let spreadsheetId = groupSetupViewModel.currentGroup?.spreadsheetId {
                HealthDetailsSettingView(spreadsheetId: spreadsheetId) {
                    hasHandledHealthDetails = true
                }
            } else if !hasHandledGoalSetting {
                NavigationStack {
                    GoalSettingView {
                        hasHandledGoalSetting = true
                    }
                }
            } else if !hasHandledNotificationPermission {
                NotificationPermissionView {
                    hasHandledNotificationPermission = true
                }
            } else {
                NavBarView()
            }
        }
    }
}
