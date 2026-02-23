import Foundation

struct ReportService {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func downloadReport(year: Int) async throws -> Data {
        return try await client.requestData(
            Endpoint(path: "/report", queryItems: [URLQueryItem(name: "year", value: "\(year)")])
        )
    }
}
