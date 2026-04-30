import SwiftUI

enum Tab: String, CaseIterable, Identifiable {
    case journal
    case insights
    case report
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .journal: "Tagebuch"
        case .insights: "Insights"
        case .report: "Bericht"
        case .settings: "Einstellungen"
        }
    }

    var systemImage: String {
        switch self {
        case .journal: "book.pages"
        case .insights: "sparkle.magnifyingglass"
        case .report: "doc.text"
        case .settings: "gearshape"
        }
    }
}

struct AppShellView: View {
    let appContainer: AppContainer
    private var features: AppFeatureDependencies { appContainer.featureDependencies }
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: Tab = .journal
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactRoot
            } else {
                regularRoot
            }
        }
        .tint(AppTheme.petrol(for: colorScheme))
        .toolbarBackground(AppTheme.petrol(for: colorScheme).opacity(SymiOpacity.strongSurface), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            appContainer.startDeferredMaintenanceIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            appContainer.appDidBecomeActive()
        }
    }

    private var compactRoot: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                content(for: .journal)
            }
            .tabItem {
                Label(Tab.journal.title, systemImage: Tab.journal.systemImage)
            }
            .accessibilityLabel("\(Tab.journal.title) Tab")
            .accessibilityIdentifier("tab-\(Tab.journal.rawValue)")
            .tag(Tab.journal)

            NavigationStack {
                content(for: .insights)
            }
            .tabItem {
                Label(Tab.insights.title, systemImage: Tab.insights.systemImage)
            }
            .accessibilityLabel("\(Tab.insights.title) Tab")
            .accessibilityIdentifier("tab-\(Tab.insights.rawValue)")
            .tag(Tab.insights)

            NavigationStack {
                content(for: .report)
            }
            .tabItem {
                Label(Tab.report.title, systemImage: Tab.report.systemImage)
            }
            .accessibilityLabel("\(Tab.report.title) Tab")
            .accessibilityIdentifier("tab-\(Tab.report.rawValue)")
            .tag(Tab.report)

            NavigationStack {
                content(for: .settings)
            }
            .tabItem {
                Label(Tab.settings.title, systemImage: Tab.settings.systemImage)
            }
            .accessibilityLabel("\(Tab.settings.title) Tab")
            .accessibilityIdentifier("tab-\(Tab.settings.rawValue)")
            .tag(Tab.settings)
        }
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }

    private var regularRoot: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List {
                ForEach(Tab.allCases) { tab in
                    Button {
                        selectedTab = tab
                        columnVisibility = .all
                    } label: {
                        Label(tab.title, systemImage: tab.systemImage)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(selectedTab == tab ? AppTheme.selectedFill(for: colorScheme) : Color.clear)
                    .accessibilityLabel("\(tab.title) Bereich")
                    .accessibilityValue(selectedTab == tab ? "Ausgewählt" : "")
                    .accessibilityIdentifier("sidebar-\(tab.rawValue)")
                }
            }
            .navigationTitle(ProductBranding.displayName)
            .navigationSplitViewColumnWidth(min: 220, ideal: 250)
        } detail: {
            NavigationStack {
                regularContent(for: selectedTab)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func content(for tab: Tab) -> some View {
        switch tab {
        case .journal:
            HomeView(dependencies: features.home)
        case .insights:
            InsightsView(dependencies: features.insights)
        case .report:
            ReportView(dependencies: features.dataExport)
        case .settings:
            SettingsView(dependencies: features.settings, showsCloseButton: false)
        }
    }

    @ViewBuilder
    private func regularContent(for tab: Tab) -> some View {
        switch tab {
        case .journal, .insights:
            content(for: tab)
        case .report, .settings:
            RegularDetailSurface {
                content(for: tab)
            }
        }
    }
}

#Preview {
    Text("Preview nicht verfügbar")
}

private struct RegularDetailSurface<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(spacing: SymiSpacing.zero) {
            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .brandScreen()
    }
}
