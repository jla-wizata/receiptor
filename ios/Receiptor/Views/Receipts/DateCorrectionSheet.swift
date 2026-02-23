import SwiftUI

struct DateCorrectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let receipt: Receipt
    let viewModel: ReceiptListViewModel?
    var onUpdate: ((Receipt) -> Void)? = nil

    @State private var selectedDate: Date = Date()
    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    private let receiptsService = ReceiptsService()
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init(receipt: Receipt, viewModel: ReceiptListViewModel?, onUpdate: ((Receipt) -> Void)? = nil) {
        self.receipt = receipt
        self.viewModel = viewModel
        self.onUpdate = onUpdate
        // Pre-fill existing date if available
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        if let ds = receipt.receiptDate, let d = fmt.date(from: ds) {
            _selectedDate = State(initialValue: d)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("Date Correction Needed")
                        .font(.headline)
                    Text("The OCR could not extract a date automatically. Please select the receipt date.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)

                DatePicker(
                    "Receipt Date",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal)

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Button(action: saveDate) {
                    Group {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Confirm Date")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Set Receipt Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Skip") { dismiss() }
                }
            }
        }
    }

    private func saveDate() {
        let dateString = dateFormatter.string(from: selectedDate)
        isSaving = true
        Task {
            if let vm = viewModel {
                await vm.updateDate(id: receipt.id, date: dateString)
            } else {
                do {
                    let updated = try await receiptsService.updateDate(id: receipt.id, date: dateString)
                    await MainActor.run { onUpdate?(updated) }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        isSaving = false
                        return
                    }
                }
            }
            await MainActor.run { dismiss() }
        }
    }
}
