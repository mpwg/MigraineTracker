import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let dependencies: SettingsFeatureDependencies
    let showsCloseButton: Bool
    @State private var controller: SettingsController
    @State private var showsResetInformation = false

    init(dependencies: SettingsFeatureDependencies, showsCloseButton: Bool = true) {
        self.dependencies = dependencies
        self.showsCloseButton = showsCloseButton
        _controller = State(initialValue: dependencies.makeSettingsController())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SymiSpacing.xxl) {
                SettingsSectionCard(title: "Synchronisation") {
                    NavigationLink {
                        SyncStatusView(controller: controller)
                    } label: {
                        SettingsStatusHeader(
                            systemImage: syncStatusIcon,
                            title: controller.syncStatusTitle,
                            detail: controller.syncStatusDetail,
                            tint: statusColor
                        )
                    }

                    SettingsDivider()

                    SettingsToggleRow(
                        title: "Synchronisation aktivieren",
                        isOn: Binding(
                            get: { controller.isSyncEnabled },
                            set: { controller.setSyncEnabled($0) }
                        )
                    )

                    SettingsDivider()

                    Button {
                        Task {
                            await controller.syncNow()
                        }
                    } label: {
                        SettingsRow(
                            title: "Jetzt synchronisieren",
                            subtitle: "Alle Daten mit iCloud abgleichen",
                            systemImage: "arrow.triangle.2.circlepath",
                            isEnabled: controller.isSyncEnabled
                        )
                    }
                    .disabled(!controller.isSyncEnabled)

                    SettingsDivider()

                    NavigationLink {
                        ManageCloudDataView(dataExportDependencies: dependencies.dataExport, controller: controller)
                    } label: {
                        SettingsRow(
                            title: controller.conflicts.isEmpty ? "Cloud-Daten verwalten" : "\(controller.conflicts.count) Sync-Konflikt\(controller.conflicts.count == 1 ? "" : "e") entscheiden",
                            subtitle: "Speicher, Geräte und Daten",
                            systemImage: controller.conflicts.isEmpty ? "icloud" : "exclamationmark.triangle.fill",
                            tint: controller.conflicts.isEmpty ? AppTheme.symiPetrol : AppTheme.symiCoral,
                            showsChevron: true
                        )
                    }

                    SettingsDivider()

                    NavigationLink {
                        SyncLogView(controller: controller)
                    } label: {
                        SettingsRow(
                            title: "Sync-Protokoll",
                            subtitle: controller.syncLogSubtitle,
                            systemImage: "text.document",
                            showsChevron: true
                        )
                    }
                }

                SettingsSectionCard(title: "Verbindungen") {
                    NavigationLink {
                        AppleHealthSettingsView(controller: controller)
                    } label: {
                        SettingsRow(
                            title: "Apple Health",
                            subtitle: "Lese- und Schreibzugriff für Symi",
                            assetImageName: "AppleHealthIcon",
                            rightValue: controller.healthConnectionStatusTitle,
                            showsChevron: true
                        )
                    }

                    if !controller.isHealthConnected {
                        SettingsDivider()

                        NavigationLink {
                            AppleHealthSettingsView(controller: controller)
                        } label: {
                            SettingsRow(
                                title: "Verbindung herstellen",
                                systemImage: "link",
                                showsChevron: true
                            )
                        }
                    }
                }

                SettingsSectionCard(title: "Daten & Sicherheit") {
                    NavigationLink {
                        DataBackupSettingsView(dependencies: dependencies.dataExport)
                    } label: {
                        SettingsRow(
                            title: "Backup erstellen",
                            subtitle: "Sichert alle Einträge und Vorlagen",
                            systemImage: "externaldrive.badge.plus",
                            showsChevron: true
                        )
                    }

                    SettingsDivider()

                    NavigationLink {
                        DataBackupSettingsView(dependencies: dependencies.dataExport)
                    } label: {
                        SettingsRow(
                            title: "Daten exportieren",
                            subtitle: "Deine Daten als Datei sichern",
                            systemImage: "square.and.arrow.up",
                            showsChevron: true
                        )
                    }

                    SettingsDivider()

                    Button {
                        showsResetInformation = true
                    } label: {
                        SettingsRow(
                            title: "Daten zurücksetzen",
                            subtitle: "Alle Daten unwiderruflich löschen",
                            systemImage: "trash",
                            tint: AppTheme.symiCoral,
                            isDestructive: true
                        )
                    }
                }

                SettingsSectionCard(title: "Datenschutz") {
                    SettingsToggleRow(
                        title: "Anonyme Nutzungsdaten teilen",
                        subtitle: "Hilft uns, Symi zu verbessern. Deine persönlichen Einträge bleiben immer privat.",
                        isOn: Binding(
                            get: { controller.isUsageDataCollectionAllowed },
                            set: { controller.setUsageDataCollectionAllowed($0) }
                        )
                    )

                    SettingsDivider()

                    NavigationLink {
                        ProductInformationView(mode: .standard)
                    } label: {
                        SettingsRow(
                            title: "Datenschutz & Hinweise",
                            systemImage: "hand.raised",
                            showsChevron: true
                        )
                    }
                }

                SettingsSectionCard(title: "App") {
                    SettingsRow(
                        title: "Version",
                        systemImage: "info.circle",
                        rightValue: controller.appVersionDisplay
                    )

                    SettingsDivider()

                    Link(destination: ProductBranding.supportURL) {
                        SettingsRow(
                            title: "Feedback senden",
                            subtitle: "Hast du Wünsche oder Probleme?",
                            systemImage: "bubble.left.and.text.bubble.right",
                            showsChevron: true
                        )
                    }
                }
            }
            .padding(.horizontal, SymiSpacing.xxl)
            .padding(.top, SymiSpacing.xxxl)
            .padding(.bottom, 96)
            .wideContent(maxWidth: AppTheme.readableContentMaxWidth)
        }
        .navigationTitle("Einstellungen")
        .brandScreen()
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
        .alert("Daten zurücksetzen", isPresented: $showsResetInformation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Das endgültige Löschen aller Daten ist derzeit nicht direkt aus dieser Ansicht verfügbar.")
        }
    }

    private var statusColor: Color {
        if !controller.conflicts.isEmpty {
            return AppTheme.symiCoral
        }

        return switch controller.syncStatus.state {
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

    private var syncStatusIcon: String {
        if !controller.conflicts.isEmpty {
            return "exclamationmark.triangle.fill"
        }

        switch controller.syncStatus.state {
        case .syncing:
            return "arrow.triangle.2.circlepath"
        case .needsAttention, .noICloudAccount, .offline:
            return "icloud.slash"
        case .conflict:
            return "exclamationmark.triangle.fill"
        case .disabled, .ready:
            return "icloud"
        }
    }

    private var closeButtonPlacement: ToolbarItemPlacement {
        #if targetEnvironment(macCatalyst)
        .topBarTrailing
        #else
        .topBarLeading
        #endif
    }
}

private struct SettingsSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.md) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.symiTextPrimary)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: SymiSpacing.zero) {
                content
            }
            .padding(.vertical, SymiSpacing.xs)
            .brandCard()
        }
    }
}

private struct SettingsStatusHeader: View {
    let systemImage: String
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: SymiSpacing.md) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(SymiOpacity.secondaryFill), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.symiTextPrimary)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.symiTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: SymiSpacing.sm)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, SymiSpacing.xs)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, SymiSpacing.lg)
        .padding(.vertical, SymiSpacing.md)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(detail)")
    }
}

private struct SettingsRow: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    var assetImageName: String?
    var rightValue: String?
    var tint: Color = AppTheme.symiPetrol
    var showsChevron = false
    var isDestructive = false
    var isEnabled = true

    var body: some View {
        HStack(alignment: .center, spacing: SymiSpacing.md) {
            iconView

            VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(isDestructive ? AppTheme.symiCoral : AppTheme.symiTextPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.symiTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: SymiSpacing.sm)

            if let rightValue {
                Text(rightValue)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.symiTextSecondary)
                    .multilineTextAlignment(.trailing)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, SymiSpacing.lg)
        .padding(.vertical, SymiSpacing.md)
        .frame(minHeight: SymiSize.minInteractiveHeight)
        .contentShape(Rectangle())
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var iconView: some View {
        if let assetImageName {
            Image(assetImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .accessibilityHidden(true)
        } else if let systemImage {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(isDestructive ? AppTheme.symiCoral : tint)
                .frame(width: 30, height: 30)
                .background((isDestructive ? AppTheme.symiCoral : tint).opacity(SymiOpacity.secondaryFill), in: Circle())
                .accessibilityHidden(true)
        }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(AppTheme.symiTextPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.symiTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(AppTheme.symiPetrol)
        .padding(.horizontal, SymiSpacing.lg)
        .padding(.vertical, SymiSpacing.md)
        .frame(minHeight: SymiSize.minInteractiveHeight)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "Aktiviert" : "Deaktiviert")
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 62)
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

                if let lastError = controller.userFacingSyncErrorMessage {
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
                    "Änderungen werden automatisch synchronisiert, sobald iCloud-Sync aktiv ist.",
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
            return "Noch keine Daten synchronisiert"
        }

        return date.formatted(date: .numeric, time: .shortened)
    }

    private var statusFooter: String {
        switch controller.syncStatus.state {
        case .disabled:
            "Der Cloud-Sync ist ausgeschaltet. Lokale Daten bleiben unverändert verfügbar."
        case .ready:
            "Der Sync-Dienst ist bereit. Änderungen werden automatisch synchronisiert. „Jetzt synchronisieren“ startet zusätzlich sofort einen Abgleich."
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
                statusRow("Nicht synchronisiert", "\(controller.syncStatus.unsyncedRecords)")
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
                Text("Papierkorb-Einträge bleiben lokal und in der Cloud erhalten, bis du sie bewusst wiederherstellst oder später einmal endgültig entfernst. Änderungen werden automatisch synchronisiert. „Jetzt synchronisieren“ startet zusätzlich sofort einen Lauf.")
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
                    Text("Wenn zwei Geräte denselben Eintrag unterschiedlich geändert haben, entscheidest du hier, welche Version bleiben soll.")
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
                        let differences = ConflictDiffPresenter.differences(for: conflict)

                        VStack(alignment: .leading, spacing: SymiSpacing.xs) {
                            Text(ConflictDiffPresenter.title(for: conflict))
                                .font(.headline)
                            Text("Es gibt unterschiedliche Änderungen für diesen Eintrag.")
                                .font(.subheadline)

                            Text("Bitte wähle, welche Version du behalten möchtest.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: SymiSpacing.xs) {
                                ForEach(differences) { difference in
                                    ConflictDifferenceRow(difference: difference)
                                }
                            }
                            .padding(.top, SymiSpacing.xxs)

                            HStack(spacing: SymiSpacing.sm) {
                                Button("Meine Version behalten") {
                                    resolveConflict(conflict, preferLocal: true)
                                }
                                .buttonStyle(.bordered)

                                VStack(alignment: .leading, spacing: SymiSpacing.micro) {
                                    Button("Version aus der Cloud verwenden") {
                                        resolveConflict(conflict, preferLocal: false)
                                    }
                                    .buttonStyle(.borderedProminent)

                                    Text("(empfohlen, wenn du mehrere Geräte nutzt)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.top, SymiSpacing.xxs)
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
        .task {
            await resolveIdenticalConflictsIfNeeded()
        }
        .onChange(of: controller.conflicts.map(\.id)) { _, _ in
            Task {
                await resolveIdenticalConflictsIfNeeded()
            }
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
            return "Noch keine Daten synchronisiert"
        }

        return date.formatted(date: .numeric, time: .shortened)
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

    private func resolveIdenticalConflictsIfNeeded() async {
        let identicalConflicts = controller.conflicts.filter {
            ConflictDiffPresenter.differences(for: $0).isEmpty
        }

        guard !identicalConflicts.isEmpty else {
            return
        }

        for conflict in identicalConflicts {
            await controller.resolveConflictUsingRemote(conflict)
        }
        controller.load()
    }
}

private struct ConflictDifferenceRow: View {
    let difference: ConflictDisplayDifference

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.micro) {
            Text(difference.label)
                .font(.subheadline.weight(.semibold))

            HStack(alignment: .firstTextBaseline, spacing: SymiSpacing.xs) {
                Text(difference.myValue)
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(difference.cloudValue)
                    .foregroundStyle(SymiColors.primaryPetrol.color)
            }
            .font(.subheadline)
            .textSelection(.enabled)
        }
    }
}

private struct ConflictDisplayDifference: Identifiable, Equatable {
    let id: String
    let label: String
    let myValue: String
    let cloudValue: String
}

private enum ConflictDiffPresenter {
    static func title(for conflict: SyncConflict) -> String {
        switch conflict.local.payload {
        case .episode(let payload):
            return "Eintrag vom \(dateOnly(payload.startedAt))"
        case .medicationDefinition(let payload):
            return payload.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Medikament" : payload.name
        case .continuousMedication(let payload):
            return payload.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Regelmäßige Medikation" : payload.name
        }
    }

    static func differences(for conflict: SyncConflict) -> [ConflictDisplayDifference] {
        var differences: [ConflictDisplayDifference] = []
        appendDifference(
            id: "deletedAt",
            label: "Status",
            myValue: conflict.local.deletedAt == nil ? "Vorhanden" : "Entfernt",
            cloudValue: conflict.remote.deletedAt == nil ? "Vorhanden" : "Entfernt",
            to: &differences
        )

        switch (conflict.local.payload, conflict.remote.payload) {
        case (.episode(let local), .episode(let remote)):
            appendEpisodeDifferences(local: local, remote: remote, to: &differences)
        case (.medicationDefinition(let local), .medicationDefinition(let remote)):
            appendMedicationDefinitionDifferences(local: local, remote: remote, to: &differences)
        case (.continuousMedication(let local), .continuousMedication(let remote)):
            appendContinuousMedicationDifferences(local: local, remote: remote, to: &differences)
        default:
            appendDifference(id: "kind", label: "Art des Eintrags", myValue: "Eintrag", cloudValue: "Andere Art von Eintrag", to: &differences)
        }

        return differences
    }

    private static func appendEpisodeDifferences(
        local: SyncEpisodePayload,
        remote: SyncEpisodePayload,
        to differences: inout [ConflictDisplayDifference]
    ) {
        appendDifference(id: "startedAt", label: "Beginn", myValue: dateAndTime(local.startedAt), cloudValue: dateAndTime(remote.startedAt), to: &differences)
        appendDifference(id: "endedAt", label: "Ende", myValue: optionalDateAndTime(local.endedAt), cloudValue: optionalDateAndTime(remote.endedAt), to: &differences)
        appendDifference(id: "type", label: "Art des Eintrags", myValue: episodeType(local.type), cloudValue: episodeType(remote.type), to: &differences)
        appendDifference(id: "intensity", label: "Schmerzstärke", myValue: intensity(local.intensity), cloudValue: intensity(remote.intensity), to: &differences)
        appendDifference(id: "painLocation", label: "Schmerzort", myValue: text(local.painLocation), cloudValue: text(remote.painLocation), to: &differences)
        appendDifference(id: "painCharacter", label: "Schmerzart", myValue: text(local.painCharacter), cloudValue: text(remote.painCharacter), to: &differences)
        appendDifference(id: "notes", label: "Notiz", myValue: text(local.notes), cloudValue: text(remote.notes), to: &differences)
        appendDifference(id: "symptoms", label: "Symptome", myValue: list(local.symptoms), cloudValue: list(remote.symptoms), to: &differences)
        appendDifference(id: "triggers", label: "Auslöser", myValue: list(local.triggers), cloudValue: list(remote.triggers), to: &differences)
        appendDifference(id: "functionalImpact", label: "Auswirkung im Alltag", myValue: text(local.functionalImpact), cloudValue: text(remote.functionalImpact), to: &differences)
        appendDifference(id: "menstruationStatus", label: "Zyklusstatus", myValue: menstruationStatus(local.menstruationStatus), cloudValue: menstruationStatus(remote.menstruationStatus), to: &differences)
        appendDifference(id: "medications", label: "Medikamente", myValue: medicationList(local.medications), cloudValue: medicationList(remote.medications), to: &differences)
        appendDifference(id: "continuousMedicationChecks", label: "Regelmäßige Medikation", myValue: continuousMedicationChecks(local.continuousMedicationChecks), cloudValue: continuousMedicationChecks(remote.continuousMedicationChecks), to: &differences)
        appendDifference(id: "weatherSnapshot", label: "Wetter", myValue: weather(local.weatherSnapshot), cloudValue: weather(remote.weatherSnapshot), to: &differences)
        appendDifference(id: "healthContext", label: "Apple-Health-Kontext", myValue: healthContext(local.healthContext), cloudValue: healthContext(remote.healthContext), to: &differences)
    }

    private static func appendMedicationDefinitionDifferences(
        local: SyncMedicationDefinitionPayload,
        remote: SyncMedicationDefinitionPayload,
        to differences: inout [ConflictDisplayDifference]
    ) {
        appendDifference(id: "name", label: "Name", myValue: text(local.name), cloudValue: text(remote.name), to: &differences)
        appendDifference(id: "category", label: "Kategorie", myValue: medicationCategory(local.category), cloudValue: medicationCategory(remote.category), to: &differences)
        appendDifference(id: "suggestedDosage", label: "Dosierung", myValue: text(local.suggestedDosage), cloudValue: text(remote.suggestedDosage), to: &differences)
        appendDifference(id: "groupTitle", label: "Gruppe", myValue: text(local.groupTitle), cloudValue: text(remote.groupTitle), to: &differences)
    }

    private static func appendContinuousMedicationDifferences(
        local: SyncContinuousMedicationPayload,
        remote: SyncContinuousMedicationPayload,
        to differences: inout [ConflictDisplayDifference]
    ) {
        appendDifference(id: "name", label: "Name", myValue: text(local.name), cloudValue: text(remote.name), to: &differences)
        appendDifference(id: "dosage", label: "Dosierung", myValue: text(local.dosage), cloudValue: text(remote.dosage), to: &differences)
        appendDifference(id: "frequency", label: "Häufigkeit", myValue: text(local.frequency), cloudValue: text(remote.frequency), to: &differences)
        appendDifference(id: "startDate", label: "Start", myValue: dateOnly(local.startDate), cloudValue: dateOnly(remote.startDate), to: &differences)
        appendDifference(id: "endDate", label: "Ende", myValue: optionalDateOnly(local.endDate), cloudValue: optionalDateOnly(remote.endDate), to: &differences)
    }

    private static func appendDifference(
        id: String,
        label: String,
        myValue: String,
        cloudValue: String,
        to differences: inout [ConflictDisplayDifference]
    ) {
        guard myValue != cloudValue else {
            return
        }

        differences.append(
            ConflictDisplayDifference(
                id: id,
                label: label,
                myValue: myValue,
                cloudValue: cloudValue
            )
        )
    }

    private static func text(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Nicht eingetragen" : trimmed
    }

    private static func list(_ values: [String]) -> String {
        let cleaned = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()

        return cleaned.isEmpty ? "Nicht vorhanden" : cleaned.joined(separator: ", ")
    }

    private static func episodeType(_ value: String) -> String {
        EpisodeType(storageValue: value).displayName
    }

    private static func menstruationStatus(_ value: String) -> String {
        MenstruationStatus(storageValue: value).displayName
    }

    private static func medicationCategory(_ value: String) -> String {
        MedicationCategory(storageValue: value).displayName
    }

    private static func medicationEffectiveness(_ value: String) -> String {
        MedicationEffectiveness(storageValue: value).displayName
    }

    private static func intensity(_ value: Int) -> String {
        value <= 0 ? "Nicht bewertet" : "\(value) (\(PainIntensityLevel(intensity: value).displayLabel))"
    }

    private static func medicationList(_ medications: [SyncMedicationEntryPayload]) -> String {
        let summaries = medications
            .map { medication in
                [
                    text(medication.name),
                    text(medication.dosage),
                    medication.quantity > 1 ? "\(medication.quantity)x" : nil,
                    medicationEffectiveness(medication.effectiveness) == "Teilweise" ? nil : "Wirkung: \(medicationEffectiveness(medication.effectiveness))"
                ]
                .compactMap { $0 }
                .filter { $0 != "Nicht eingetragen" }
                .joined(separator: " · ")
            }
            .filter { !$0.isEmpty }
            .sorted()

        return summaries.isEmpty ? "Nicht vorhanden" : summaries.joined(separator: ", ")
    }

    private static func continuousMedicationChecks(_ checks: [SyncContinuousMedicationCheckPayload]) -> String {
        let summaries = checks
            .map { check in
                let status = check.wasTaken ? "genommen" : "nicht genommen"
                return [text(check.name), text(check.dosage), status]
                    .filter { $0 != "Nicht eingetragen" }
                    .joined(separator: " · ")
            }
            .filter { !$0.isEmpty }
            .sorted()

        return summaries.isEmpty ? "Nicht vorhanden" : summaries.joined(separator: ", ")
    }

    private static func weather(_ weather: SyncWeatherSnapshotPayload?) -> String {
        guard let weather else {
            return "Nicht vorhanden"
        }

        var parts = [text(weather.condition)]
        if let temperature = weather.temperature {
            parts.append("\(temperature.formatted(.number.precision(.fractionLength(0 ... 1)))) °C")
        }
        return parts.joined(separator: ", ")
    }

    private static func healthContext(_ context: HealthContextSnapshotData?) -> String {
        context == nil ? "Nicht vorhanden" : "Vorhanden"
    }

    private static func optionalDateAndTime(_ date: Date?) -> String {
        guard let date else {
            return "Nicht eingetragen"
        }

        return dateAndTime(date)
    }

    private static func optionalDateOnly(_ date: Date?) -> String {
        guard let date else {
            return "Nicht eingetragen"
        }

        return dateOnly(date)
    }

    private static func dateAndTime(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private static func dateOnly(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}

#Preview {
    Text("Preview nicht verfügbar")
}
