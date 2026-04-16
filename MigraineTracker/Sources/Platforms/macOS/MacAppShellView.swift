import SwiftUI

struct MacAppShellView: View {
    let appContainer: AppContainer

    @State private var selectedSection: AppSection? = AppSection.macOSDefaultSection

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationTitle("Migraine Tracker")
        } detail: {
            NavigationStack {
                detailView(for: selectedSection ?? .history)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appPrimaryBackground)
        }
        .navigationSplitViewStyle(.balanced)
        .task {
            await appContainer.weatherBackfillService.runIfNeeded()
        }
    }

    @ViewBuilder
    private func detailView(for section: AppSection) -> some View {
        switch section {
        case .home:
            HomeView(appContainer: appContainer) { destination in
                selectedSection = destination
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
