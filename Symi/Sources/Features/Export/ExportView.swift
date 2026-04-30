import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let dependencies: SettingsFeatureDependencies
    let showsCloseButton: Bool
    @State private var controller: SettingsController

    init(dependencies: SettingsFeatureDependencies, showsCloseButton: Bool = true) {
        self.dependencies = dependencies
        self.showsCloseButton = showsCloseButton
        _controller = State(initialValue: dependencies.makeSettingsController())
    }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    SyncStatusView(controller: controller)
                } label: {
                    VStack(alignment: .leading, spacing: SymiSpacing.sm) {
                        HStack {
                            Text("Status")
                            Spacer()
                            statusBadge
                        }

                        Text(statusSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if let syncStalenessWarning {
                            Label(syncStalenessWarning, systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.symiCoral)
                        }

                        HStack(spacing: SymiSpacing.lg) {
                            statValue(title: "Ausstehend", value: "\(controller.syncStatus.queuedUpdates)")
                            statValue(title: "Ungesynct", value: "\(controller.syncStatus.unsyncedRecords)")
                            statValue(title: "Konflikte", value: "\(controller.conflicts.count)")
                        }

                        VStack(alignment: .leading, spacing: SymiSpacing.micro) {
                            Text("Upload: \(formatted(controller.syncStatus.lastUploadedAt))")
                            Text("Download: \(formatted(controller.syncStatus.lastDownloadedAt))")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, SymiSpacing.compact)
                    .brandGroupedRow()
                }

                Toggle("Sync aktivieren", isOn: Binding(
                    get: { controller.isSyncEnabled },
                    set: { controller.setSyncEnabled($0) }
                ))
                .tint(AppTheme.symiPetrol)

                NavigationLink {
                    ManageCloudDataView(dataExportDependencies: dependencies.dataExport, controller: controller)
                } label: {
                    Label("Cloud-Daten verwalten", systemImage: "icloud")
                }

                if !controller.conflicts.isEmpty {
                    NavigationLink {
                        ManageCloudDataView(dataExportDependencies: dependencies.dataExport, controller: controller)
                    } label: {
                        Label("\(controller.conflicts.count) Sync-Konflikt\(controller.conflicts.count == 1 ? "" : "e") entscheiden", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppTheme.symiCoral)
                    }
                }

                NavigationLink {
                    SyncLogView(controller: controller)
                } label: {
                    VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
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
                Text(syncContractSummary)
            }

            Section {
                NavigationLink {
                    AppleHealthSettingsView(controller: controller)
                } label: {
                    VStack(alignment: .leading, spacing: SymiSpacing.sm) {
                        HStack {
                            Label("Apple Health", systemImage: "heart.text.square")
                            Spacer()
                            Text(healthStatusTitle)
                                .foregroundStyle(.secondary)
                        }

                        Text("Lesen und Schreiben werden getrennt verwaltet. Die App nutzt nur Daten, die für Schmerzepisoden als Kontext sinnvoll sind.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, SymiSpacing.compact)
                    .brandGroupedRow()
                }
            } header: {
                Text("Gesundheit")
            } footer: {
                Text("Apple-Health-Daten bleiben optional. Gelesene Werte werden als Apple-Health-Kontext gekennzeichnet; geschriebene Symptome enthalten keine Notizen.")
            }

            Section("Allgemein") {
                NavigationLink {
                    ContinuousMedicationSettingsView(controller: controller)
                } label: {
                    Label("Dauermedikation", systemImage: "pills")
                }

                Link(destination: ProductBranding.websiteURL) {
                    Label("symiapp.com", systemImage: "link")
                }

                NavigationLink {
                    ProductInformationView(mode: .standard)
                } label: {
                    Label("Datenschutz und Hinweise", systemImage: "hand.raised")
                }
            }

            Section("Daten") {
                BackupSettingsCardView(dependencies: dependencies.dataExport)
            }

            Section {
                Toggle("Anonyme Nutzungsdaten teilen", isOn: Binding(
                    get: { controller.isUsageDataCollectionAllowed },
                    set: { controller.setUsageDataCollectionAllowed($0) }
                ))
                .tint(AppTheme.symiPetrol)
            } header: {
                Text("App verbessern")
            } footer: {
                Text("Symi verwendet nur anonyme Nutzungs- und Diagnosedaten. Tagebuchinhalte, Gesundheitsdaten und personenbezogene Daten werden nicht übertragen. Du kannst diese Einstellung jederzeit ändern.")
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
            if showsCloseButton {
                ToolbarItem(placement: closeButtonPlacement) {
                    Button("Schließen") {
                        dismiss()
                    }
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
            AppTheme.symiSage
        case .syncing:
            AppTheme.symiPetrol
        case .conflict, .needsAttention:
            AppTheme.symiCoral
        case .noICloudAccount, .offline:
            AppTheme.symiCoral
        case .disabled:
            .gray
        }
    }

    private var statusSubtitle: String {
        if let lastError = controller.syncStatus.lastError, !lastError.isEmpty {
            return lastError
        }

        return controller.isSyncEnabled
            ? "Synchronisation ist bereit. Lokale Änderungen bleiben bis zum nächsten Lauf sicher auf dem Gerät."
            : "Synchronisation ist deaktiviert. Alle Daten bleiben lokal auf diesem Gerät erhalten."
    }

    private var syncStalenessWarning: String? {
        controller.syncStatus.staleDataWarning(
            isSyncEnabled: controller.isSyncEnabled,
            openConflictCount: controller.conflicts.count
        )
    }

    private var syncContractSummary: String {
        [
            "Cloud-Sync läuft automatisch, sobald er aktiviert ist.",
            "Symi gleicht Änderungen ab, wenn die App geöffnet wird, wenn du Daten änderst oder wenn die Verbindung wieder da ist.",
            "„Jetzt synchronisieren“ startet zusätzlich sofort einen Abgleich."
        ].joined(separator: " ")
    }

    private var statusBadge: some View {
        HStack(spacing: SymiSpacing.xs) {
            Circle()
                .fill(statusColor)
                .frame(width: SymiSize.statusDot, height: SymiSize.statusDot)
            Text(controller.syncStatus.state.displayTitle)
                .foregroundStyle(.secondary)
        }
    }

    private func statValue(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: SymiSpacing.micro) {
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

    private func formatted(_ date: Date?) -> String {
        guard let date else {
            return "Noch nie"
        }

        return formatted(date)
    }

    private var logSubtitle: String {
        if let latest = controller.logEntries.first {
            return "Letzter Eintrag: \(formatted(latest.timestamp))"
        }

        return "Ansehen, teilen und bei Bedarf löschen."
    }

    private var healthStatusTitle: String {
        let status = controller.healthAuthorization
        guard status.isAvailable else {
            return "Nicht verfügbar"
        }

        if status.isReadEnabled, status.isWriteEnabled {
            return "Lesen und Schreiben"
        }

        if status.isReadEnabled {
            return "Lesen"
        }

        if status.isWriteEnabled {
            return "Schreiben"
        }

        return "Nicht verbunden"
    }

    private var closeButtonPlacement: ToolbarItemPlacement {
        #if targetEnvironment(macCatalyst)
        .topBarTrailing
        #else
        .topBarLeading
        #endif
    }
}

private struct ContinuousMedicationSettingsView: View {
    @Bindable var controller: SettingsController

    var body: some View {
        List {
            Section {
                Button {
                    controller.presentContinuousMedicationEditor(for: nil)
                } label: {
                    Label("Dauermedikation hinzufügen", systemImage: "plus")
                }
            } footer: {
                Text("Dauermedikationen sind ein eigener Verlaufskontext und bleiben von Akutmedikation in Einträgen getrennt.")
            }

            Section("Aktuell") {
                let active = controller.continuousMedications.filter(\.isActive)
                if active.isEmpty {
                    Text("Keine aktive Dauermedikation.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(active) { medication in
                        ContinuousMedicationSettingsRow(
                            medication: medication,
                            onEdit: { controller.presentContinuousMedicationEditor(for: medication) },
                            onEnd: { controller.endContinuousMedication(id: medication.id) }
                        )
                    }
                }
            }

            Section("Beendet") {
                let ended = controller.continuousMedications.filter { !$0.isActive }
                if ended.isEmpty {
                    Text("Keine beendete Dauermedikation.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(ended) { medication in
                        ContinuousMedicationSettingsRow(
                            medication: medication,
                            onEdit: { controller.presentContinuousMedicationEditor(for: medication) },
                            onEnd: nil
                        )
                    }
                }
            }

            if let message = controller.continuousMedicationMessage {
                Section {
                    Text(message)
                        .foregroundStyle(AppTheme.symiCoral)
                }
            }
        }
        .navigationTitle("Dauermedikation")
        .brandGroupedScreen()
        .sheet(item: $controller.continuousMedicationEditor) { draft in
            NavigationStack {
                ContinuousMedicationEditorSheet(
                    draft: draft,
                    onCancel: { controller.continuousMedicationEditor = nil },
                    onSave: { draft in
                        Task {
                            await controller.saveContinuousMedication(draft)
                        }
                    }
                )
            }
            .presentationDetents([.medium, .large])
        }
        .task {
            controller.load()
        }
        .refreshable {
            controller.load()
        }
    }
}

private struct ContinuousMedicationSettingsRow: View {
    let medication: ContinuousMedicationRecord
    let onEdit: () -> Void
    let onEnd: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
                    Text(medication.name)
                        .font(.headline)
                    if !medication.detailText.isEmpty {
                        Text(medication.detailText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(medication.isActive ? "Aktiv" : "Beendet")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(medication.isActive ? AppTheme.symiSage : .secondary)
            }

            Text(dateRangeText)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Bearbeiten", action: onEdit)
                if let onEnd {
                    Button("Beenden", role: .destructive, action: onEnd)
                }
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, SymiSpacing.xxs)
        .brandGroupedRow()
    }

    private var dateRangeText: String {
        let start = medication.startDate.formatted(date: .abbreviated, time: .omitted)
        guard let endDate = medication.endDate else {
            return "Seit \(start)"
        }

        return "\(start) bis \(endDate.formatted(date: .abbreviated, time: .omitted))"
    }
}

private struct ContinuousMedicationEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ContinuousMedicationDraft
    @State private var hasEndDate: Bool

    let onCancel: () -> Void
    let onSave: (ContinuousMedicationDraft) -> Void

    init(
        draft: ContinuousMedicationDraft,
        onCancel: @escaping () -> Void,
        onSave: @escaping (ContinuousMedicationDraft) -> Void
    ) {
        _draft = State(initialValue: draft)
        _hasEndDate = State(initialValue: draft.endDate != nil)
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Medikament") {
                TextField("Name", text: $draft.name)
                    .textInputAutocapitalization(.words)
                TextField("Dosierung, optional", text: $draft.dosage)
                TextField("Frequenz, optional", text: $draft.frequency)
            }

            Section("Zeitraum") {
                DatePicker("Startdatum", selection: $draft.startDate, displayedComponents: .date)
                Toggle("Enddatum setzen", isOn: $hasEndDate.animation())
                if hasEndDate {
                    DatePicker(
                        "Enddatum",
                        selection: Binding(
                            get: { draft.endDate ?? draft.startDate },
                            set: { draft.endDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                }
            }
        }
        .navigationTitle(draft.id == nil ? "Dauermedikation" : "Bearbeiten")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") {
                    onCancel()
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Sichern") {
                    var normalizedDraft = draft
                    if !hasEndDate {
                        normalizedDraft.endDate = nil
                    }
                    onSave(normalizedDraft)
                    dismiss()
                }
            }
        }
    }
}

private struct AppleHealthSettingsView: View {
    @Bindable var controller: SettingsController

    var body: some View {
        List {
            Section {
                let status = controller.healthAuthorization
                LabeledContent("Status", value: status.isAvailable ? "Verfügbar" : "Nicht verfügbar")
                LabeledContent("Lesen", value: status.isReadEnabled ? "Aktiviert" : "Deaktiviert")
                LabeledContent("Schreiben", value: status.isWriteEnabled ? "Aktiviert" : "Deaktiviert")

                if let message = status.lastErrorMessage {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Verbindung")
            } footer: {
                Text("iOS verwaltet Health-Berechtigungen pro Datentyp. Verweigerte Leserechte erscheinen in der App wie fehlende Daten.")
            }

            HealthDataTypeSection(
                title: "Lesen aus Apple Health",
                direction: .read,
                definitions: controller.healthReadDefinitions,
                enabledTypes: controller.healthAuthorization.enabledReadTypes,
                onToggle: controller.setHealthDataTypeEnabled
            )

            Section {
                Button {
                    Task {
                        await controller.requestHealthReadAuthorization()
                    }
                } label: {
                    Label("Leserechte anfragen", systemImage: "eye")
                }
                .disabled(!controller.healthAuthorization.isAvailable)
            }

            HealthDataTypeSection(
                title: "Schreiben nach Apple Health",
                direction: .write,
                definitions: controller.healthWriteDefinitions,
                enabledTypes: controller.healthAuthorization.enabledWriteTypes,
                onToggle: controller.setHealthDataTypeEnabled
            )

            Section {
                Button {
                    Task {
                        await controller.requestHealthWriteAuthorization()
                    }
                } label: {
                    Label("Schreibrechte anfragen", systemImage: "square.and.pencil")
                }
                .disabled(!controller.healthAuthorization.isAvailable)
            } footer: {
                Text("Geschrieben werden nur ausreichend präzise, nutzererfasste Symptome. Zyklusangaben aus der App wie „aktuell“ oder „erwartet“ bleiben Kontext und werden nicht als exakte Health-Flow-Samples gespeichert.")
            }
        }
        .navigationTitle("Apple Health")
        .brandGroupedScreen()
    }
}

private struct HealthDataTypeSection: View {
    let title: String
    let direction: HealthDataDirection
    let definitions: [HealthDataTypeDefinition]
    let enabledTypes: Set<HealthDataTypeID>
    let onToggle: (Bool, HealthDataTypeID, HealthDataDirection) -> Void

    var body: some View {
        Section(title) {
            ForEach(definitions) { definition in
                Toggle(isOn: Binding(
                    get: { enabledTypes.contains(definition.id) },
                    set: { onToggle($0, definition.id, direction) }
                )) {
                    VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
                        Text(definition.displayName)
                        Text("\(definition.category.rawValue) · \(definition.healthKitIdentifier)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(definition.rationale)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let availabilityNote = definition.availabilityNote {
                            Text(availabilityNote)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(AppTheme.symiPetrol)
            }
        }
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
                statusRow("Offene Konflikte", "\(controller.conflicts.count)")
                statusRow("Letzter Download", formatted(controller.syncStatus.lastDownloadedAt))
                statusRow("Letzter Upload", formatted(controller.syncStatus.lastUploadedAt))

                if let syncStalenessWarning {
                    Label(syncStalenessWarning, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.symiCoral)
                        .padding(.vertical, SymiSpacing.xxs)
                        .brandGroupedRow()
                }

                if let lastError = controller.syncStatus.lastError {
                    VStack(alignment: .leading, spacing: SymiSpacing.compact) {
                        Text("Letzter Fehler")
                        Text(lastError)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, SymiSpacing.xxs)
                    .brandGroupedRow()
                }
            } header: {
                Text("Status")
            } footer: {
                Text(statusFooter)
            }

            Section("Sync-Vertrag") {
                Text([
                    "Symi speichert deine Daten zuerst sicher auf diesem Gerät.",
                    "Wenn Cloud-Sync aktiv ist, gleicht Symi Änderungen automatisch mit iCloud ab: beim Aktivieren, beim Öffnen der App, nach Änderungen und sobald die Verbindung wieder da ist.",
                    "„Jetzt synchronisieren“ startet zusätzlich sofort einen Abgleich.",
                    "Wenn etwas nicht klappt, bleiben deine lokalen Daten erhalten. Symi zeigt dir, ob du es erneut versuchen kannst oder ob erst ein App- oder Cloud-Problem behoben werden muss.",
                    "Bei Unterschieden zwischen Geräten entscheidet Symi nicht still für dich. Konflikte bleiben sichtbar, bis du auswählst, welcher Stand gelten soll."
                ].joined(separator: " "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .brandGroupedRow()
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
            "Der Sync-Dienst ist bereit. Änderungen werden automatisch und per „Jetzt synchronisieren“ in die private iCloud-Datenbank übertragen."
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

    private var syncStalenessWarning: String? {
        controller.syncStatus.staleDataWarning(
            isSyncEnabled: controller.isSyncEnabled,
            openConflictCount: controller.conflicts.count
        )
    }
}

private struct ManageCloudDataView: View {
    let dataExportDependencies: DataExportFeatureDependencies
    @Bindable var controller: SettingsController
    @State private var isResolvingConflict = false

    var body: some View {
        List {
            Section {
                statusRow("Sync", controller.isSyncEnabled ? "Aktiviert" : "Deaktiviert")
                statusRow("Letzter Upload", formatted(controller.syncStatus.lastUploadedAt))
                statusRow("Letzter Download", formatted(controller.syncStatus.lastDownloadedAt))
                statusRow("Ungesyncte Records", "\(controller.syncStatus.unsyncedRecords)")
                statusRow("Offene Konflikte", "\(controller.conflicts.count)")
                statusRow("Papierkorb", "\(controller.summary.trashCount)")

                if let syncStalenessWarning {
                    Label(syncStalenessWarning, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.symiCoral)
                        .padding(.vertical, SymiSpacing.xxs)
                        .brandGroupedRow()
                }
            } header: {
                Text("Übersicht")
            } footer: {
                Text("Papierkorb-Einträge bleiben lokal und in der Cloud erhalten, bis du sie bewusst wiederherstellst oder später einmal endgültig entfernst. Bei aktiviertem Cloud-Sync läuft der Abgleich automatisch; „Jetzt synchronisieren“ startet zusätzlich sofort einen Lauf.")
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
                .disabled(!controller.isSyncEnabled || !controller.syncStatus.lastErrorIsRetryable)

                NavigationLink {
                    DataBackupSettingsView(dependencies: dataExportDependencies)
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
                    Label("\(controller.conflicts.count) Konflikt\(controller.conflicts.count == 1 ? "" : "e") warten auf deine Entscheidung.", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.symiCoral)
                        .padding(.vertical, SymiSpacing.xxs)
                        .brandGroupedRow()

                    ForEach(controller.conflicts) { conflict in
                        VStack(alignment: .leading, spacing: SymiSpacing.xs) {
                            Text(conflictTitle(for: conflict))
                                .font(.headline)
                            Text("Lokaler Stand und Cloud-Stand unterscheiden sich.")
                                .font(.subheadline)
                            Text(versionSummary("Lokal", envelope: conflict.local))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(versionSummary("Cloud", envelope: conflict.remote))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Abweichende Felder: \(conflict.conflictingFields.joined(separator: ", "))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            HStack(spacing: SymiSpacing.sm) {
                                Button("Lokale Version behalten") {
                                    resolveConflict(conflict, preferLocal: true)
                                }
                                .buttonStyle(.bordered)

                                Button("Cloud-Version übernehmen") {
                                    resolveConflict(conflict, preferLocal: false)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .disabled(isResolvingConflict)
                        }
                        .padding(.vertical, SymiSpacing.xxs)
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
                            VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
                                Text(episode.startedAt.formatted(date: .abbreviated, time: .shortened))
                                Text(episode.type.displayName)
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
                            VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
                                Text(definition.name)
                                Text(definition.category.displayName)
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
                    .padding(SymiSpacing.xxl)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: SymiRadius.flowBanner, style: .continuous))
            }
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
        case .continuousMedication:
            "Dauermedikation"
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

    private func versionSummary(_ title: String, envelope: SyncDocumentEnvelope) -> String {
        let deletedSuffix = envelope.deletedAt == nil ? "" : " · gelöscht"
        return "\(title): geändert \(formatted(envelope.modifiedAt))\(deletedSuffix)"
    }

    private var syncStalenessWarning: String? {
        controller.syncStatus.staleDataWarning(
            isSyncEnabled: controller.isSyncEnabled,
            openConflictCount: controller.conflicts.count
        )
    }

    private func resolveConflict(_ conflict: SyncConflict, preferLocal: Bool) {
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
            }
        }
    }
}

#Preview {
    Text("Preview nicht verfügbar")
}
