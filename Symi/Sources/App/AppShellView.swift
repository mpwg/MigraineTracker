import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case overview
    case history
    case export
    case settings
    case information

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Heute"
        case .history: "Tagebuch"
        case .export: "Teilen"
        case .settings: "Einstellungen"
        case .information: "Hinweise"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "sparkles"
        case .history: "book.closed"
        case .export: "square.and.arrow.up"
        case .settings: "gearshape"
        case .information: "hand.raised"
        }
    }
}

struct AppShellView: View {
    let appContainer: AppContainer
    @Environment(\.colorScheme) private var colorScheme
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
        .tint(AppTheme.petrol(for: colorScheme))
        .toolbarBackground(AppTheme.petrol(for: colorScheme).opacity(SymiOpacity.strongSurface), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            appContainer.startDeferredMaintenanceIfNeeded()
        }
    }

    private var compactRoot: some View {
        TabView(selection: $selectedSection) {
            ForEach([AppSection.overview, .history, .export, .settings]) { section in
                NavigationStack {
                    content(for: section)
                }
                .tabItem {
                    Label(section.title, systemImage: section.systemImage)
                }
                .accessibilityLabel("\(section.title) Tab")
                .accessibilityIdentifier("tab-\(section.rawValue)")
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
                    .listRowBackground(selectedSection == section ? AppTheme.selectedFill(for: colorScheme) : Color.clear)
                    .accessibilityLabel("\(section.title) Bereich")
                    .accessibilityValue(selectedSection == section ? "Ausgewählt" : "")
                    .accessibilityIdentifier("sidebar-\(section.rawValue)")
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
        case .overview, .history:
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
        HStack(spacing: SymiSpacing.zero) {
            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .brandScreen()
    }
}
