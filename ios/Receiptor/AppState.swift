import Foundation
import Observation

@Observable
final class AppState {
    var isAuthenticated: Bool = false
    var accessToken: String? = nil
    var refreshToken: String? = nil
    var userEmail: String? = nil

    init() {
        if let token = KeychainManager.shared.load(key: "access_token") {
            accessToken = token
            isAuthenticated = true
        }
        refreshToken = KeychainManager.shared.load(key: "refresh_token")
        userEmail = KeychainManager.shared.load(key: "user_email")
    }

    func login(token: String, refresh: String, email: String) {
        accessToken = token
        refreshToken = refresh
        userEmail = email
        isAuthenticated = true
        KeychainManager.shared.save(key: "access_token", value: token)
        KeychainManager.shared.save(key: "refresh_token", value: refresh)
        KeychainManager.shared.save(key: "user_email", value: email)
    }

    func logout() {
        accessToken = nil
        refreshToken = nil
        userEmail = nil
        isAuthenticated = false
        KeychainManager.shared.delete(key: "access_token")
        KeychainManager.shared.delete(key: "refresh_token")
        KeychainManager.shared.delete(key: "user_email")
    }
}
