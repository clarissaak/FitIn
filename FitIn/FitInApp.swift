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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authViewModel)
                .environmentObject(groupSetupViewModel)
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

// Switches between sign-in, health permission, group setup, and the main
// app based on current state.
private struct RootView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var groupSetupViewModel: GroupSetupViewModel
    @State private var hasHandledHealthPermission = false

    var body: some View {
        switch authViewModel.state {
        case .checkingSession:
            ProgressView()
        case .signedOut:
            SignInView()
        case .signedIn:
            if !hasHandledHealthPermission {
                HealthPermissionView {
                    hasHandledHealthPermission = true
                }
            } else if !groupSetupViewModel.isReadyToProceed {
                GroupSetupView()
            } else {
                // Temporary: swap back to ContentView (or your real dashboard) once Sheets testing is done.
                SheetsTestView()
            }
        }
    }
}
