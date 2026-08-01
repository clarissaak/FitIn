//
//  GoalSettingView.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 7/29/26.
//
import SwiftUI

// Lets the user set their three goals: daily step count, the heart rate
// threshold they're tracking, and how many minutes above that threshold
// they're aiming for each day. The heart rate threshold's range is based
// on the user's age (via Health app date of birth) when available.
struct GoalSettingView: View {
    @EnvironmentObject var groupSetupViewModel: GroupSetupViewModel
    @StateObject private var goalViewModel = GoalViewModel()

    var body: some View {
        Form {
            Section {
                Stepper(value: $goalViewModel.stepsGoal, in: 1_000...50_000, step: 500) {
                    goalLabel(title: "Steps Goal", value: "\(goalViewModel.stepsGoal)", recommended: "\(User.defaultStepsGoal)")
                }
            } header: {
                Text("Daily Steps")
            }

            Section {
                Stepper(value: $goalViewModel.heartRateGoal, in: goalViewModel.heartRateRange, step: 5) {
                    goalLabel(title: "Heart Rate Threshold", value: "\(goalViewModel.heartRateGoal) BPM", recommended: recommendedHeartRateText)
                }
            } header: {
                Text("Heart Rate Threshold")
            } footer: {
                if let age = goalViewModel.age {
                    Text("Based on your age (\(age)), a moderate-to-vigorous exercise range is roughly \(goalViewModel.heartRateRange.lowerBound)-\(goalViewModel.heartRateRange.upperBound) BPM.")
                } else {
                    Text("Using a general range since your birth date isn't on file yet.")
                }
            }

            Section {
                Stepper(value: $goalViewModel.elevatedMinutesGoal, in: 5...180, step: 5) {
                    goalLabel(title: "Elevated Minutes Goal", value: "\(Int(goalViewModel.elevatedMinutesGoal)) min", recommended: "\(Int(User.defaultElevatedMinutesGoal)) min")
                }
            } header: {
                Text("Elevated Heart Rate Minutes")
            } footer: {
                Text("How many minutes per day you're aiming to spend above your heart rate threshold.")
            }

            if let errorMessage = goalViewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }

            Section {
                Button {
                    Task {
                        if let spreadsheetId = groupSetupViewModel.currentGroup?.spreadsheetId {
                            await goalViewModel.saveGoals(spreadsheetId: spreadsheetId)
                        }
                    }
                } label: {
                    if goalViewModel.isSaving {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Save Goals").frame(maxWidth: .infinity)
                    }
                }
                .disabled(goalViewModel.isSaving || goalViewModel.isLoading)
            }
        }
        .navigationTitle("Your Goals")
        .task {
            if let spreadsheetId = groupSetupViewModel.currentGroup?.spreadsheetId {
                await goalViewModel.loadGoals(spreadsheetId: spreadsheetId)
            }
        }
        .overlay {
            if goalViewModel.isLoading {
                ProgressView()
            }
        }
    }

    private var recommendedHeartRateText: String {
        if goalViewModel.age != nil {
            return "\(goalViewModel.heartRateRange.lowerBound)-\(goalViewModel.heartRateRange.upperBound) BPM"
        } else {
            return "\(User.defaultHeartRateGoal) BPM"
        }
    }

    private func goalLabel(title: String, value: String, recommended: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text("\(value) · (Recommended: \(recommended))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        GoalSettingView()
            .environmentObject(GroupSetupViewModel())
    }
}
