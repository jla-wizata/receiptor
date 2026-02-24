import SwiftUI
import UIKit

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = DashboardViewModel()
    @State private var isDownloadingReport = false
    @State private var reportError: String? = nil
    @State private var reportURL: URL? = nil
    @State private var showReportShare = false
    private let reportService = ReportService()

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
            .sheet(isPresented: $showReportShare, onDismiss: { reportURL = nil }) {
                if let url = reportURL { ShareSheet(items: [url]) }
            }
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

                reportSection
            }
            .padding(.bottom)
        }
        .refreshable { await viewModel.load() }
    }

    private var reportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Annual Report", systemImage: "doc.richtext")
                .font(.headline)
            if let error = reportError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            Button(action: downloadReport) {
                Group {
                    if isDownloadingReport {
                        HStack(spacing: 8) { ProgressView(); Text("Generating PDF...") }
                    } else {
                        Label("Download PDF – \(String(viewModel.year))", systemImage: "arrow.down.doc.fill")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .disabled(isDownloadingReport)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func downloadReport() {
        isDownloadingReport = true
        reportError = nil
        Task {
            do {
                let data = try await reportService.downloadReport(year: viewModel.year)
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("receiptor-\(String(viewModel.year)).pdf")
                try data.write(to: url)
                await MainActor.run {
                    reportURL = url
                    showReportShare = true
                    isDownloadingReport = false
                }
            } catch {
                await MainActor.run {
                    reportError = error.localizedDescription
                    isDownloadingReport = false
                }
            }
        }
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
