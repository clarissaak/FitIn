//
//  NavBarView.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 8/8/26.
//
import SwiftUI

// The main tab bar once onboarding is complete: Summary (personal
// dashboard), Sharing (group progress), and Account.
struct NavBarView: View {
    var body: some View {
        TabView {
            SummaryView()
                .tabItem {
                    Label("Summary", systemImage: "chart.bar.fill")
                }

            DashboardView()
                .tabItem {
                    Label("Sharing", systemImage: "person.2.fill")
                }

            AccountView()
                .tabItem {
                    Label("Account", systemImage: "person.crop.circle.fill")
                }
        }
    }
}

#Preview {
    NavBarView()
        .environmentObject(GroupSetupViewModel())
        .environmentObject(AuthViewModel())
        .environmentObject(NotificationPreferencesStore())
}
