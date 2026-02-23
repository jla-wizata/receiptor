import SwiftUI

struct RegisterView: View {
    @Environment(AppState.self) private var appState
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    private let authService = AuthService()

    private var passwordMismatch: Bool {
        !confirmPassword.isEmpty && password != confirmPassword
    }

    var body: some View {
        VStack(spacing: 16) {
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 24)

            SecureField("Password", text: $password)
                .textContentType(.newPassword)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 24)

            SecureField("Confirm Password", text: $confirmPassword)
                .textContentType(.newPassword)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 24)

            if passwordMismatch {
                Text("Passwords do not match")
                    .foregroundColor(.red)
                    .font(.caption)
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Button(action: register) {
                Group {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Create Account")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || email.isEmpty || password.isEmpty || passwordMismatch)
            .padding(.horizontal, 24)
        }
        .padding(.top, 16)
    }

    private func register() {
        guard password == confirmPassword else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let response = try await authService.register(email: email, password: password)
                await MainActor.run {
                    appState.login(token: response.accessToken, refresh: response.refreshToken, email: email)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}
