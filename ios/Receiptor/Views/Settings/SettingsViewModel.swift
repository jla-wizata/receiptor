import Foundation
import Observation

@Observable
final class SettingsViewModel {
    var settings: UserSettings? = nil
    var countries: [Country] = []
    var isLoading = false
    var isSaving = false
    var errorMessage: String? = nil
    var successMessage: String? = nil

    // Editable fields
    var workingCountryCode: String = ""
    var residenceCountryCode: String = ""
    var homeworkingThreshold: Int = 34
    var workingDays: Set<Int> = [0, 1, 2, 3, 4]

    private let dashboardService = DashboardService()
    private let holidaysService = HolidaysService()

    @MainActor
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let settingsTask = dashboardService.getSettings()
            async let countriesTask = holidaysService.getCountries()
            let (s, c) = try await (settingsTask, countriesTask)
            settings = s
            countries = c
            populateFields(from: s)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func populateFields(from s: UserSettings) {
        workingCountryCode = s.workingCountryCode
        residenceCountryCode = s.residenceCountryCode
        homeworkingThreshold = s.homeworkingThreshold
        workingDays = Set(s.workingDays)
    }

    @MainActor
    func save() async {
        isSaving = true
        errorMessage = nil
        successMessage = nil
        do {
            let request = UpdateSettingsRequest(
                workingCountryCode: workingCountryCode,
                residenceCountryCode: residenceCountryCode,
                homeworkingThreshold: homeworkingThreshold,
                workingDays: Array(workingDays).sorted()
            )
            settings = try await dashboardService.updateSettings(request)
            successMessage = "Settings saved"
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
