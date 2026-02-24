import SwiftUI

struct ReceiptDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var receipt: Receipt
    @State private var showDateCorrection = false

    init(receipt: Receipt) {
        _receipt = State(initialValue: receipt)
    }

    private var displayDate: String {
        guard let ds = receipt.receiptDate else { return "Not available" }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let d = fmt.date(from: ds) else { return ds }
        let out = DateFormatter()
        out.dateStyle = .long
        return out.string(from: d)
    }

    private var ocrStatusText: String {
        switch receipt.ocrStatus {
        case "success": return "Date extracted via OCR"
        case "manual": return "Date set manually"
        case "no_date_found": return "No date found by OCR"
        case "failed": return "OCR failed"
        default: return receipt.ocrStatus
        }
    }

    private var ocrStatusColor: Color {
        switch receipt.ocrStatus {
        case "success": return .green
        case "manual": return .blue
        default: return .orange
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let urlStr = receipt.imageUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                                .frame(height: 300)
                                .overlay(ProgressView())
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(12)
                        case .failure:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                                .frame(height: 200)
                                .overlay(
                                    Label("Image unavailable", systemImage: "photo.slash")
                                        .foregroundColor(.secondary)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 12) {
                    InfoRow(label: "Date", value: displayDate)
                    InfoRow(label: "OCR Status", value: ocrStatusText, valueColor: ocrStatusColor)
                    if let notes = receipt.notes, !notes.isEmpty {
                        InfoRow(label: "Notes", value: notes)
                    }
                    InfoRow(label: "ID", value: String(receipt.id.prefix(8)) + "...")
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)

                Button {
                    showDateCorrection = true
                } label: {
                    Label("Correct Date", systemImage: "calendar.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Receipt")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDateCorrection) {
            DateCorrectionSheet(receipt: receipt, viewModel: nil) { updated in
                receipt = updated
                dismiss()
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.body)
                .foregroundColor(valueColor)
            Spacer()
        }
    }
}
