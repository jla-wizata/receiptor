import SwiftUI

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    LoadingView()
                } else if let summary = viewModel.summary {
                    dashboardContent(summary)
                } else if let error = viewModel.errorMessage {
                    ErrorBanner(message: error, onRetry: { Task { await viewModel.load() } })
                } else {
                    emptyState
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    yearPicker
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gear")
                        }
                        Button(role: .destructive, action: {
                            appState.logout()
                        }) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
            }
            .task { await viewModel.load() }
            .onChange(of: viewModel.year) { Task { await viewModel.load() } }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No data available")
                .font(.headline)
            Button("Retry") { Task { await viewModel.load() } }
                .buttonStyle(.borderedProminent)
        }
    }

    private var yearPicker: some View {
        HStack(spacing: 4) {
            Button { viewModel.year -= 1 } label: {
                Image(systemName: "chevron.left")
                    .imageScale(.small)
            }
            Text(String(viewModel.year))
                .font(.headline)
                .monospacedDigit()
                .frame(minWidth: 48)
            Button { viewModel.year += 1 } label: {
                Image(systemName: "chevron.right")
                    .imageScale(.small)
            }
        }
        .buttonStyle(.borderless)
    }

    @ViewBuilder
    private func dashboardContent(_ summary: DashboardSummary) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                ComplianceStatusBadge(status: summary.complianceStatus)
                    .padding(.top)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(title: "Working Days", value: "\(summary.totalWorkingDays)")
                    StatCard(title: "Days Passed", value: "\(summary.pastWorkingDays)")
                    StatCard(title: "With Proof", value: "\(summary.daysWithProof)", color: .green)
                    StatCard(title: "Without Proof", value: "\(summary.daysWithoutProof)",
                             color: summary.daysWithoutProof > 0 ? .orange : .primary)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Home-working usage")
                        .font(.headline)
                        .padding(.horizontal)

                    let progress = Double(summary.daysWithoutProof) / Double(max(summary.homeworkingThreshold, 1))
                    ProgressView(value: min(progress, 1.0))
                        .tint(progress >= 1.0 ? .red : progress > 0.8 ? .orange : .green)
                        .padding(.horizontal)

                    HStack {
                        Text("\(summary.daysWithoutProof) / \(summary.homeworkingThreshold) days used")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(summary.remainingAllowedHomeworkingDays) remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label("Year-end forecast", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.headline)
                    Text("Estimated \(summary.forecastedDaysWithoutProof) days without proof by Dec 31")
                        .font(.body)
                        .foregroundColor(
                            summary.forecastedDaysWithoutProof > summary.homeworkingThreshold ? .red : .primary
                        )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
        .refreshable { await viewModel.load() }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title)
                .bold()
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
