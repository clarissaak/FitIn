//
//  SummaryView.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 8/7/26.
//
import SwiftUI

// The Summary tab: today's date, then a widget card per metric (Steps,
// Elevated Heart Rate Minutes), each with today's progress and a small
// recent-history sparkline. 
struct SummaryView: View {
    @EnvironmentObject var groupSetupViewModel: GroupSetupViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = SummaryViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var isShowingAccount = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                        .padding(.top, 12)

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    if let currentUser = authViewModel.currentUser, let spreadsheetId = groupSetupViewModel.currentGroup?.spreadsheetId {
                        let email = currentUser.email ?? ""

                        NavigationLink {
                            TrendsView(email: email, spreadsheetId: spreadsheetId, focusMetric: .steps)
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
                            TrendsView(email: email, spreadsheetId: spreadsheetId, focusMetric: .heartRate)
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
            .navigationBarHidden(true)
            .sheet(isPresented: $isShowingAccount) {
                AccountView()
            }
            .refreshable {
                await refresh()
            }
            .task {
                await refresh()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
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
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.dateHeaderFormatter.string(from: Date()))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Summary")
                    .font(.largeTitle.bold())
            }

            Spacer()

            Button {
                isShowingAccount = true
            } label: {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title)
            }
            .padding(.top, 8)
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
