import SwiftUI

struct SyncView: View {
    let dependencies: SettingsFeatureDependencies
    @State private var controller: SettingsController
    @State private var showsDisableSyncConfirmation = false
    @State private var showsDeleteCloudDataConfirmation = false
    @State private var pendingSyncDisable = false

    init(dependencies: SettingsFeatureDependencies) {
        self.dependencies = dependencies
        _controller = State(initialValue: dependencies.makeSettingsController())
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Status", value: controller.isSyncEnabled ? "Aktiviert" : "Deaktiviert")
                LabeledContent("Letzte Synchronisation", value: formatted(lastSyncDate))
            } footer: {
                Text(controller.syncStatusDetail)
            }

            Section {
                Toggle("Synchronisation aktivieren", isOn: syncEnabledBinding)
                    .disabled(pendingSyncDisable || showsDisableSyncConfirmation || showsDeleteCloudDataConfirmation)

                Button {
                    Task {
                        await controller.syncNow()
                    }
                } label: {
                    Label("Jetzt synchronisieren", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(!controller.isSyncEnabled)
            }

            Section {
                NavigationLink {
                    ManageCloudDataView(dataExportDependencies: dependencies.dataExport, controller: controller)
                } label: {
                    Label("Cloud-Daten verwalten", systemImage: "icloud")
                }
            }
        }
        .navigationTitle("Synchronisation")
        .brandGroupedScreen()
        .task {
            controller.load()
            controller.refreshLog(limit: 1)
        }
        .refreshable {
            controller.load()
            controller.refreshLog(limit: 1)
        }
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

    private var syncEnabledBinding: Binding<Bool> {
        Binding(
            get: { controller.isSyncEnabled },
            set: { newValue in
                if newValue {
                    controller.setSyncEnabled(true)
                } else {
                    pendingSyncDisable = true
                    showsDisableSyncConfirmation = true
                }
            }
        )
    }

    private var lastSyncDate: Date? {
        [controller.syncStatus.lastUploadedAt, controller.syncStatus.lastDownloadedAt]
            .compactMap { $0 }
            .max()
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

    private func formatted(_ date: Date?) -> String {
        guard let date else {
            return "Noch keine Daten synchronisiert"
        }

        return date.formatted(date: .numeric, time: .shortened)
    }
}
