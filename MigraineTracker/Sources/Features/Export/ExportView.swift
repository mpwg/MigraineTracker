import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let appContainer: AppContainer
    @State private var controller: SettingsController

    init(appContainer: AppContainer) {
        self.appContainer = appContainer
        _controller = State(initialValue: appContainer.makeSettingsController())
    }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    SyncStatusView(controller: controller)
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
                            statValue(title: "Ausstehend", value: "\(controller.syncStatus.queuedUpdates)")
                            statValue(title: "Ungesynct", value: "\(controller.syncStatus.unsyncedRecords)")
                            statValue(title: "Konflikte", value: "\(controller.conflicts.count)")
                        }
                    }
                    .padding(.vertical, 6)
                    .brandGroupedRow()
                }

                Toggle("Sync aktivieren", isOn: Binding(
                    get: { controller.isSyncEnabled },
                    set: { controller.setSyncEnabled($0) }
                ))
                .tint(AppTheme.ocean)

                NavigationLink {
                    ManageCloudDataView(appContainer: appContainer, controller: controller)
                } label: {
                    Label("Cloud-Daten verwalten", systemImage: "icloud")
                }

                NavigationLink {
                    SyncLogView(controller: controller)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Sync-Protokoll", systemImage: "text.document")
                        Text(logSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .brandGroupedRow()
                }
            } header: {
                Text("Synchronisation")
            } footer: {
                Text("Die App bleibt lokal vollständig nutzbar. iCloud-Sync ist optional, arbeitet getrennt von SwiftData und kann jederzeit wieder deaktiviert werden.")
            }

            Section("Allgemein") {
                NavigationLink {
                    DataExportView(appContainer: appContainer)
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
                LabeledContent("Aktive Episoden", value: "\(controller.summary.activeEpisodeCount)")
                LabeledContent("Papierkorb", value: "\(controller.summary.trashCount)")
                LabeledContent("Konflikte", value: "\(controller.summary.conflictCount)")
            }
        }
        .navigationTitle("Einstellungen")
        .brandGroupedScreen()
        .toolbar {
            ToolbarItem(placement: closeButtonPlacement) {
                Button("Schließen") {
                    dismiss()
                }
            }
        }
        .task {
            controller.load()
            controller.refreshLog(limit: 1)
        }
        .refreshable {
            controller.load()
            controller.refreshLog(limit: 1)
        }
    }

    private var statusColor: Color {
        switch controller.syncStatus.state {
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
        if let lastError = controller.syncStatus.lastError, !lastError.isEmpty {
            return lastError
        }

        if let lastUploadedAt = controller.syncStatus.lastUploadedAt {
            return "Letzter Upload: \(formatted(lastUploadedAt))"
        }

        if let lastDownloadedAt = controller.syncStatus.lastDownloadedAt {
            return "Letzter Download: \(formatted(lastDownloadedAt))"
        }

        return controller.isSyncEnabled
            ? "Synchronisation ist bereit. Lokale Änderungen bleiben bis zum nächsten Lauf sicher auf dem Gerät."
            : "Synchronisation ist deaktiviert. Alle Daten bleiben lokal auf diesem Gerät erhalten."
    }

    private var statusBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            Text(controller.syncStatus.state.displayTitle)
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
        if let latest = controller.logEntries.first {
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
    @Bindable var controller: SettingsController

    var body: some View {
        List {
            Section {
                statusRow("Status", controller.syncStatus.state.displayTitle)
                statusRow("Dienst", controller.syncStatus.service)
                statusRow("Ausstehende Uploads", "\(controller.syncStatus.queuedUpdates)")
                statusRow("Ungesyncte Einträge", "\(controller.syncStatus.unsyncedRecords)")
                statusRow("Letzter Download", formatted(controller.syncStatus.lastDownloadedAt))
                statusRow("Letzter Upload", formatted(controller.syncStatus.lastUploadedAt))

                if let lastError = controller.syncStatus.lastError {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Letzter Fehler")
                        Text(lastError)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .brandGroupedRow()
                }
            } header: {
                Text("Status")
            } footer: {
                Text(statusFooter)
            }
        }
        .navigationTitle("Status")
        .brandGroupedScreen()
        .refreshable {
            controller.load()
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
        switch controller.syncStatus.state {
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
    let appContainer: AppContainer
    @Bindable var controller: SettingsController
    @State private var selectedConflict: SyncConflict?
    @State private var isResolvingConflict = false

    var body: some View {
        List {
            Section {
                statusRow("Sync", controller.isSyncEnabled ? "Aktiviert" : "Deaktiviert")
                statusRow("Offene Konflikte", "\(controller.conflicts.count)")
                statusRow("Papierkorb", "\(controller.summary.trashCount)")
            } header: {
                Text("Übersicht")
            } footer: {
                Text("Papierkorb-Einträge bleiben lokal und in der Cloud erhalten, bis du sie bewusst wiederherstellst oder später einmal endgültig entfernst.")
            }

            Section {
                Button("Jetzt synchronisieren") {
                    Task {
                        await controller.syncNow()
                    }
                }
                .disabled(!controller.isSyncEnabled)

                Button("Fehler erneut versuchen") {
                    Task {
                        await controller.retryLastError()
                    }
                }
                .disabled(!controller.isSyncEnabled || controller.syncStatus.lastError == nil)

                NavigationLink {
                    DataExportView(appContainer: appContainer)
                } label: {
                    Text("Lokales JSON5-Backup erstellen")
                }
            } header: {
                Text("Aktionen")
            } footer: {
                if !controller.isSyncEnabled {
                    Text("Aktiviere den Sync, um iCloud-Synchronisation und Konfliktbehandlung zu verwenden.")
                } else {
                    Text("Der Abgleich arbeitet defensiv: Konflikte werden nicht still überschrieben, sondern hier sichtbar gemacht.")
                }
            }

            Section("Konflikte") {
                if controller.conflicts.isEmpty {
                    Text("Keine offenen Konflikte.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(controller.conflicts) { conflict in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(conflictTitle(for: conflict))
                                .font(.headline)
                            Text("Lokaler Stand und Cloud-Stand unterscheiden sich.")
                                .font(.subheadline)
                            Text("Abweichende Felder: \(conflict.conflictingFields.joined(separator: ", "))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Button("Konflikt lösen") {
                                selectedConflict = conflict
                            }
                        }
                        .padding(.vertical, 4)
                        .brandGroupedRow()
                    }
                }
            }

            Section("Papierkorb") {
                if controller.deletedEpisodes.isEmpty && controller.deletedDefinitions.isEmpty {
                    Text("Keine gelöschten Einträge.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(controller.deletedEpisodes) { episode in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(episode.startedAt.formatted(date: .abbreviated, time: .shortened))
                                Text(episode.type.rawValue)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Wiederherstellen") {
                                controller.restoreEpisode(id: episode.id)
                            }
                        }
                        .brandGroupedRow()
                    }

                    ForEach(controller.deletedDefinitions) { definition in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(definition.name)
                                Text(definition.category.rawValue)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Wiederherstellen") {
                                controller.restoreMedicationDefinition(definition)
                            }
                        }
                        .brandGroupedRow()
                    }
                }
            }
        }
        .navigationTitle("Cloud-Daten")
        .brandGroupedScreen()
        .disabled(isResolvingConflict)
        .overlay {
            if isResolvingConflict {
                ProgressView("Konflikt wird verarbeitet …")
                    .padding(20)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .confirmationDialog(
            selectedConflict.map(dialogTitle(for:)) ?? "Sync-Konflikt",
            isPresented: selectedConflictPresented,
            titleVisibility: .visible,
            presenting: selectedConflict
        ) { conflict in
            Button("Lokal hat recht") {
                resolveConflict(conflict, preferLocal: true)
            }
            Button("Cloud hat recht") {
                resolveConflict(conflict, preferLocal: false)
            }
            Button("Abbrechen", role: .cancel) {}
        } message: { conflict in
            Text(dialogMessage(for: conflict))
        }
        .onAppear {
            presentNextConflictIfNeeded()
        }
        .onChange(of: controller.conflicts.map(\.id)) { _, _ in
            presentNextConflictIfNeeded()
        }
        .refreshable {
            controller.load()
        }
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

    private var selectedConflictPresented: Binding<Bool> {
        Binding(
            get: { selectedConflict != nil },
            set: { isPresented in
                if !isPresented {
                    selectedConflict = nil
                }
            }
        )
    }

    private func dialogTitle(for conflict: SyncConflict) -> String {
        "\(conflictTitle(for: conflict)) in Konflikt"
    }

    private func dialogMessage(for conflict: SyncConflict) -> String {
        "Der lokale Stand und die Cloud-Daten unterscheiden sich. Wähle, welche Version gelten soll. Abweichende Felder: \(conflict.conflictingFields.joined(separator: ", "))."
    }

    private func presentNextConflictIfNeeded() {
        guard selectedConflict == nil, !controller.conflicts.isEmpty else {
            return
        }

        selectedConflict = controller.conflicts.first
    }

    private func resolveConflict(_ conflict: SyncConflict, preferLocal: Bool) {
        selectedConflict = nil
        isResolvingConflict = true

        Task {
            if preferLocal {
                await controller.resolveConflictKeepingLocal(conflict)
                await controller.syncNow()
            } else {
                await controller.resolveConflictUsingRemote(conflict)
            }

            await MainActor.run {
                isResolvingConflict = false
                presentNextConflictIfNeeded()
            }
        }
    }
}

#Preview {
    Text("Preview nicht verfügbar")
}
