import SwiftUI

struct IOSAppShellView: View {
    let appContainer: AppContainer

    @State private var selectedTab: AppTab = AppSection.iOSDefaultTab

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack {
                    rootView(for: tab)
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.systemImage)
                }
                .tag(tab)
            }
        }
        .task {
            await appContainer.weatherBackfillService.runIfNeeded()
        }
    }

    @ViewBuilder
    private func rootView(for tab: AppTab) -> some View {
        switch tab {
        case .home:
            HomeView(appContainer: appContainer) { section in
                selectedTab = section.tab
            }
        case .capture:
            CaptureView(appContainer: appContainer)
        case .history:
            HistoryView(appContainer: appContainer, showsSettingsShortcut: false)
        case .syncAndExport:
            SyncAndExportView(appContainer: appContainer)
        case .settings:
            SettingsView(appContainer: appContainer, showsCloseButton: false)
        }
    }
}
