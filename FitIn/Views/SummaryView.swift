//
//  SummaryView.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 8/7/26.
//
import SwiftUI

// The Summary tab: today's date, then a widget card per metric (Steps,
// Elevated Heart Rate Minutes), each with today's progress and a small
// recent-history sparkline. Styled after Apple Fitness's Summary tab.
struct SummaryView: View {
    @EnvironmentObject var groupSetupViewModel: GroupSetupViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = SummaryViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    if let currentUser = authViewModel.currentUser, let spreadsheetId = groupSetupViewModel.currentGroup?.spreadsheetId {
                        let email = currentUser.email ?? ""

                        NavigationLink {
                            TrendsView(email: email, displayName: "My Trends", spreadsheetId: spreadsheetId, focusMetric: .steps)
                        } label: {
                            SummaryMetricWidget(
                                icon: "figure.walk",
                                title: "Steps",
                                color: .green,
                                currentValueText: "\(viewModel.todaySteps)",
                                goalText: "\(viewModel.stepGoal)",
                                progress: viewModel.stepGoal > 0 ? Double(viewModel.todaySteps) / Double(viewModel.stepGoal) : 0,
                                points: viewModel.stepsSparkline
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            TrendsView(email: email, displayName: "My Trends", spreadsheetId: spreadsheetId, focusMetric: .heartRate)
                        } label: {
                            SummaryMetricWidget(
                                icon: "heart.fill",
                                title: "Elevated Heart Rate",
                                color: .red,
                                currentValueText: "\(Int(viewModel.todayElevatedMinutes)) min",
                                goalText: "\(Int(viewModel.elevatedMinutesGoal)) min",
                                progress: viewModel.elevatedMinutesGoal > 0 ? viewModel.todayElevatedMinutes / viewModel.elevatedMinutesGoal : 0,
                                points: viewModel.heartRateSparkline
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink("Goals") {
                        GoalSettingView()
                    }
                }
            }
            .refreshable {
                await refresh()
            }
            .task {
                await refresh()
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    Task { await refresh() }
                }
            }
            .overlay {
                if viewModel.isLoading && viewModel.stepsSparkline.isEmpty {
                    ProgressView()
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Self.dateHeaderFormatter.string(from: Date()))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Summary")
                .font(.largeTitle.bold())
        }
    }

    private func refresh() async {
        guard let spreadsheetId = groupSetupViewModel.currentGroup?.spreadsheetId else { return }
        await viewModel.refresh(spreadsheetId: spreadsheetId)
    }

    private static let dateHeaderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()
}

#Preview {
    SummaryView()
        .environmentObject(GroupSetupViewModel())
        .environmentObject(AuthViewModel())
}
