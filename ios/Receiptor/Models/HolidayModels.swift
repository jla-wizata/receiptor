import Foundation

struct UserHoliday: Codable, Identifiable {
    let id: String
    let startDate: String
    let endDate: String
    let description: String?
}

struct CreateHolidayRequest: Encodable {
    let startDate: String
    let endDate: String
    let description: String?

    enum CodingKeys: String, CodingKey {
        case startDate = "start_date"
        case endDate = "end_date"
        case description
    }
}

struct WorkSchedulePeriod: Codable, Identifiable {
    let id: String
    let startDate: String
    let endDate: String?
    let workingDays: [Int]
    let description: String?
}

struct CreateSchedulePeriodRequest: Encodable {
    let startDate: String
    let endDate: String?
    let workingDays: [Int]
    let description: String?

    enum CodingKeys: String, CodingKey {
        case startDate = "start_date"
        case endDate = "end_date"
        case workingDays = "working_days"
        case description
    }
}

struct PublicHoliday: Codable, Identifiable {
    let id: String
    let date: String
    let localName: String
    let name: String
}

struct Country: Codable, Identifiable {
    var id: String { countryCode }
    let countryCode: String
    let name: String
}

struct CountriesResponse: Codable {
    let countries: [Country]
}
