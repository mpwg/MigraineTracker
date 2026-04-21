import SwiftUI

struct SyncLogView: View {
    @Bindable var controller: SettingsController

    var body: some View {
        List {
            Section {
                Text("Das Protokoll bleibt lokal auf diesem Gerät. Es enthält technische Metadaten zu Synchronisation, Konflikten und Fehlern, aber keine sensiblen Freitextinhalte im Klartext.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .brandGroupedRow()
            }

            Section("Filter") {
                Picker("Ansicht", selection: $controller.logFilter) {
                    Text("Alle").tag(AppLogFilter.all)
                    Text("Nur Fehler").tag(AppLogFilter.errors)
                    Text("Nur Sync").tag(AppLogFilter.sync)
                }
                .pickerStyle(.segmented)
                .onChange(of: controller.logFilter) { _, _ in
                    controller.refreshLog()
                }
            }

            Section("Aktionen") {
                Button("Aktualisieren") {
                    controller.refreshLog()
                }

                if let shareURL = controller.logShareURL {
                    ShareLink(item: shareURL) {
                        Label("Protokoll teilen", systemImage: "square.and.arrow.up")
                    }
                }

                Button("Protokoll löschen", role: .destructive) {
                    controller.clearLog()
                }
                .disabled(controller.logEntries.isEmpty)
            }

            Section("Einträge") {
                if controller.logEntries.isEmpty {
                    ContentUnavailableView(
                        "Kein Protokoll vorhanden",
                        systemImage: "text.page.slash",
                        description: Text("Sobald Sync-Vorgänge oder Fehler auftreten, erscheinen sie hier.")
                    )
                } else {
                    ForEach(controller.logEntries) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: iconName(for: entry.level))
                                    .foregroundStyle(color(for: entry.level))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.operation)
                                        .font(.headline)
                                    Text(entry.message)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(entry.timestamp.formatted(date: .abbreviated, time: .standard))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if !entry.metadata.isEmpty {
                                Text(entry.metadata.map { "\($0.key): \($0.value)" }.sorted().joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        .brandGroupedRow()
                    }
                }
            }
        }
        .navigationTitle("Sync-Protokoll")
        .brandGroupedScreen()
        .task {
            controller.refreshLog()
        }
        .refreshable {
            controller.refreshLog()
        }
    }

    private func iconName(for level: AppLogLevel) -> String {
        switch level {
        case .debug:
            "ladybug"
        case .info:
            "info.circle"
        case .warning:
            "exclamationmark.triangle"
        case .error:
            "xmark.octagon"
        }
    }

    private func color(for level: AppLogLevel) -> Color {
        switch level {
        case .debug:
            .blue
        case .info:
            .green
        case .warning:
            .orange
        case .error:
            .red
        }
    }
}
