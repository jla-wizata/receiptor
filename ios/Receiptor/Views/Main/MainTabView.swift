import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 3

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
                .tag(0)

            ReceiptListView()
                .tabItem { Label("Receipts", systemImage: "doc.text.fill") }
                .tag(1)

            HolidaysView()
                .tabItem { Label("Holidays", systemImage: "calendar") }
                .tag(2)

            CaptureTabView()
                .tabItem { Label("Scan", systemImage: "camera.fill") }
                .tag(3)
        }
    }
}
