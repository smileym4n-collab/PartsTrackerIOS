import SwiftUI

struct AppShellView: View {
    var body: some View {
        TabView {
            PartsListView()
                .tabItem {
                    Label("Parts", systemImage: "shippingbox")
                }

            ProjectsListView()
                .tabItem {
                    Label("Projects", systemImage: "folder")
                }

            LowStockView()
                .tabItem {
                    Label("Low Stock", systemImage: "exclamationmark.triangle")
                }

            HealthAboutView()
                .tabItem {
                    Label("Server", systemImage: "server.rack")
                }
        }
    }
}

