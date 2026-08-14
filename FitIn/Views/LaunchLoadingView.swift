//
//  LaunchLoadingView.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 8/13/26.
//


import SwiftUI

// Shown while restoring the signed-in session and group on launch.
// Displays the app logo so the transition from the native launch
// screen feels seamless, with a spinner underneath.
struct LaunchLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)

            ProgressView()
        }
    }
}

#Preview {
    LaunchLoadingView()
}
