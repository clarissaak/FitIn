//
//  FitInApp.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 7/20/26.
//
import SwiftUI
import GoogleSignIn
import BackgroundTasks

private let dailyUploadTaskIdentifier = "com.clarissakristanto.FitIn.dailyUpload"

@main
struct FitInApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var groupSetupViewModel = GroupSetupViewModel()
    @StateObject private var notificationPreferences = NotificationPreferencesStore()

    init() {
        registerBackgroundTasks()
        Task {
            await HealthKitService.shared.enableBackgroundDelivery()
            HealthKitService.shared.startObservingHealthChanges {
                await handleHealthDataChanged()
            }
        }
    }

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
                    await groupSetupViewModel.restoreGroupIfAvailable()
                    scheduleNextDailyUpload()
                }
        }
    }

    // Registers the periodic fallback task. Kept as a companion to the
    // HealthKit observer above — the observer reacts to real data
    // changes and is the primary path, this is a safety net for
    // whatever window it misses.
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: dailyUploadTaskIdentifier,
            using: nil
        ) { task in
            handleDailyUploadTask(task as! BGAppRefreshTask)
        }
    }

    private func handleDailyUploadTask(_ task: BGAppRefreshTask) {
        scheduleNextDailyUpload()

        let refreshTask = Task {
            guard let spreadsheetId = GroupService.shared.restoreCurrentGroup()?.spreadsheetId else {
                task.setTaskCompleted(success: false)
                return
            }
            await DailyUploadCoordinator.shared.uploadRecentDaysIfNeeded(spreadsheetId: spreadsheetId, dayCount: 7)
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            refreshTask.cancel()
        }
    }

    private func scheduleNextDailyUpload() {
        let request = BGAppRefreshTaskRequest(identifier: dailyUploadTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}

// Called whenever the HealthKit observer fires (new step or heart rate
// data written). Free function, not a method — avoids capturing the App
// struct's `self` in the escaping closure passed to HealthKit.
func handleHealthDataChanged() async {
    guard let spreadsheetId = GroupService.shared.restoreCurrentGroup()?.spreadsheetId else { return }
    await DailyUploadCoordinator.shared.uploadTodayIfNeeded(spreadsheetId: spreadsheetId)
}

// Switches between sign-in, health permission, group setup, awaiting
// approval, health details, goal setting, notification permission, and
// the main app based on current state. Each onboarding step's "handled"
// flag is persisted via @AppStorage so it only shows once ever, not on
// every launch.
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
            } else if groupSetupViewModel.isPendingApproval {
                AwaitingApprovalView()
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
