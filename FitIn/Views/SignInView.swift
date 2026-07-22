//
//  SignInView.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 7/21/26.
//
import SwiftUI
import GoogleSignInSwift
import UIKit

struct SignInView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("FitIn")
                    .font(.largeTitle.bold())
                Text("Share your fitness activity with other users.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            GoogleSignInButton {
                Task {
                    guard let rootVC = Self.topViewController() else { return }
                    await authViewModel.signIn(presenting: rootVC)
                }
            }
            .padding(.horizontal, 32)

            if let errorMessage = authViewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
        .padding()
    }

    // Finds the top-most view controller to present the Google Sign-In flow from.
    private static func topViewController() -> UIViewController? {
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else {
            return nil
        }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}

#Preview {
    SignInView()
        .environmentObject(AuthViewModel())
}
