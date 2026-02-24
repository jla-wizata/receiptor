import Foundation
import Observation

@Observable
final class HolidaysViewModel {
    var userHolidays: [UserHoliday] = []
    var schedulePeriods: [WorkSchedulePeriod] = []
    var publicHolidays: [PublicHoliday] = []
    var isLoading = false
    var errorMessage: String? = nil

    var year: Int = Calendar.current.component(.year, from: Date())

    private let dashboardService = DashboardService()
    private let holidaysService = HolidaysService()

    @MainActor
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let holidaysTask = dashboardService.listHolidays()
            async let scheduleTask = dashboardService.listSchedulePeriods()
            let (h, s) = try await (holidaysTask, scheduleTask)
            userHolidays = h
            schedulePeriods = s
        } catch {
            errorMessage = error.localizedDescription
        }
        // Load public holidays separately — don't fail user data if Nager.Date is unreachable
        do {
            publicHolidays = try await holidaysService.getPublicHolidays(year: year)
        } catch {
            publicHolidays = []
        }
        isLoading = false
    }

    @MainActor
    func createHoliday(startDate: String, endDate: String, description: String?) async {
        do {
            let req = CreateHolidayRequest(startDate: startDate, endDate: endDate, description: description)
            let holiday = try await dashboardService.createHoliday(req)
            userHolidays.append(holiday)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func updateHoliday(id: String, startDate: String, endDate: String, description: String?) async {
        do {
            let req = CreateHolidayRequest(startDate: startDate, endDate: endDate, description: description)
            let updated = try await dashboardService.updateHoliday(id: id, req)
            if let index = userHolidays.firstIndex(where: { $0.id == id }) {
                userHolidays[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func deleteHoliday(id: String) async {
        do {
            try await dashboardService.deleteHoliday(id: id)
            userHolidays.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func createSchedulePeriod(startDate: String, endDate: String?, workingDays: [Int], description: String?) async {
        do {
            let req = CreateSchedulePeriodRequest(startDate: startDate, endDate: endDate,
                                                  workingDays: workingDays, description: description)
            let period = try await dashboardService.createSchedulePeriod(req)
            schedulePeriods.append(period)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func updateSchedulePeriod(id: String, startDate: String, endDate: String?, workingDays: [Int], description: String?) async {
        do {
            let req = CreateSchedulePeriodRequest(startDate: startDate, endDate: endDate,
                                                  workingDays: workingDays, description: description)
            let updated = try await dashboardService.updateSchedulePeriod(id: id, req)
            if let index = schedulePeriods.firstIndex(where: { $0.id == id }) {
                schedulePeriods[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func deleteSchedulePeriod(id: String) async {
        do {
            try await dashboardService.deleteSchedulePeriod(id: id)
            schedulePeriods.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
