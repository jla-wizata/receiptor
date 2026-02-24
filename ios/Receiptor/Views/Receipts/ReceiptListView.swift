import SwiftUI

struct ReceiptListView: View {
    @State private var viewModel = ReceiptListViewModel()
    @State private var showCapture = false
    @State private var showFilter = false
    @State private var selectedReceipt: Receipt? = nil
    @State private var receiptToDelete: Receipt? = nil

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
            .navigationDestination(item: $selectedReceipt) { receipt in
                ReceiptDetailView(receipt: receipt)
            }
            .alert(
                "Delete Receipt",
                isPresented: Binding(
                    get: { receiptToDelete != nil },
                    set: { if !$0 { receiptToDelete = nil } }
                )
            ) {
                Button("Delete", role: .destructive) {
                    if let r = receiptToDelete {
                        Task { await viewModel.delete(id: r.id) }
                    }
                    receiptToDelete = nil
                }
                Button("Cancel", role: .cancel) { receiptToDelete = nil }
            } message: {
                Text("This receipt and its image will be permanently deleted.")
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
                            Button { selectedReceipt = receipt } label: {
                                Image(systemName: "pencil")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.borderless)
                            Button {
                                receiptToDelete = receipt
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.appDanger)
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

    @State private var start: Date
    @State private var end: Date
    @State private var showFromPicker = false
    @State private var showToPicker = false

    private let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; return f
    }()

    init(viewModel: ReceiptListViewModel) {
        self.viewModel = viewModel
        _start = State(initialValue: viewModel.filterStart ?? ReceiptListViewModel.currentYearStart())
        _end = State(initialValue: viewModel.filterEnd ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Quick Select") {
                    Button("This Year") { applyPreset(thisYear: true) }
                    Button("Last 3 Months") { applyPreset(months: 3) }
                    Button("Last 6 Months") { applyPreset(months: 6) }
                    Button("All Time") { applyAllTime() }
                }
                .foregroundColor(.primary)

                Section("Custom Range") {
                    Button {
                        showFromPicker = true
                    } label: {
                        HStack {
                            Text("From").foregroundColor(.primary)
                            Spacer()
                            Text(dateFmt.string(from: start)).foregroundColor(.secondary)
                        }
                    }
                    Button {
                        showToPicker = true
                    } label: {
                        HStack {
                            Text("To").foregroundColor(.primary)
                            Spacer()
                            Text(dateFmt.string(from: end)).foregroundColor(.secondary)
                        }
                    }
                    Button("Apply Custom Range") { apply() }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showFromPicker) {
                DatePickerSheet(title: "From", date: $start, max: end)
            }
            .sheet(isPresented: $showToPicker) {
                DatePickerSheet(title: "To", date: $end, min: start)
            }
        }
    }

    private func applyPreset(thisYear: Bool = false, months: Int? = nil) {
        if thisYear {
            viewModel.filterStart = ReceiptListViewModel.currentYearStart()
            viewModel.filterEnd = ReceiptListViewModel.currentYearEnd()
        } else if let m = months {
            viewModel.filterEnd = Date()
            viewModel.filterStart = Calendar.current.date(byAdding: .month, value: -m, to: Date())!
        }
        Task { await viewModel.load() }
        dismiss()
    }

    private func applyAllTime() {
        viewModel.filterStart = nil
        viewModel.filterEnd = nil
        Task { await viewModel.load() }
        dismiss()
    }

    private func apply() {
        viewModel.filterStart = start
        viewModel.filterEnd = end
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
        case "success": return .appSuccess
        case "manual": return .appSuccess
        case "no_date_found": return .appAccent
        default: return .red
        }
    }

    private var ocrStatusLabel: String {
        switch receipt.ocrStatus {
        case "success": return "Date auto-detected"
        case "manual": return "Date filled"
        case "no_date_found": return "No date found"
        default: return "Date detection failed"
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
