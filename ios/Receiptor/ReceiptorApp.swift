import SwiftUI

@main
struct ReceiptorApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentRootView()
                .environment(appState)
                .onReceive(NotificationCenter.default.publisher(for: .apiUnauthorized)) { _ in
                    if appState.isAuthenticated {
                        appState.logout()
                    }
                }
        }
    }
}

struct ContentRootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.isAuthenticated {
            MainTabView()
        } else {
            AuthContainerView()
        }
    }
}
