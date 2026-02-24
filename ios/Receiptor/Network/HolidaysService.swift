import Foundation

struct HolidaysService {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func getPublicHolidays(year: Int) async throws -> [PublicHoliday] {
        let queryItems = [URLQueryItem(name: "year", value: "\(year)")]
        return try await client.request(Endpoint(path: "/holidays", queryItems: queryItems))
    }

    func getCountries() async throws -> [Country] {
        return try await client.request(Endpoint(path: "/holidays/countries"))
    }
}
