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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authViewModel)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .task {
                    await authViewModel.restoreSessionIfAvailable()
                }
        }
    }
}

// Switches between the sign-in flow and the main app based on auth state.
private struct RootView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var hasHandledHealthPermission = false
 
    var body: some View {
        switch authViewModel.state {
        case .checkingSession:
            ProgressView()
        case .signedOut:
            SignInView()
        case .signedIn:
            if hasHandledHealthPermission {
                ContentView()
            } else {
                HealthPermissionView {
                    hasHandledHealthPermission = true
                }
            }
        }
    }
}
