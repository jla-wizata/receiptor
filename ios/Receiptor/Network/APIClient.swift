import Foundation

enum HTTPMethod: String {
    case GET, POST, PUT, DELETE, PATCH
}

struct Endpoint {
    let path: String
    let method: HTTPMethod
    let body: Data?
    let queryItems: [URLQueryItem]?
    let contentType: String

    init(
        path: String,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        queryItems: [URLQueryItem]? = nil,
        contentType: String = "application/json"
    ) {
        self.path = path
        self.method = method
        self.body = body
        self.queryItems = queryItems
        self.contentType = contentType
    }
}

extension Notification.Name {
    static let apiUnauthorized = Notification.Name("APIClientUnauthorized")
}

enum APIError: LocalizedError {
    case invalidURL
    case httpError(statusCode: Int, message: String)
    case decodingError(Error)
    case networkError(Error)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .httpError(let code, let msg): return "HTTP \(code): \(msg)"
        case .decodingError(let e): return "Decode error: \(e.localizedDescription)"
        case .networkError(let e): return e.localizedDescription
        case .unauthorized: return "Session expired. Please log in again."
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    private let baseURL: String
    private let session: URLSession
    var tokenProvider: (() -> String?)?

    private init() {
        baseURL = Bundle.main.infoDictionary?["API_BASE_URL"] as? String ?? "http://127.0.0.1:8000"
        session = URLSession.shared
        tokenProvider = { KeychainManager.shared.load(key: "access_token") }
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func applyCommonHeaders(to request: inout URLRequest, endpoint: Endpoint) {
        if endpoint.body != nil {
            request.setValue(endpoint.contentType, forHTTPHeaderField: "Content-Type")
        }
        if let token = tokenProvider?() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func buildURL(for endpoint: Endpoint) throws -> URL {
        guard var components = URLComponents(string: baseURL + endpoint.path) else {
            throw APIError.invalidURL
        }
        components.queryItems = endpoint.queryItems
        guard let url = components.url else { throw APIError.invalidURL }
        return url
    }

    private func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }
        if http.statusCode == 401 {
            NotificationCenter.default.post(name: .apiUnauthorized, object: nil)
            throw APIError.unauthorized
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.httpError(statusCode: http.statusCode, message: message)
        }
    }

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let url = try buildURL(for: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        applyCommonHeaders(to: &request, endpoint: endpoint)

        let (data, response) = try await session.data(for: request)
        try validate(response, data: data)

        do {
            return try makeDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    func requestData(_ endpoint: Endpoint) async throws -> Data {
        let url = try buildURL(for: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        applyCommonHeaders(to: &request, endpoint: endpoint)

        let (data, response) = try await session.data(for: request)
        try validate(response, data: data)
        return data
    }

    func requestNoContent(_ endpoint: Endpoint) async throws {
        let url = try buildURL(for: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        applyCommonHeaders(to: &request, endpoint: endpoint)
        let (data, response) = try await session.data(for: request)
        try validate(response, data: data)
    }

    func upload(path: String, imageData: Data) async throws -> Data {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = tokenProvider?() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"receipt.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        try validate(response, data: data)
        return data
    }
}
