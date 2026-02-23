import Foundation
import Observation

@Observable
final class DashboardViewModel {
    var summary: DashboardSummary? = nil
    var isLoading = false
    var errorMessage: String? = nil
    var year: Int = Calendar.current.component(.year, from: Date())

    private let service = DashboardService()

    @MainActor
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            summary = try await service.getSummary(year: year)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
