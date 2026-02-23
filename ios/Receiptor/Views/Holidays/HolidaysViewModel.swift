import Foundation
import Observation

@Observable
final class HolidaysViewModel {
    var userHolidays: [UserHoliday] = []
    var schedulePeriods: [WorkSchedulePeriod] = []
    var isLoading = false
    var errorMessage: String? = nil

    private let service = DashboardService()

    @MainActor
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let holidaysTask = service.listHolidays()
            async let scheduleTask = service.listSchedulePeriods()
            let (h, s) = try await (holidaysTask, scheduleTask)
            userHolidays = h
            schedulePeriods = s
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    func createHoliday(startDate: String, endDate: String, description: String?) async {
        do {
            let req = CreateHolidayRequest(startDate: startDate, endDate: endDate, description: description)
            let holiday = try await service.createHoliday(req)
            userHolidays.append(holiday)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func updateHoliday(id: String, startDate: String, endDate: String, description: String?) async {
        do {
            let req = CreateHolidayRequest(startDate: startDate, endDate: endDate, description: description)
            let updated = try await service.updateHoliday(id: id, req)
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
            try await service.deleteHoliday(id: id)
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
            let period = try await service.createSchedulePeriod(req)
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
            let updated = try await service.updateSchedulePeriod(id: id, req)
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
            try await service.deleteSchedulePeriod(id: id)
            schedulePeriods.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
