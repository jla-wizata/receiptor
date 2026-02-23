import SwiftUI
import UIKit

struct ReportView: View {
    @State private var viewModel = ReportViewModel()
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 72))
                        .foregroundColor(.accentColor)
                    Text("Annual Compliance Report")
                        .font(.title2)
                        .bold()
                    Text("Download a PDF summary of your receipts and compliance status for the selected year.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                HStack {
                    Button { viewModel.year -= 1 } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.borderless)

                    Text(String(viewModel.year))
                        .font(.largeTitle)
                        .bold()
                        .monospacedDigit()
                        .frame(minWidth: 80)

                    Button { viewModel.year += 1 } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.borderless)
                }

                Button(action: { Task { await viewModel.download() } }) {
                    Group {
                        if viewModel.isDownloading {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Generating PDF...")
                            }
                        } else {
                            Label("Download Report", systemImage: "arrow.down.doc.fill")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isDownloading)
                .padding(.horizontal, 32)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("Report")
            .onChange(of: viewModel.pdfURL) { _, url in
                if url != nil { showShareSheet = true }
            }
            .sheet(isPresented: $showShareSheet, onDismiss: { viewModel.pdfURL = nil }) {
                if let url = viewModel.pdfURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }
}

// MARK: - UIActivityViewController wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
