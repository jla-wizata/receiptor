import Foundation

struct ReceiptsService {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func upload(imageData: Data) async throws -> Receipt {
        let data = try await client.upload(path: "/receipts/upload", imageData: imageData)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Receipt.self, from: data)
    }

    func list(startDate: String? = nil, endDate: String? = nil) async throws -> ReceiptList {
        var queryItems: [URLQueryItem] = []
        if let s = startDate { queryItems.append(URLQueryItem(name: "start_date", value: s)) }
        if let e = endDate { queryItems.append(URLQueryItem(name: "end_date", value: e)) }
        return try await client.request(
            Endpoint(path: "/receipts", queryItems: queryItems.isEmpty ? nil : queryItems)
        )
    }

    func get(id: String) async throws -> Receipt {
        return try await client.request(Endpoint(path: "/receipts/\(id)"))
    }

    func updateDate(id: String, date: String) async throws -> Receipt {
        let body = try JSONEncoder().encode(UpdateDateRequest(receiptDate: date))
        return try await client.request(Endpoint(path: "/receipts/\(id)/date", method: .PUT, body: body))
    }

    func delete(id: String) async throws {
        try await client.requestNoContent(Endpoint(path: "/receipts/\(id)", method: .DELETE))
    }
}
