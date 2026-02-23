import Foundation
import Observation

@Observable
final class ReceiptListViewModel {
    var receipts: [Receipt] = []
    var isLoading = false
    var isUploading = false
    var errorMessage: String? = nil
    var uploadedReceipt: Receipt? = nil
    var showDateCorrection = false

    // Filter: default = current year; nil = no bound (all time)
    var filterStart: Date? = ReceiptListViewModel.currentYearStart()
    var filterEnd: Date? = ReceiptListViewModel.currentYearEnd()

    private let service = ReceiptsService()
    private let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    var isDefaultFilter: Bool {
        guard let s = filterStart, let e = filterEnd else { return false }
        let def = (ReceiptListViewModel.currentYearStart(), ReceiptListViewModel.currentYearEnd())
        return Calendar.current.isDate(s, inSameDayAs: def.0) &&
               Calendar.current.isDate(e, inSameDayAs: def.1)
    }

    static func currentYearStart() -> Date {
        let year = Calendar.current.component(.year, from: Date())
        return Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1))!
    }

    static func currentYearEnd() -> Date {
        let year = Calendar.current.component(.year, from: Date())
        return Calendar.current.date(from: DateComponents(year: year, month: 12, day: 31))!
    }

    @MainActor
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await service.list(
                startDate: filterStart.map { dateFmt.string(from: $0) },
                endDate: filterEnd.map { dateFmt.string(from: $0) }
            )
            receipts = result.receipts
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    func upload(imageData: Data) async {
        isUploading = true
        errorMessage = nil
        do {
            let receipt = try await service.upload(imageData: imageData)
            uploadedReceipt = receipt
            receipts.insert(receipt, at: 0)
            if receipt.ocrStatus != "success" {
                showDateCorrection = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isUploading = false
    }

    @MainActor
    func delete(id: String) async {
        do {
            try await service.delete(id: id)
            receipts.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func updateDate(id: String, date: String) async {
        do {
            let updated = try await service.updateDate(id: id, date: date)
            if let index = receipts.firstIndex(where: { $0.id == id }) {
                receipts[index] = updated
            }
            if uploadedReceipt?.id == id {
                uploadedReceipt = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // No-date receipts first, then months newest → oldest
    var groupedReceipts: [(key: String, value: [Receipt])] {
        let inputFmt = DateFormatter()
        inputFmt.dateFormat = "yyyy-MM-dd"
        let headerFmt = DateFormatter()
        headerFmt.dateFormat = "MMMM yyyy"

        var groups: [String: [Receipt]] = [:]
        for receipt in receipts {
            let key: String
            if let ds = receipt.receiptDate, let d = inputFmt.date(from: ds) {
                key = headerFmt.string(from: d)
            } else {
                key = "No Date"
            }
            groups[key, default: []].append(receipt)
        }

        return groups.sorted { a, b in
            if a.key == "No Date" { return true }
            if b.key == "No Date" { return false }
            return a.key > b.key
        }
    }
}
