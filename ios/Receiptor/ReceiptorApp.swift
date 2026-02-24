import SwiftUI

@main
struct ReceiptorApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentRootView()
                .environment(appState)
                .tint(.appAccent)
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
    @State private var showSplash = true

    var body: some View {
        ZStack {
            MainTabView()
                .fullScreenCover(isPresented: Binding(
                    get: { !appState.isAuthenticated },
                    set: { _ in }
                )) {
                    AuthContainerView()
                }

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeOut(duration: 0.4)) {
                showSplash = false
            }
        }
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 20) {
                AppIcon(size: 90, variant: .color)
                Text("Receiptor")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.appPrimary)
            }
        }
    }
}
