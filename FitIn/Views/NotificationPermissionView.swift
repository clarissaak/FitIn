//
//  NotificationPermissionView.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 8/15/26.
//


import SwiftUI

// Shown once, during onboarding, to explain and trigger the notification
// permission prompt. The app root tracks completion via @AppStorage
// so this never shows again after the first time.
struct NotificationPermissionView: View {
    var onComplete: () -> Void

    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bell.badge")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("Stay on Track")
                    .font(.title2.bold())
                Text("FitIn can remind you if you or other users in your group haven't hit your goals for the day. You can turn this off anytime in Account > Notifications.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button {
                requestPermission()
            } label: {
                if isRequesting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Enable Notifications")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .disabled(isRequesting)

            Button("Not Now") {
                onComplete()
            }
            .font(.footnote)
            .padding(.bottom, 8)

            Spacer()
        }
        .padding()
    }

    private func requestPermission() {
        isRequesting = true
        Task {
            await NotificationService.shared.requestAuthorization()
            isRequesting = false
            onComplete()
        }
    }
}

#Preview {
    NotificationPermissionView(onComplete: {})
}
