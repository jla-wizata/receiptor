import Foundation

struct DashboardService {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func getSummary(year: Int) async throws -> DashboardSummary {
        return try await client.request(
            Endpoint(path: "/dashboard", queryItems: [URLQueryItem(name: "year", value: "\(year)")])
        )
    }

    func getSettings() async throws -> UserSettings {
        return try await client.request(Endpoint(path: "/dashboard/settings"))
    }

    func updateSettings(_ settings: UpdateSettingsRequest) async throws -> UserSettings {
        let body = try JSONEncoder().encode(settings)
        return try await client.request(Endpoint(path: "/dashboard/settings", method: .PUT, body: body))
    }

    func listHolidays(year: Int? = nil) async throws -> [UserHoliday] {
        var queryItems: [URLQueryItem]? = nil
        if let y = year { queryItems = [URLQueryItem(name: "year", value: "\(y)")] }
        return try await client.request(Endpoint(path: "/dashboard/holidays", queryItems: queryItems))
    }

    func createHoliday(_ holiday: CreateHolidayRequest) async throws -> UserHoliday {
        let body = try JSONEncoder().encode(holiday)
        return try await client.request(Endpoint(path: "/dashboard/holidays", method: .POST, body: body))
    }

    func updateHoliday(id: String, _ holiday: CreateHolidayRequest) async throws -> UserHoliday {
        let body = try JSONEncoder().encode(holiday)
        return try await client.request(Endpoint(path: "/dashboard/holidays/\(id)", method: .PUT, body: body))
    }

    func deleteHoliday(id: String) async throws {
        try await client.requestNoContent(Endpoint(path: "/dashboard/holidays/\(id)", method: .DELETE))
    }

    func listSchedulePeriods() async throws -> [WorkSchedulePeriod] {
        return try await client.request(Endpoint(path: "/dashboard/schedule"))
    }

    func createSchedulePeriod(_ period: CreateSchedulePeriodRequest) async throws -> WorkSchedulePeriod {
        let body = try JSONEncoder().encode(period)
        return try await client.request(Endpoint(path: "/dashboard/schedule", method: .POST, body: body))
    }

    func updateSchedulePeriod(id: String, _ period: CreateSchedulePeriodRequest) async throws -> WorkSchedulePeriod {
        let body = try JSONEncoder().encode(period)
        return try await client.request(Endpoint(path: "/dashboard/schedule/\(id)", method: .PUT, body: body))
    }

    func deleteSchedulePeriod(id: String) async throws {
        try await client.requestNoContent(Endpoint(path: "/dashboard/schedule/\(id)", method: .DELETE))
    }
}
