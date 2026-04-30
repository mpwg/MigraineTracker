import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let dependencies: SettingsFeatureDependencies
    let showsCloseButton: Bool
    @State private var controller: SettingsController
    @State private var showsResetInformation = false
    @State private var showsDisableSyncConfirmation = false
    @State private var showsDeleteCloudDataConfirmation = false
    @State private var pendingSyncDisable = false

    init(dependencies: SettingsFeatureDependencies, showsCloseButton: Bool = true) {
        self.dependencies = dependencies
        self.showsCloseButton = showsCloseButton
        _controller = State(initialValue: dependencies.makeSettingsController())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SymiSpacing.xxl) {
                SettingsSectionCard(title: "Synchronisation") {
                    SettingsStatusHeader(
                        systemImage: syncStatusIcon,
                        title: controller.syncStatusTitle,
                        detail: controller.syncStatusDetail,
                        tint: statusColor
                    )

                    SettingsToggleRow(
                        title: "Synchronisation aktivieren",
                        systemImage: "icloud",
                        tint: AppTheme.symiPetrol,
                        isOn: Binding(
                            get: { controller.isSyncEnabled },
                            set: { newValue in
                                if newValue == false {
                                    pendingSyncDisable = true
                                    showsDisableSyncConfirmation = true
                                } else {
                                    controller.setSyncEnabled(true)
                                }
                            }
                        )
                    )
                    .disabled(pendingSyncDisable || showsDisableSyncConfirmation || showsDeleteCloudDataConfirmation)
                    .confirmationDialog(
                        "Synchronisation deaktivieren?",
                        isPresented: $showsDisableSyncConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Daten behalten") {
                            controller.disableSyncKeepingCloudData()
                            pendingSyncDisable = false
                        }

                        if controller.canOfferCloudDataDeletion {
                            Button("Cloud-Daten löschen", role: .destructive) {
                                showsDeleteCloudDataConfirmation = true
                            }
                        }

                        Button("Abbrechen", role: .cancel) {
                            pendingSyncDisable = false
                        }
                    } message: {
                        Text(disableSyncConfirmationMessage)
                    }

                    SettingsDivider()

                    Button {
                        Task {
                            await controller.syncNow()
                        }
                    } label: {
                        SettingsRow(
                            title: "Jetzt synchronisieren",
                            subtitle: "Alle Daten mit iCloud synchronisieren",
                            systemImage: "arrow.triangle.2.circlepath",
                            rowStyle: .primaryAction,
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
                            rowStyle: .navigation,
                            showsChevron: true
                        )
                    }

                    NavigationLink {
                        SyncLogView(controller: controller)
                    } label: {
                        SettingsRow(
                            title: "Sync-Protokoll",
                            subtitle: controller.syncLogSubtitle,
                            systemImage: "text.document",
                            tint: AppTheme.symiPetrol,
                            rowStyle: .navigation,
                            showsChevron: true
                        )
                    }
                }

                SettingsSectionCard(title: "Verbindungen") {
                    NavigationLink {
                        AppleHealthSettingsView(controller: controller)
                    } label: {
                        AppleHealthCardView(
                            statusTitle: controller.healthConnectionStatusTitle,
                            isConnected: controller.isHealthConnected
                        )
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
                            tint: SettingsIconPalette.dataSecurity,
                            rowStyle: .navigation,
                            showsChevron: true
                        )
                    }

                    NavigationLink {
                        DataBackupSettingsView(dependencies: dependencies.dataExport)
                    } label: {
                        SettingsRow(
                            title: "Daten exportieren",
                            subtitle: "Deine Daten als Datei sichern",
                            systemImage: "square.and.arrow.up",
                            tint: SettingsIconPalette.dataSecurity,
                            rowStyle: .navigation,
                            showsChevron: true
                        )
                    }

                    Button {
                        showsResetInformation = true
                    } label: {
                        SettingsRow(
                            title: "Daten zurücksetzen",
                            subtitle: "Alle Daten unwiderruflich löschen",
                            systemImage: "trash",
                            tint: AppTheme.symiCoral,
                            rowStyle: .destructive,
                            isDestructive: true
                        )
                    }
                }

                SettingsSectionCard(title: "Datenschutz") {
                    SettingsToggleRow(
                        title: "Anonyme Nutzungsdaten teilen",
                        subtitle: "Hilft uns, Symi zu verbessern. Deine persönlichen Einträge bleiben immer privat.",
                        systemImage: "chart.bar",
                        tint: AppTheme.symiSage,
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
                            tint: AppTheme.symiSage,
                            rowStyle: .navigation,
                            showsChevron: true
                        )
                    }
                }

                SettingsSectionCard(title: "App") {
                    SettingsRow(
                        title: "Version",
                        systemImage: "info.circle",
                        rightValue: controller.appVersionDisplay,
                        tint: AppTheme.symiPetrol
                    )

                    SettingsDivider()

                    Link(destination: ProductBranding.supportURL) {
                        SettingsRow(
                            title: "Feedback senden",
                            subtitle: "Hast du Wünsche oder Probleme?",
                            systemImage: "bubble.left.and.text.bubble.right",
                            tint: AppTheme.symiPetrol,
                            rowStyle: .navigation,
                            showsChevron: true
                        )
                    }
                }
            }
            .padding(.horizontal, SymiSpacing.xxl)
            .padding(.top, SymiSpacing.xxxl)
            .padding(.bottom, SymiSpacing.settingsContentBottomPadding)
            .wideContent(maxWidth: AppTheme.readableContentMaxWidth)
        }
        .safeAreaPadding(.bottom, SymiSpacing.settingsSafeAreaBottomPadding)
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
        .alert("Cloud-Daten wirklich löschen?", isPresented: $showsDeleteCloudDataConfirmation) {
            Button("Jetzt löschen", role: .destructive) {
                Task {
                    await controller.disableSyncAndDeleteCloudData()
                    pendingSyncDisable = false
                }
            }

            Button("Abbrechen", role: .cancel) {
                pendingSyncDisable = false
            }
        } message: {
            Text("Deine Daten werden dauerhaft aus iCloud entfernt.\nDieser Schritt kann nicht rückgängig gemacht werden.")
        }
        .onChange(of: showsDisableSyncConfirmation) { _, isPresented in
            if !isPresented && !showsDeleteCloudDataConfirmation {
                pendingSyncDisable = false
            }
        }
        .onChange(of: showsDeleteCloudDataConfirmation) { _, isPresented in
            if !isPresented {
                pendingSyncDisable = false
            }
        }
    }

    private var disableSyncConfirmationMessage: String {
        guard controller.canOfferCloudDataDeletion else {
            if controller.isCloudUnavailableForSyncDisableFlow {
                return "iCloud ist derzeit nicht verfügbar.\nDeine Daten bleiben auf diesem Gerät gespeichert."
            }

            return "Deine Daten bleiben auf diesem Gerät gespeichert."
        }

        if controller.isCloudUnavailableForSyncDisableFlow {
            return "iCloud ist derzeit nicht verfügbar.\nDeine Daten bleiben auf diesem Gerät gespeichert.\nMöchtest du auch die Daten aus der Cloud entfernen?"
        }

        return "Deine Daten bleiben auf diesem Gerät gespeichert.\nMöchtest du auch die Daten aus der Cloud entfernen?"
    }

    private var statusColor: Color {
        if !controller.conflicts.isEmpty {
            return AppTheme.symiCoral
        }

        return switch controller.syncStatus.state {
        case .ready:
            AppTheme.symiSage
        case .syncing:
            SymiColors.noteAmber.color
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

#Preview {
    Text("Preview nicht verfügbar")
}
