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

// Switches between sign-in, health permission, group setup, birth date
// onboarding, and the main dashboard based on current state.
private struct RootView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var groupSetupViewModel: GroupSetupViewModel

    // Backed by UserDefaults instead of plain @State, so once a user has
    // gotten past the health permission screen during onboarding, it
    // stays skipped on every future app launch rather than resetting
    // each time RootView is re-created.
    @AppStorage("hasCompletedHealthPermissionOnboarding") private var hasHandledHealthPermission = false
    @State private var hasHandledBirthDate = false

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
            } else if !hasHandledBirthDate, let spreadsheetId = groupSetupViewModel.currentGroup?.spreadsheetId {
                HealthDetailsSettingView(spreadsheetId: spreadsheetId) {
                    hasHandledBirthDate = true
                }
            } else {
                NavBarView()
            }
        }
    }
}
