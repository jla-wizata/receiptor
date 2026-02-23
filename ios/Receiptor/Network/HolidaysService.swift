import Foundation

struct HolidaysService {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func getPublicHolidays(year: Int, country: String) async throws -> [PublicHoliday] {
        let queryItems = [
            URLQueryItem(name: "year", value: "\(year)"),
            URLQueryItem(name: "country_code", value: country)
        ]
        return try await client.request(Endpoint(path: "/holidays/public", queryItems: queryItems))
    }

    func getCountries() async throws -> [Country] {
        return try await client.request(Endpoint(path: "/holidays/countries"))
    }
}
