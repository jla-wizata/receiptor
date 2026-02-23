import SwiftUI

struct ReceiptListView: View {
    @State private var viewModel = ReceiptListViewModel()
    @State private var showCapture = false
    @State private var showFilter = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    LoadingView()
                } else if viewModel.receipts.isEmpty {
                    emptyState
                } else {
                    receiptList
                }
            }
            .navigationTitle("Receipts")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showFilter = true } label: {
                        Image(systemName: viewModel.isDefaultFilter ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCapture = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .overlay {
                if viewModel.isUploading { uploadingOverlay }
            }
            .sheet(isPresented: $showCapture) {
                ReceiptCaptureView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showDateCorrection) {
                if let receipt = viewModel.uploadedReceipt {
                    DateCorrectionSheet(receipt: receipt, viewModel: viewModel)
                }
            }
            .sheet(isPresented: $showFilter) {
                ReceiptFilterSheet(viewModel: viewModel)
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil), actions: {
                Button("OK") { viewModel.errorMessage = nil }
            }, message: {
                Text(viewModel.errorMessage ?? "")
            })
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No receipts")
                .font(.headline)
            Text(viewModel.isDefaultFilter ? "Tap + to scan your first receipt" : "No receipts in this period")
                .font(.subheadline)
                .foregroundColor(.secondary)
            if viewModel.isDefaultFilter {
                Button("Add Receipt") { showCapture = true }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var uploadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView().scaleEffect(1.5).tint(.white)
                Text("Uploading receipt...").foregroundColor(.white).font(.headline)
            }
        }
    }

    private var receiptList: some View {
        List {
            ForEach(viewModel.groupedReceipts, id: \.key) { group in
                Section(group.key) {
                    ForEach(group.value) { receipt in
                        HStack {
                            ReceiptRow(receipt: receipt)
                            Spacer()
                            NavigationLink(destination: ReceiptDetailView(receipt: receipt)) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.borderless)
                            Button {
                                Task { await viewModel.delete(id: receipt.id) }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Filter Sheet

struct ReceiptFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ReceiptListViewModel

    // Local copies so changes only apply on "Apply"
    @State private var start: Date
    @State private var end: Date
    @State private var isAllTime: Bool

    init(viewModel: ReceiptListViewModel) {
        self.viewModel = viewModel
        _start = State(initialValue: viewModel.filterStart ?? ReceiptListViewModel.currentYearStart())
        _end = State(initialValue: viewModel.filterEnd ?? Date())
        _isAllTime = State(initialValue: viewModel.filterStart == nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Quick Select") {
                    Button("This Year") { applyPreset(thisYear: true) }
                    Button("Last 3 Months") { applyPreset(months: 3) }
                    Button("Last 6 Months") { applyPreset(months: 6) }
                    Button("All Time") { isAllTime = true }
                }
                .foregroundColor(.primary)

                if !isAllTime {
                    Section("Custom Range") {
                        DatePicker("From", selection: $start, in: ...end, displayedComponents: .date)
                            .onChange(of: start) { isAllTime = false }
                        DatePicker("To", selection: $end, in: start..., displayedComponents: .date)
                            .onChange(of: end) { isAllTime = false }
                    }
                } else {
                    Section {
                        Text("Showing all receipts").foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") { apply() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func applyPreset(thisYear: Bool = false, months: Int? = nil) {
        isAllTime = false
        if thisYear {
            start = ReceiptListViewModel.currentYearStart()
            end = ReceiptListViewModel.currentYearEnd()
        } else if let m = months {
            end = Date()
            start = Calendar.current.date(byAdding: .month, value: -m, to: Date())!
        }
    }

    private func apply() {
        viewModel.filterStart = isAllTime ? nil : start
        viewModel.filterEnd = isAllTime ? nil : end
        Task { await viewModel.load() }
        dismiss()
    }
}

// MARK: - Receipt Row

struct ReceiptRow: View {
    let receipt: Receipt

    private var displayDate: String {
        guard let ds = receipt.receiptDate else { return "Date unknown" }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: ds) else { return ds }
        let out = DateFormatter()
        out.dateFormat = "EEE, MMM d"
        return out.string(from: date)
    }

    private var ocrStatusColor: Color {
        switch receipt.ocrStatus {
        case "success": return .green
        case "manual": return .blue
        default: return .orange
        }
    }

    private var ocrStatusLabel: String {
        switch receipt.ocrStatus {
        case "success": return "OCR"
        case "manual": return "Manual"
        case "no_date_found": return "No date"
        default: return "Failed"
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayDate).font(.body)
                if let notes = receipt.notes, !notes.isEmpty {
                    Text(notes).font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            Text(ocrStatusLabel)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(ocrStatusColor.opacity(0.2))
                .foregroundColor(ocrStatusColor)
                .cornerRadius(4)
        }
    }
}
