import SwiftUI

struct AppShellView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(selectedTab: $selectedTab)
            }
            .tabItem {
                Label(AppTab.home.title, systemImage: AppTab.home.systemImage)
            }
            .tag(AppTab.home)

            NavigationStack {
                CaptureView()
            }
            .tabItem {
                Label(AppTab.capture.title, systemImage: AppTab.capture.systemImage)
            }
            .tag(AppTab.capture)

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label(AppTab.history.title, systemImage: AppTab.history.systemImage)
            }
            .tag(AppTab.history)

            NavigationStack {
                ExportView()
            }
            .tabItem {
                Label(AppTab.export.title, systemImage: AppTab.export.systemImage)
            }
            .tag(AppTab.export)
        }
    }
}

#Preview {
    AppShellView()
}
