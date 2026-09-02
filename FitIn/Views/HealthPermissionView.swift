//
//  HealthPermissionView.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 7/22/26.
//
import SwiftUI

// Explains why FitIn needs HealthKit access and triggers the system
// permission sheet. Present this before relying on step data elsewhere
// in the app.
struct HealthPermissionView: View {
    var onAuthorizationHandled: () -> Void

    @State private var isRequesting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "figure.walk")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("Connect Health Data")
                    .font(.title2.bold())
                Text("FitIn reads your activity data to share your progress with other users. Your data stays private until you choose to share it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button {
                requestAccess()
            } label: {
                if isRequesting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Connect Health")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .disabled(isRequesting)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .padding()
    }

    private func requestAccess() {
        errorMessage = nil
        isRequesting = true
        Task {
            do {
                try await HealthKitService.shared.requestAuthorization()

                // Activate background delivery + the change observer right
                // away, rather than waiting for the next app launch (when
                // FitInApp's init() would otherwise pick this up). Without
                // this, there'd be a window on fresh installs where the
                // observer stays inert until the user relaunches the app.
                await HealthKitService.shared.enableBackgroundDelivery()
                HealthKitService.shared.startObservingHealthChanges {
                    await handleHealthDataChanged()
                }

                isRequesting = false
                onAuthorizationHandled()
            } catch {
                isRequesting = false
                errorMessage = "Couldn't access Health data. You can enable it later in Settings > Health > Data Access & Devices."
            }
        }
    }
}

#Preview {
    HealthPermissionView(onAuthorizationHandled: {})
}
