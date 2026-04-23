import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case overview
    case history
    case doctors
    case export
    case settings
    case information

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Übersicht"
        case .history: "Tagebuch"
        case .doctors: "Ärzte"
        case .export: "Export"
        case .settings: "Einstellungen"
        case .information: "Hinweise"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "house"
        case .history: "book.closed"
        case .doctors: "cross.case"
        case .export: "square.and.arrow.up"
        case .settings: "gearshape"
        case .information: "hand.raised"
        }
    }
}

struct AppShellView: View {
    let appContainer: AppContainer
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedSection: AppSection = .overview
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactRoot
            } else {
                regularRoot
            }
        }
        .tint(AppTheme.ocean)
        .toolbarBackground(AppTheme.ink.opacity(0.96), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else {
                return
            }
            await appContainer.weatherBackfillService.runIfNeeded()
        }
    }

    private var compactRoot: some View {
        TabView(selection: $selectedSection) {
            ForEach([AppSection.overview, .history, .doctors, .export, .settings]) { section in
                NavigationStack {
                    content(for: section)
                }
                .tabItem {
                    Label(section.title, systemImage: section.systemImage)
                }
                .tag(section)
            }
        }
    }

    private var regularRoot: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List {
                ForEach(AppSection.allCases) { section in
                    Button {
                        selectedSection = section
                        columnVisibility = .all
                    } label: {
                        Label(section.title, systemImage: section.systemImage)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(selectedSection == section ? AppTheme.selectedFill : Color.clear)
                }
            }
            .navigationTitle(ProductBranding.displayName)
            .navigationSplitViewColumnWidth(min: 220, ideal: 250)
        } detail: {
            NavigationStack {
                regularContent(for: selectedSection)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func content(for section: AppSection) -> some View {
        switch section {
        case .overview:
            HomeView(appContainer: appContainer)
        case .history:
            HistoryView(appContainer: appContainer)
        case .doctors:
            DoctorsHubView(appContainer: appContainer)
        case .export:
            DataExportView(appContainer: appContainer)
        case .settings:
            SettingsView(appContainer: appContainer, showsCloseButton: false)
        case .information:
            ProductInformationView(mode: .standard)
        }
    }

    @ViewBuilder
    private func regularContent(for section: AppSection) -> some View {
        switch section {
        case .overview, .history, .doctors:
            content(for: section)
        case .export, .settings, .information:
            RegularDetailSurface {
                content(for: section)
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
        HStack(spacing: 0) {
            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .brandScreen()
    }
}
