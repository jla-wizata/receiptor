import Foundation
import Observation

@Observable
final class ReportViewModel {
    var year: Int = Calendar.current.component(.year, from: Date())
    var isDownloading = false
    var errorMessage: String? = nil
    var pdfURL: URL? = nil

    private let service = ReportService()

    @MainActor
    func download() async {
        isDownloading = true
        errorMessage = nil
        pdfURL = nil
        do {
            let data = try await service.downloadReport(year: year)
            let fileName = "receiptor-report-\(year).pdf"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try data.write(to: url)
            pdfURL = url
        } catch {
            errorMessage = error.localizedDescription
        }
        isDownloading = false
    }
}
