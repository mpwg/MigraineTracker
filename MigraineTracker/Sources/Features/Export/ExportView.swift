import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncCoordinator.self) private var syncCoordinator
    @Environment(AppLogViewModel.self) private var appLogViewModel
    @Query(sort: [SortDescriptor(\Episode.startedAt, order: .reverse)]) private var storedEpisodes: [Episode]
    @Query(sort: [SortDescriptor(\MedicationDefinition.name)]) private var storedDefinitions: [MedicationDefinition]

    var body: some View {
        List {
            Section {
                NavigationLink {
                    SyncStatusView()
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Status")
                            Spacer()
                            statusBadge
                        }

                        Text(statusSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 16) {
                            statValue(title: "Ausstehend", value: "\(syncCoordinator.status.queuedUpdates)")
                            statValue(title: "Ungesynct", value: "\(syncCoordinator.status.unsyncedRecords)")
                            statValue(title: "Konflikte", value: "\(syncCoordinator.conflicts.count)")
                        }
                    }
                    .padding(.vertical, 6)
            }

                Toggle("Sync aktivieren", isOn: Binding(
                    get: { syncCoordinator.isEnabled },
                    set: { syncCoordinator.setSyncEnabled($0) }
                ))
                .tint(.green)

                NavigationLink {
                    ManageCloudDataView()
                } label: {
                    Label("Cloud-Daten verwalten", systemImage: "icloud")
                }

                NavigationLink {
                    SyncLogView()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Sync-Protokoll", systemImage: "text.document")
                        Text(logSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Synchronisation")
            }
            footer: {
                Text("Die App bleibt lokal vollständig nutzbar. iCloud-Sync ist optional, arbeitet getrennt von SwiftData und kann jederzeit wieder deaktiviert werden.")
            }

            Section("Allgemein") {
                NavigationLink {
                    DataExportView()
                } label: {
                    Label("Datenexport", systemImage: "square.and.arrow.up")
                }

                NavigationLink {
                    ProductInformationView(mode: .standard)
                } label: {
                    Label("Datenschutz und Hinweise", systemImage: "hand.raised")
                }
            }

            Section("Übersicht") {
                LabeledContent("Aktive Episoden", value: "\(storedEpisodes.filter { !$0.isDeleted }.count)")
                LabeledContent("Papierkorb", value: "\(storedEpisodes.filter(\.isDeleted).count + storedDefinitions.filter(\.isDeleted).count)")
                LabeledContent("Konflikte", value: "\(syncCoordinator.conflicts.count)")
            }
        }
        .navigationTitle("Einstellungen")
        .toolbar {
            ToolbarItem(placement: closeButtonPlacement) {
                Button("Schließen") {
                    dismiss()
                }
            }
        }
        .task {
            syncCoordinator.refreshStatus()
            appLogViewModel.refresh(limit: 1)
        }
        .refreshable {
            syncCoordinator.refreshStatus()
            appLogViewModel.refresh(limit: 1)
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

    private var statusSubtitle: String {
        if let lastError = syncCoordinator.status.lastError, !lastError.isEmpty {
            return lastError
        }

        if let lastUploadedAt = syncCoordinator.status.lastUploadedAt {
            return "Letzter Upload: \(formatted(lastUploadedAt))"
        }

        if let lastDownloadedAt = syncCoordinator.status.lastDownloadedAt {
            return "Letzter Download: \(formatted(lastDownloadedAt))"
        }

        return syncCoordinator.isEnabled
            ? "Synchronisation ist bereit. Lokale Änderungen bleiben bis zum nächsten Lauf sicher auf dem Gerät."
            : "Synchronisation ist deaktiviert. Alle Daten bleiben lokal auf diesem Gerät erhalten."
    }

    private var statusBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            Text(syncCoordinator.status.state.displayTitle)
                .foregroundStyle(.secondary)
        }
    }

    private func statValue(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private var logSubtitle: String {
        if let latest = appLogViewModel.entries.first {
            return "Letzter Eintrag: \(formatted(latest.timestamp))"
        }

        return "Ansehen, teilen und bei Bedarf löschen."
    }

    private var closeButtonPlacement: ToolbarItemPlacement {
        #if targetEnvironment(macCatalyst)
        .topBarTrailing
        #else
        .topBarLeading
        #endif
    }
}

private struct SyncStatusView: View {
    @Environment(SyncCoordinator.self) private var syncCoordinator

    var body: some View {
        List {
            Section {
                statusRow("Status", syncCoordinator.status.state.displayTitle)
                statusRow("Dienst", syncCoordinator.status.service)
                statusRow("Ausstehende Uploads", "\(syncCoordinator.status.queuedUpdates)")
                statusRow("Ungesyncte Einträge", "\(syncCoordinator.status.unsyncedRecords)")
                statusRow("Letzter Download", formatted(syncCoordinator.status.lastDownloadedAt))
                statusRow("Letzter Upload", formatted(syncCoordinator.status.lastUploadedAt))

                if let lastError = syncCoordinator.status.lastError {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Letzter Fehler")
                        Text(lastError)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Status")
            }
            footer: {
                Text(statusFooter)
            }
        }
        .navigationTitle("Status")
        .refreshable {
            syncCoordinator.refreshStatus()
        }
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

    private var statusFooter: String {
        switch syncCoordinator.status.state {
        case .disabled:
            "Der Cloud-Sync ist ausgeschaltet. Lokale Daten bleiben unverändert verfügbar."
        case .ready:
            "Der Sync-Dienst ist bereit. Änderungen werden beim nächsten Lauf in die private iCloud-Datenbank übertragen."
        case .syncing:
            "Es läuft gerade ein Abgleich zwischen lokalem Speicher und iCloud."
        case .needsAttention:
            "Der Sync braucht Aufmerksamkeit. Prüfe die Fehlermeldung und versuche den Abgleich erneut."
        case .conflict:
            "Mindestens ein Eintrag wurde auf mehreren Geräten unterschiedlich verändert. Erst nach einer Entscheidung gilt der Datensatz wieder als sauber synchronisiert."
        case .noICloudAccount:
            "Für iCloud-Sync muss auf dem Gerät ein iCloud-Account angemeldet sein."
        case .offline:
            "Ohne Netzwerk bleiben alle Daten lokal erhalten und werden später erneut versucht."
        }
    }
}

private struct ManageCloudDataView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncCoordinator.self) private var syncCoordinator
    @Query(sort: [SortDescriptor(\Episode.startedAt, order: .reverse)]) private var storedEpisodes: [Episode]
    @Query(sort: [SortDescriptor(\MedicationDefinition.updatedAt, order: .reverse)]) private var storedDefinitions: [MedicationDefinition]

    var body: some View {
        List {
            Section {
                statusRow("Sync", syncCoordinator.isEnabled ? "Aktiviert" : "Deaktiviert")
                statusRow("Offene Konflikte", "\(syncCoordinator.conflicts.count)")
                statusRow("Papierkorb", "\(deletedEpisodes.count + deletedDefinitions.count)")
            } header: {
                Text("Übersicht")
            }
            footer: {
                Text("Papierkorb-Einträge bleiben lokal und in der Cloud erhalten, bis du sie bewusst wiederherstellst oder später einmal endgültig entfernst.")
            }

            Section {
                Button("Jetzt synchronisieren") {
                    Task {
                        await syncCoordinator.syncNow()
                    }
                }
                .disabled(!syncCoordinator.isEnabled)

                Button("Fehler erneut versuchen") {
                    Task {
                        await syncCoordinator.retryLastError()
                    }
                }
                .disabled(!syncCoordinator.isEnabled || syncCoordinator.status.lastError == nil)

                NavigationLink {
                    DataExportView()
                } label: {
                    Text("Lokales JSON5-Backup erstellen")
                }
            } header: {
                Text("Aktionen")
            }
            footer: {
                if !syncCoordinator.isEnabled {
                    Text("Aktiviere den Sync, um iCloud-Synchronisation und Konfliktbehandlung zu verwenden.")
                } else {
                    Text("Der Abgleich arbeitet defensiv: Konflikte werden nicht still überschrieben, sondern hier sichtbar gemacht.")
                }
            }

            Section("Konflikte") {
                if syncCoordinator.conflicts.isEmpty {
                    Text("Keine offenen Konflikte.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(syncCoordinator.conflicts) { conflict in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(conflictTitle(for: conflict))
                                .font(.headline)
                            Text("Abweichende Felder: \(conflict.conflictingFields.joined(separator: ", "))")
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
        .refreshable {
            syncCoordinator.refreshStatus()
        }
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

    private func conflictTitle(for conflict: SyncConflict) -> String {
        switch conflict.entityType {
        case .episode:
            "Episode"
        case .medicationDefinition:
            "Medikamentenvorlage"
        }
    }

    private func statusRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
