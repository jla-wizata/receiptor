import Foundation

struct AuthService {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        let body = try JSONEncoder().encode(LoginRequest(email: email, password: password))
        return try await client.request(Endpoint(path: "/auth/login", method: .POST, body: body))
    }

    func register(email: String, password: String) async throws -> AuthResponse {
        let body = try JSONEncoder().encode(RegisterRequest(email: email, password: password))
        return try await client.request(Endpoint(path: "/auth/register", method: .POST, body: body))
    }

    func logout() async throws {
        try await client.requestNoContent(Endpoint(path: "/auth/logout", method: .POST))
    }
}
