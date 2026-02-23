import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }

            ReceiptListView()
                .tabItem { Label("Receipts", systemImage: "doc.text.fill") }

            HolidaysView()
                .tabItem { Label("Holidays", systemImage: "calendar") }

            ReportView()
                .tabItem { Label("Report", systemImage: "arrow.down.doc.fill") }
        }
    }
}
