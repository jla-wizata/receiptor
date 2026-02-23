import Foundation

struct DashboardSummary: Codable {
    let year: Int
    let totalWorkingDays: Int
    let pastWorkingDays: Int
    let daysWithProof: Int
    let daysWithoutProof: Int
    let homeworkingThreshold: Int
    let forecastedDaysWithoutProof: Int
    let remainingAllowedHomeworkingDays: Int
    let complianceStatus: String
}

struct UserSettings: Codable {
    let workingCountryCode: String
    let residenceCountryCode: String
    let homeworkingThreshold: Int
    let workingDays: [Int]
}

struct UpdateSettingsRequest: Encodable {
    let workingCountryCode: String?
    let residenceCountryCode: String?
    let homeworkingThreshold: Int?
    let workingDays: [Int]?

    enum CodingKeys: String, CodingKey {
        case workingCountryCode = "working_country_code"
        case residenceCountryCode = "residence_country_code"
        case homeworkingThreshold = "homeworking_threshold"
        case workingDays = "working_days"
    }
}
