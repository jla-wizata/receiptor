import Foundation

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
}

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct RegisterRequest: Encodable {
    let email: String
    let password: String
}

struct MessageResponse: Codable {
    let message: String
}
