//
//  ContentView.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 7/20/26.
//

import SwiftUI

// Temporary debug view to confirm HealthKit step data is flowing correctly.

struct ContentView: View {
    @State private var steps: Double?
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Today's Steps")
                .font(.headline)
                .foregroundStyle(.secondary)

            if isLoading {
                ProgressView()
            } else if let steps {
                Text("\(Int(steps))")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button("Refresh") {
                loadSteps()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .task {
            loadSteps()
        }
    }

    private func loadSteps() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                steps = try await HealthKitService.shared.todaysSteps()
            } catch {
                errorMessage = "Couldn't load steps: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}

#Preview {
    ContentView()
}
