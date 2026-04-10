import SwiftData
import SwiftUI

struct ExportView: View {
    @EnvironmentObject private var syncCoordinator: SyncCoordinator
    @Query(sort: [SortDescriptor(\Episode.startedAt, order: .reverse)]) private var storedEpisodes: [Episode]
    @Query(sort: [SortDescriptor(\MedicationDefinition.name)]) private var storedDefinitions: [MedicationDefinition]

    var body: some View {
        List {
            Section("Synchronisation") {
                NavigationLink {
                    SyncStatusView()
                } label: {
                    HStack {
                        Text("Status")
                        Spacer()
                        Circle()
                            .fill(statusColor)
                            .frame(width: 10, height: 10)
                        Text(syncCoordinator.status.state.displayTitle)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle("Sync aktivieren", isOn: Binding(
                    get: { syncCoordinator.isEnabled },
                    set: { syncCoordinator.setSyncEnabled($0) }
                ))

                NavigationLink {
                    ManageCloudDataView()
                } label: {
                    Label("Cloud-Daten verwalten", systemImage: "icloud")
                }
            }

            Section("Export") {
                NavigationLink {
                    DataExportView()
                } label: {
                    Label("Datenexport", systemImage: "square.and.arrow.up")
                }
            }

            Section("Übersicht") {
                LabeledContent("Aktive Episoden", value: "\(storedEpisodes.filter { !$0.isDeleted }.count)")
                LabeledContent("Papierkorb", value: "\(storedEpisodes.filter(\.isDeleted).count + storedDefinitions.filter(\.isDeleted).count)")
                LabeledContent("Konflikte", value: "\(syncCoordinator.conflicts.count)")
            }
        }
        .navigationTitle("Sync & Datenexport")
        .task {
            syncCoordinator.refreshStatus()
        }
    }

    private var statusColor: Color {
        switch syncCoordinator.status.state {
        case .ready:
            .green
        case .syncing:
            .blue
        case .conflict, .needsAttention:
            .orange
        case .noICloudAccount, .offline:
            .red
        case .disabled:
            .gray
        }
    }
}

private struct SyncStatusView: View {
    @EnvironmentObject private var syncCoordinator: SyncCoordinator

    var body: some View {
        List {
            Section("Status") {
                statusRow("Status", syncCoordinator.status.state.displayTitle)
                statusRow("Service", syncCoordinator.status.service)
                statusRow("Queued Updates", "\(syncCoordinator.status.queuedUpdates)")
                statusRow("Unsynced Records", "\(syncCoordinator.status.unsyncedRecords)")
                statusRow("Last Downloaded", formatted(syncCoordinator.status.lastDownloadedAt))
                statusRow("Last Uploaded", formatted(syncCoordinator.status.lastUploadedAt))

                if let lastError = syncCoordinator.status.lastError {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Letzter Fehler")
                        Text(lastError)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Status")
    }

    private func statusRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func formatted(_ date: Date?) -> String {
        guard let date else {
            return "Noch nie"
        }

        return date.formatted(date: .numeric, time: .shortened)
    }
}

private struct ManageCloudDataView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var syncCoordinator: SyncCoordinator
    @Query(sort: [SortDescriptor(\Episode.startedAt, order: .reverse)]) private var storedEpisodes: [Episode]
    @Query(sort: [SortDescriptor(\MedicationDefinition.updatedAt, order: .reverse)]) private var storedDefinitions: [MedicationDefinition]

    var body: some View {
        List {
            Section("Aktionen") {
                Button("Jetzt synchronisieren") {
                    Task {
                        await syncCoordinator.syncNow()
                    }
                }

                Button("Fehler erneut versuchen") {
                    Task {
                        await syncCoordinator.retryLastError()
                    }
                }
                .disabled(syncCoordinator.status.lastError == nil)

                NavigationLink {
                    DataExportView()
                } label: {
                    Text("Lokales JSON5-Backup erstellen")
                }
            }

            Section("Konflikte") {
                if syncCoordinator.conflicts.isEmpty {
                    Text("Keine offenen Konflikte.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(syncCoordinator.conflicts) { conflict in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(conflict.documentID)
                                .font(.headline)
                            Text(conflict.conflictingFields.joined(separator: ", "))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Button("Lokale Version behalten") {
                                syncCoordinator.resolveConflictKeepingLocal(conflict)
                            }

                            Button("Cloud-Version übernehmen") {
                                syncCoordinator.resolveConflictUsingRemote(conflict)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Papierkorb") {
                if deletedEpisodes.isEmpty && deletedDefinitions.isEmpty {
                    Text("Keine gelöschten Einträge.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(deletedEpisodes, id: \.id) { episode in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(episode.startedAt.formatted(date: .abbreviated, time: .shortened))
                                Text(episode.type.rawValue)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Wiederherstellen") {
                                restore(episode)
                            }
                        }
                    }

                    ForEach(deletedDefinitions, id: \.catalogKey) { definition in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(definition.name)
                                Text(definition.category.rawValue)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Wiederherstellen") {
                                restore(definition)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Cloud-Daten")
    }

    private var deletedEpisodes: [Episode] {
        storedEpisodes.filter(\.isDeleted)
    }

    private var deletedDefinitions: [MedicationDefinition] {
        storedDefinitions.filter(\.isDeleted)
    }

    private func restore(_ episode: Episode) {
        episode.restore()
        try? modelContext.save()
        syncCoordinator.refreshStatus()
    }

    private func restore(_ definition: MedicationDefinition) {
        definition.restore()
        try? modelContext.save()
        syncCoordinator.refreshStatus()
    }
}

#Preview {
    NavigationStack {
        ExportView()
    }
}
