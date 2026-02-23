import SwiftUI

struct AuthContainerView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                Text("Receiptor")
                    .font(.largeTitle)
                    .bold()
                Text("Prove your presence")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 60)
            .padding(.bottom, 32)

            Picker("", selection: $selectedTab) {
                Text("Sign In").tag(0)
                Text("Register").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)

            if selectedTab == 0 {
                LoginView()
                    .transition(.opacity)
            } else {
                RegisterView()
                    .transition(.opacity)
            }

            Spacer()
        }
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
    }
}
