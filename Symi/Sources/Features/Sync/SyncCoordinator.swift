import CloudKit
import Foundation
import Network
import Observation
import SwiftData

typealias SyncProviderFactory = @MainActor @Sendable (
    SyncStateStore,
    CKRecordZone.ID,
    AppLogStore,
    @escaping @Sendable (CKRecord.ID) async -> CKRecord?,
    @escaping @Sendable (SyncProviderEvent) async -> Void
) -> any SyncProvider

@MainActor
@Observable
final class SyncCoordinator {
    private(set) var status = SyncStatusSnapshot()
    private(set) var conflicts: [SyncConflict] = []
    private(set) var isEnabled = false

    private let modelContainer: ModelContainer
    private let stateStore: SyncStateStore
    private let appLogStore: AppLogStore
    private let repository: LocalSyncRepository
    private let deviceID: String
    private let providerFactory: SyncProviderFactory
    private var provider: (any SyncProvider)?
    private let zoneID = SyncConfiguration.zoneID
    private var syncRunTask: Task<Void, Never>?
    private var automaticSyncTask: Task<Void, Never>?
    private var localChangeObserverTask: Task<Void, Never>?
    private var networkMonitor: NWPathMonitor?
    private var currentSyncRunHadError = false
    private var loggedAutomaticStatusResolutionKeys = Set<String>()
    private let networkMonitorQueue = DispatchQueue(label: "Symi.Sync.NetworkMonitor")

    init(
        modelContainer: ModelContainer,
        appLogStore: AppLogStore,
        healthContextStore: HealthContextStore = HealthContextStore(),
        stateStore: SyncStateStore = SyncStateStore(),
        deviceID: String? = nil,
        autostart: Bool = true,
        providerFactory: @escaping SyncProviderFactory = { stateStore, zoneID, appLogStore, recordProvider, eventHandler in
            CloudKitSyncProvider(
                stateStore: stateStore,
                zoneID: zoneID,
                appLogStore: appLogStore,
                recordProvider: recordProvider,
                eventHandler: eventHandler
            )
        }
    ) {
        self.modelContainer = modelContainer
        self.stateStore = stateStore
        self.appLogStore = appLogStore
        self.repository = LocalSyncRepository(modelContainer: modelContainer, healthContextStore: healthContextStore)
        self.deviceID = deviceID ?? Self.persistedDeviceID()
        self.providerFactory = providerFactory

        guard autostart else {
            return
        }

        startLocalChangeObserver()
        Task {
            await loadPersistedState()
        }
    }

    private static func persistedDeviceID() -> String {
        let key = "SyncCoordinator.deviceID"
        let defaults = UserDefaults.standard

        if let existingID = defaults.string(forKey: key), !existingID.isEmpty {
            return existingID
        }

        let newID = UUID().uuidString
        defaults.set(newID, forKey: key)
        return newID
    }

    func loadPersistedState() async {
        await PerformanceInstrumentation.measure("SyncLoadPersistedState") {
            isEnabled = await stateStore.syncEnabled()
            conflicts = await stateStore.conflicts()
            await logStateStoreEvents()
            await log(level: .info, operation: "coordinator.loadPersistedState", message: "Persistierter Sync-Status geladen.", metadata: [
                "enabled": "\(isEnabled)",
                "conflicts": "\(conflicts.count)"
            ])
            status = await buildStatusSnapshot(
                baseState: isEnabled ? .ready : .disabled,
                isSyncing: false
            )

            if isEnabled {
                await ensureStarted()
                startNetworkMonitorIfNeeded()
                triggerAutomaticSync(reason: "loadPersistedState")
            }
        }
    }

    func setSyncEnabled(_ enabled: Bool) {
        Task {
            await stateStore.setSyncEnabled(enabled)
            await logStateStoreEvents()
            isEnabled = enabled
            await log(level: .info, operation: "coordinator.setSyncEnabled", message: enabled ? "Sync wurde aktiviert." : "Sync wurde deaktiviert.")

            if enabled {
                await ensureStarted()
                startNetworkMonitorIfNeeded()
                await syncNow()
            } else {
                automaticSyncTask?.cancel()
                stopNetworkMonitor()
                status = await buildStatusSnapshot(baseState: .disabled, isSyncing: false)
            }
        }
    }

    func refreshStatus() {
        Task {
            let snapshot = await buildStatusSnapshot(baseState: currentBaseState(), isSyncing: false)
            status = snapshot
            await resolveActionableStatusIfNeeded(snapshot, reason: "refreshStatus")
        }
    }

    func syncNow() async {
        if let syncRunTask {
            await syncRunTask.value
            return
        }

        let task = Task { @MainActor in
            await performSyncNow()
        }
        syncRunTask = task
        await task.value
        syncRunTask = nil
    }

    func appDidBecomeActive() {
        triggerAutomaticSync(reason: "appDidBecomeActive", debounce: .seconds(0))
    }

    private func performSyncNow() async {
        await PerformanceInstrumentation.measure("SyncManualRun") {
            guard isEnabled else {
                await log(level: .warning, operation: "coordinator.syncNow.skip", message: "Sync wurde angefordert, ist aber deaktiviert.")
                status = await buildStatusSnapshot(baseState: .disabled, isSyncing: false)
                return
            }

            await ensureStarted()

            guard let provider else {
                await log(level: .error, operation: "coordinator.syncNow.missingProvider", message: "Sync konnte nicht starten, da kein Provider verfügbar ist.")
                status = await buildStatusSnapshot(baseState: .needsAttention, isSyncing: false)
                return
            }

            await log(level: .info, operation: "coordinator.syncNow.start", message: "Manueller Sync-Lauf gestartet.")
            status = await buildStatusSnapshot(baseState: .syncing, isSyncing: true)

            do {
                currentSyncRunHadError = false
                try await PerformanceInstrumentation.measure("SyncProviderFetch") {
                    try await provider.fetch()
                }
                try await queueUnsyncedDocuments()
                try await PerformanceInstrumentation.measure("SyncProviderSend") {
                    try await provider.send()
                }
                if !currentSyncRunHadError {
                    await stateStore.clearLastError()
                }
                await logStateStoreEvents()
                await log(level: .info, operation: "coordinator.syncNow.finish", message: "Sync-Lauf erfolgreich abgeschlossen.", metadata: [
                    "conflicts": "\(await stateStore.conflicts().count)"
                ])
            } catch {
                currentSyncRunHadError = true
                await stateStore.setLastError(error.localizedDescription, isRetryable: SyncErrorClassifier.isRetryable(error))
                await logStateStoreEvents()
                await log(level: .error, operation: "coordinator.syncNow.error", message: "Sync-Lauf fehlgeschlagen.", metadata: [
                    "error": error.localizedDescription
                ])
            }

            conflicts = await stateStore.conflicts()
            status = await buildStatusSnapshot(baseState: currentBaseState(), isSyncing: false)
        }
    }

    func retryLastError() async {
        await log(level: .info, operation: "coordinator.retryLastError", message: "Fehlerhafter Sync-Lauf wird erneut versucht.")
        await syncNow()
    }

    func backupNow() async {
        await syncNow()
    }

    func resolveConflictKeepingLocal(_ conflict: SyncConflict) async {
        await stateStore.removeConflict(documentID: conflict.documentID)
        conflicts = await stateStore.conflicts()
        await log(level: .info, operation: "coordinator.resolveConflictKeepingLocal", message: "Lokale Version eines Konflikts wurde beibehalten.", metadata: [
            "documentID": conflict.documentID,
            "entityType": conflict.entityType.rawValue,
            "fields": conflict.conflictingFields.joined(separator: ",")
        ])
        status = await buildStatusSnapshot(baseState: currentBaseState(), isSyncing: false)
    }

    func resolveConflictUsingRemote(_ conflict: SyncConflict) async {
        do {
            try repository.apply(remote: conflict.remote)
            let recordSystemFields = await stateStore.shadow(for: conflict.documentID)?.recordSystemFields
            await stateStore.saveShadow(
                SyncShadow(envelope: conflict.remote, recordSystemFields: recordSystemFields),
                for: conflict.documentID
            )
            await stateStore.removeConflict(documentID: conflict.documentID)
            conflicts = await stateStore.conflicts()
            await log(level: .info, operation: "coordinator.resolveConflictUsingRemote", message: "Cloud-Version eines Konflikts wurde übernommen.", metadata: [
                "documentID": conflict.documentID,
                "entityType": conflict.entityType.rawValue,
                "fields": conflict.conflictingFields.joined(separator: ",")
            ])
            status = await buildStatusSnapshot(baseState: currentBaseState(), isSyncing: false)
        } catch {
            await stateStore.setLastError(error.localizedDescription, isRetryable: SyncErrorClassifier.isRetryable(error))
            await log(level: .error, operation: "coordinator.resolveConflictUsingRemote.error", message: "Konflikt konnte nicht mit Cloud-Daten aufgelöst werden.", metadata: [
                "documentID": conflict.documentID,
                "error": error.localizedDescription
            ])
            status = await buildStatusSnapshot(baseState: .needsAttention, isSyncing: false)
        }
    }

    private func ensureStarted() async {
        await PerformanceInstrumentation.measure("SyncEnsureStarted") {
            guard provider == nil else {
                return
            }

            let cloudProvider = providerFactory(
                stateStore,
                zoneID,
                appLogStore,
                { [weak self] recordID in
                    await self?.recordForUpload(recordID: recordID)
                },
                { [weak self] event in
                    await self?.handleProviderEvent(event)
                }
            )

            provider = cloudProvider

            do {
                try await PerformanceInstrumentation.measure("SyncProviderStart") {
                    try await cloudProvider.start()
                }
                await log(level: .info, operation: "coordinator.ensureStarted", message: "Sync-Provider wurde initialisiert.")
            } catch {
                await stateStore.setLastError(error.localizedDescription, isRetryable: SyncErrorClassifier.isRetryable(error))
                await log(level: .error, operation: "coordinator.ensureStarted.error", message: "Sync-Provider konnte nicht gestartet werden.", metadata: [
                    "error": error.localizedDescription
                ])
            }
        }
    }

    private func recordForUpload(recordID: CKRecord.ID) async -> CKRecord? {
        let envelope: SyncDocumentEnvelope
        do {
            guard let fetchedEnvelope = try repository.envelope(documentID: recordID.recordName, deviceID: deviceID) else {
                await log(level: .warning, operation: "coordinator.recordForUpload.missingEnvelope", message: "Kein lokales Dokument für Upload gefunden.", metadata: [
                    "recordID": recordID.recordName
                ])
                return nil
            }
            envelope = fetchedEnvelope
        } catch {
            await stateStore.setLastError(error.localizedDescription, isRetryable: SyncErrorClassifier.isRetryable(error))
            await log(level: .error, operation: "coordinator.recordForUpload.error", message: "Lokales Dokument für Upload konnte nicht geladen werden.", metadata: [
                "recordID": recordID.recordName,
                "error": error.localizedDescription
            ])
            return nil
        }

        let shadow = await stateStore.shadow(for: envelope.documentID)
        await log(level: .debug, operation: "coordinator.recordForUpload", message: "Lokales Dokument wird für Upload codiert.", metadata: metadata(for: envelope, shadow: shadow))
        var systemFieldsFallbackReason: CloudKitRecordSystemFieldsFallbackReason?
        let record = CloudKitRecordCodec.record(
            for: envelope,
            zoneID: zoneID,
            existingSystemFields: shadow?.recordSystemFields,
            systemFieldsFallback: { reason in
                systemFieldsFallbackReason = reason
            }
        )

        if let systemFieldsFallbackReason {
            await log(level: .warning, operation: "coordinator.recordForUpload.systemFieldsFallback", message: "Gespeicherte CloudKit-Systemfelder konnten nicht genutzt werden; Upload wird mit frischem Record vorbereitet.", metadata: [
                "documentID": envelope.documentID,
                "entityType": envelope.entityType.rawValue,
                "recordID": recordID.recordName,
                "reason": systemFieldsFallbackReason.rawValue
            ])
        }

        return record
    }

    private func handleProviderEvent(_ event: SyncProviderEvent) async {
        switch event {
        case .didUpdateState(let serialization):
            await stateStore.saveEngineState(serialization)
            await log(level: .debug, operation: "coordinator.provider.didUpdateState", message: "Engine-Status wurde persistiert.")
        default:
            guard isEnabled else {
                await log(level: .debug, operation: "coordinator.provider.eventIgnored", message: "Provider-Ereignis wurde ignoriert, weil Cloud-Sync deaktiviert ist.")
                status = await buildStatusSnapshot(baseState: .disabled, isSyncing: false)
                return
            }

            await handleEnabledProviderEvent(event)
        }
    }

    private func handleEnabledProviderEvent(_ event: SyncProviderEvent) async {
        switch event {
        case .didUpdateState:
            return
        case .didFetchRecords(let records):
            await log(level: .info, operation: "coordinator.provider.didFetchRecords", message: "Remote-Records empfangen.", metadata: [
                "count": "\(records.count)"
            ])
            for record in records {
                await applyRemoteRecord(record)
            }
            await stateStore.setLastDownloadedAt(.now)
        case .didDeleteRecords(let recordIDs):
            await log(level: .info, operation: "coordinator.provider.didDeleteRecords", message: "Remote-Löschungen empfangen.", metadata: [
                "count": "\(recordIDs.count)",
                "recordIDs": recordIDs.map(\.recordName).sorted().joined(separator: ",")
            ])
            for recordID in recordIDs {
                await handleRemoteDeletion(recordID: recordID)
            }
            await stateStore.setLastDownloadedAt(.now)
        case .didSendRecords(let records):
            await log(level: .info, operation: "coordinator.provider.didSendRecords", message: "Lokale Änderungen wurden hochgeladen.", metadata: [
                "count": "\(records.count)"
            ])
            for record in records {
                if let envelope = CloudKitRecordCodec.envelope(from: record) {
                    let systemFields = CloudKitRecordCodec.systemFields(for: record)
                    await stateStore.saveShadow(
                        SyncShadow(envelope: envelope, recordSystemFields: systemFields),
                        for: envelope.documentID
                    )
                    await stateStore.removeConflict(documentID: envelope.documentID)
                }
            }
            conflicts = await stateStore.conflicts()
            await stateStore.setLastUploadedAt(.now)
        case .didFailToSend(let failures):
            currentSyncRunHadError = currentSyncRunHadError || failures.contains { !isRepairableServerRecordChange($0) }
            await log(level: .warning, operation: "coordinator.provider.didFailToSend", message: "Ein Teil des Uploads ist fehlgeschlagen.", metadata: [
                "count": "\(failures.count)"
            ])
            for failure in failures {
                await handleFailedSave(failure)
            }
        case .didEncounterError(let message):
            currentSyncRunHadError = true
            await stateStore.setLastError(message, isRetryable: SyncErrorClassifier.isRetryable(message: message))
            await log(level: .error, operation: "coordinator.provider.didEncounterError", message: "Der Provider hat einen Fehler gemeldet.", metadata: [
                "error": message
            ])
        case .didRecoverAccountAvailability:
            await log(level: .info, operation: "coordinator.provider.didRecoverAccountAvailability", message: "iCloud-Account ist verfügbar; automatischer Sync wird geplant.")
            triggerAutomaticSync(reason: "iCloudAccountAvailable", debounce: .seconds(0))
        }

        status = await buildStatusSnapshot(baseState: currentBaseState(), isSyncing: false)
    }

    func applyRemoteRecord(_ record: CKRecord) async {
        guard let remoteEnvelope = CloudKitRecordCodec.envelope(from: record) else {
            await log(level: .warning, operation: "coordinator.applyRemoteRecord.decodeFailed", message: "Remote-Record konnte nicht decodiert werden.", metadata: [
                "recordID": record.recordID.recordName
            ])
            return
        }

        let shadow = await stateStore.shadow(for: remoteEnvelope.documentID)
        let localEnvelope: SyncDocumentEnvelope?
        do {
            localEnvelope = try repository.envelope(documentID: remoteEnvelope.documentID, deviceID: deviceID)
        } catch {
            await stateStore.setLastError(error.localizedDescription, isRetryable: SyncErrorClassifier.isRetryable(error))
            await log(level: .error, operation: "coordinator.applyRemoteRecord.localEnvelopeError", message: "Lokaler Vergleichsstand konnte nicht geladen werden.", metadata: [
                "documentID": remoteEnvelope.documentID,
                "error": error.localizedDescription
            ])
            return
        }

        do {
            try repository.validate(remote: remoteEnvelope)
        } catch {
            await stateStore.setLastError(error.localizedDescription, isRetryable: SyncErrorClassifier.isRetryable(error))

            if let localEnvelope {
                await stateStore.saveConflict(
                    SyncConflict(
                        documentID: remoteEnvelope.documentID,
                        entityType: remoteEnvelope.entityType,
                        base: shadow?.envelope,
                        local: localEnvelope,
                        remote: remoteEnvelope,
                        conflictingFields: validationFields(from: error)
                    )
                )
            }

            await log(level: .error, operation: "coordinator.applyRemoteRecord.validationFailed", message: "Remote-Record wurde wegen ungültiger Payload abgelehnt.", metadata: [
                "documentID": remoteEnvelope.documentID,
                "recordID": record.recordID.recordName,
                "error": error.localizedDescription
            ])
            conflicts = await stateStore.conflicts()
            return
        }

        do {
            if let localEnvelope {
                if localEnvelope == remoteEnvelope {
                    await stateStore.saveShadow(
                        SyncShadow(envelope: remoteEnvelope, recordSystemFields: CloudKitRecordCodec.systemFields(for: record)),
                        for: remoteEnvelope.documentID
                    )
                    await log(level: .debug, operation: "coordinator.applyRemoteRecord.noChange", message: "Remote-Record entspricht bereits dem lokalen Stand.", metadata: metadata(for: remoteEnvelope, shadow: shadow))
                    return
                }

                let merge = SyncMergeEngine.merge(
                    base: shadow?.envelope,
                    local: localEnvelope,
                    remote: remoteEnvelope
                )

                if merge.conflicts.isEmpty {
                    try repository.apply(remote: merge.merged)
                    await stateStore.saveShadow(
                        SyncShadow(envelope: merge.merged, recordSystemFields: CloudKitRecordCodec.systemFields(for: record)),
                        for: remoteEnvelope.documentID
                    )
                    await stateStore.removeConflict(documentID: remoteEnvelope.documentID)
                    await log(level: .info, operation: "coordinator.applyRemoteRecord.merged", message: "Remote-Record wurde konfliktfrei gemergt.", metadata: metadata(for: merge.merged, shadow: shadow))
                } else if Self.hasSameUserVisibleContent(localEnvelope, remoteEnvelope) {
                    await stateStore.saveShadow(
                        SyncShadow(envelope: remoteEnvelope, recordSystemFields: CloudKitRecordCodec.systemFields(for: record)),
                        for: remoteEnvelope.documentID
                    )
                    await stateStore.removeConflict(documentID: remoteEnvelope.documentID)
                    await log(level: .info, operation: "coordinator.applyRemoteRecord.identicalContent", message: "Konflikt wurde automatisch gelöst, weil der sichtbare Inhalt identisch ist.", metadata: [
                        "documentID": remoteEnvelope.documentID,
                        "entityType": remoteEnvelope.entityType.rawValue
                    ])
                } else {
                    await stateStore.saveShadow(
                        SyncShadow(envelope: remoteEnvelope, recordSystemFields: CloudKitRecordCodec.systemFields(for: record)),
                        for: remoteEnvelope.documentID
                    )
                    await stateStore.saveConflict(
                        SyncConflict(
                            documentID: remoteEnvelope.documentID,
                            entityType: remoteEnvelope.entityType,
                            base: shadow?.envelope,
                            local: localEnvelope,
                            remote: remoteEnvelope,
                            conflictingFields: merge.conflicts
                        )
                    )
                    await log(level: .warning, operation: "coordinator.applyRemoteRecord.conflict", message: "Beim Mergen wurde ein Konflikt erkannt. Der lokale Stand bleibt bis zur Entscheidung unverändert.", metadata: [
                        "documentID": remoteEnvelope.documentID,
                        "entityType": remoteEnvelope.entityType.rawValue,
                        "fields": merge.conflicts.joined(separator: ",")
                    ])
                }
            } else {
                try repository.apply(remote: remoteEnvelope)
                await stateStore.saveShadow(
                    SyncShadow(envelope: remoteEnvelope, recordSystemFields: CloudKitRecordCodec.systemFields(for: record)),
                    for: remoteEnvelope.documentID
                )
                await log(level: .info, operation: "coordinator.applyRemoteRecord.insert", message: "Remote-Record wurde lokal neu angelegt.", metadata: metadata(for: remoteEnvelope, shadow: shadow))
            }
        } catch {
            await stateStore.setLastError(error.localizedDescription, isRetryable: SyncErrorClassifier.isRetryable(error))
            await log(level: .error, operation: "coordinator.applyRemoteRecord.error", message: "Remote-Record konnte nicht angewendet werden.", metadata: [
                "documentID": remoteEnvelope.documentID,
                "error": error.localizedDescription
            ])
        }

        conflicts = await stateStore.conflicts()
    }

    private func handleRemoteDeletion(recordID: CKRecord.ID) async {
        let localEnvelope: SyncDocumentEnvelope?
        do {
            localEnvelope = try repository.envelope(documentID: recordID.recordName, deviceID: deviceID)
        } catch {
            await stateStore.setLastError(error.localizedDescription, isRetryable: SyncErrorClassifier.isRetryable(error))
            await log(level: .error, operation: "coordinator.handleRemoteDeletion.loadError", message: "Lokaler Stand für Remote-Löschung konnte nicht geladen werden.", metadata: [
                "recordID": recordID.recordName,
                "error": error.localizedDescription
            ])
            return
        }

        guard let localEnvelope else {
            await log(level: .debug, operation: "coordinator.handleRemoteDeletion.skip", message: "Remote-Löschung ignoriert, da lokal kein Dokument existiert.", metadata: [
                "recordID": recordID.recordName
            ])
            return
        }

        let tombstone = SyncDocumentEnvelope(
            documentID: localEnvelope.documentID,
            entityType: localEnvelope.entityType,
            modifiedAt: .now,
            authorDeviceID: localEnvelope.authorDeviceID,
            deletedAt: .now,
            payload: localEnvelope.payload
        )

        do {
            try repository.apply(remote: tombstone)
            await stateStore.saveShadow(SyncShadow(envelope: tombstone), for: tombstone.documentID)
            await log(level: .info, operation: "coordinator.handleRemoteDeletion", message: "Remote-Löschung als Tombstone übernommen.", metadata: [
                "documentID": tombstone.documentID,
                "entityType": tombstone.entityType.rawValue
            ])
        } catch {
            await stateStore.setLastError(error.localizedDescription, isRetryable: SyncErrorClassifier.isRetryable(error))
            await log(level: .error, operation: "coordinator.handleRemoteDeletion.error", message: "Remote-Löschung konnte lokal nicht angewendet werden.", metadata: [
                "recordID": recordID.recordName,
                "error": error.localizedDescription
            ])
        }
    }

    private func handleFailedSave(_ failure: SyncFailedRecordSave) async {
        switch failure.error.code {
        case .serverRecordChanged:
            await log(level: .warning, operation: "coordinator.handleFailedSave.serverRecordChanged", message: "Server meldet geänderten Record. Remote-Stand wird neu angewendet.", metadata: [
                "recordID": failure.recordID.recordName,
                "errorCode": "\(failure.error.code.rawValue)"
            ])
            guard let serverRecord = failure.serverRecord ?? failure.error.serverRecord else {
                await stateStore.setLastError(failure.error.localizedDescription, isRetryable: SyncErrorClassifier.isRetryable(failure.error))
                await log(level: .error, operation: "coordinator.handleFailedSave.serverRecordMissing", message: "Server-Record fehlt trotz Konfliktmeldung.", metadata: [
                    "recordID": failure.recordID.recordName
                ])
                return
            }

            await applyRemoteRecord(serverRecord)
            triggerAutomaticSync(reason: "serverRecordChangedRepair", debounce: .seconds(0))
        default:
            let syncError = SyncErrorClassifier.classify(failure.error)
            await stateStore.setLastError(syncError.userMessage, isRetryable: syncError.isRetryable)
            await log(level: .error, operation: "coordinator.handleFailedSave.error", message: "Record konnte nicht gespeichert werden.", metadata: [
                "recordID": failure.recordID.recordName,
                "errorCode": "\(failure.error.code.rawValue)",
                "error": failure.error.localizedDescription,
                "isRetryable": "\(syncError.isRetryable)"
            ])
        }
    }

    private func isRepairableServerRecordChange(_ failure: SyncFailedRecordSave) -> Bool {
        failure.error.code == .serverRecordChanged
            && (failure.serverRecord != nil || failure.error.serverRecord != nil)
    }

    private func startLocalChangeObserver() {
        guard localChangeObserverTask == nil else {
            return
        }

        localChangeObserverTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .symiLocalSyncDataDidChange) {
                await MainActor.run {
                    self?.triggerAutomaticSync(reason: "localDataChanged")
                }
            }
        }
    }

    private func triggerAutomaticSync(reason: String, debounce: Duration = .seconds(1)) {
        guard isEnabled else {
            return
        }

        automaticSyncTask?.cancel()
        automaticSyncTask = Task { [weak self] in
            do {
                try await Task.sleep(for: debounce)
            } catch {
                return
            }

            await MainActor.run {
                self?.startAutomaticSyncRun(reason: reason)
            }
        }
    }

    private func startAutomaticSyncRun(reason: String) {
        Task { [weak self] in
            await self?.log(level: .info, operation: "coordinator.automaticSync", message: "Automatischer Sync-Lauf wird gestartet.", metadata: [
                "reason": reason
            ])
            await self?.syncNow()
        }
    }

    private func startNetworkMonitorIfNeeded() {
        guard networkMonitor == nil else {
            return
        }

        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else {
                return
            }

            Task { @MainActor [weak self] in
                self?.triggerAutomaticSync(reason: "networkAvailable", debounce: .seconds(0))
            }
        }
        monitor.start(queue: networkMonitorQueue)
        networkMonitor = monitor
    }

    private func stopNetworkMonitor() {
        networkMonitor?.cancel()
        networkMonitor = nil
    }

    private func resolveActionableStatusIfNeeded(_ snapshot: SyncStatusSnapshot, reason: String) async {
        guard isEnabled, snapshot.state != .syncing else {
            return
        }

        let openConflicts = await stateStore.conflicts().count
        let uploadableLocalChanges = max(0, snapshot.unsyncedRecords - openConflicts)
        var shouldSync = false

        if uploadableLocalChanges > 0 {
            await logAutomaticStatusResolution(
                key: "uploadableLocalChanges",
                operation: "coordinator.statusAutoResolution.uploadableLocalChanges",
                message: "Lokale Änderungen wurden automatisch für den nächsten iCloud-Abgleich vorgemerkt.",
                metadata: [
                    "reason": reason,
                    "count": "\(uploadableLocalChanges)"
                ]
            )
            shouldSync = true
        }

        if snapshot.lastDownloadedAt == nil {
            await logAutomaticStatusResolution(
                key: "missingInitialDownload",
                operation: "coordinator.statusAutoResolution.missingInitialDownload",
                message: "Fehlender iCloud-Download wird automatisch nachgeholt.",
                metadata: [
                    "reason": reason
                ]
            )
            shouldSync = true
        } else if let lastDownloadedAt = snapshot.lastDownloadedAt,
                  Date().timeIntervalSince(lastDownloadedAt) >= SyncStatusSnapshot.staleDataWarningInterval {
            await logAutomaticStatusResolution(
                key: "staleDownload",
                operation: "coordinator.statusAutoResolution.staleDownload",
                message: "Veralteter iCloud-Download wurde erkannt; ein automatischer Abgleich wird gestartet.",
                metadata: [
                    "reason": reason,
                    "lastDownloadedAt": lastDownloadedAt.ISO8601Format()
                ]
            )
            shouldSync = true
        }

        if snapshot.lastErrorIsRetryable {
            await logAutomaticStatusResolution(
                key: "retryableLastError",
                operation: "coordinator.statusAutoResolution.retryableLastError",
                message: "Ein vorübergehender Sync-Fehler wird automatisch erneut versucht.",
                metadata: [
                    "reason": reason
                ]
            )
            shouldSync = true
        }

        if shouldSync {
            triggerAutomaticSync(reason: "statusAutoResolution", debounce: .seconds(0))
        }
    }

    private func logAutomaticStatusResolution(
        key: String,
        operation: String,
        message: String,
        metadata: [String: String]
    ) async {
        guard !loggedAutomaticStatusResolutionKeys.contains(key) else {
            return
        }

        loggedAutomaticStatusResolutionKeys.insert(key)
        await log(level: .info, operation: operation, message: message, metadata: metadata)
    }

    private func queueUnsyncedDocuments() async throws {
        try await PerformanceInstrumentation.measure("SyncQueueUnsyncedDocuments") {
            guard let provider else {
                await log(level: .warning, operation: "coordinator.queueUnsyncedDocuments.skip", message: "Keine Upload-Queue aufgebaut, da kein Provider aktiv ist.")
                return
            }

            let shadows = await stateStore.shadows()
            let conflictList = await stateStore.conflicts()
            let conflicts = Set(conflictList.map(\.documentID))
            let envelopes = try PerformanceInstrumentation.measure("SyncRepositoryAllEnvelopes") {
                try repository.allEnvelopes(deviceID: deviceID)
            }

            let pendingRecordNames = SyncUploadPlanner.pendingRecordNames(
                envelopes: envelopes,
                shadows: shadows,
                conflicts: conflictList
            )

            await log(level: .info, operation: "coordinator.queueUnsyncedDocuments", message: "Lokale Änderungen wurden für den Upload ausgewählt.", metadata: [
                "localEnvelopes": "\(envelopes.count)",
                "shadows": "\(shadows.count)",
                "conflicts": "\(conflicts.count)",
                "pendingRecords": "\(pendingRecordNames.count)",
                "recordNames": pendingRecordNames.sorted().joined(separator: ",")
            ])
            await provider.queue(recordNames: pendingRecordNames)
        }
    }

    private func currentBaseState() -> SyncServiceState {
        if !isEnabled {
            return .disabled
        }

        if !conflicts.isEmpty {
            return .conflict
        }

        return .ready
    }

    private func buildStatusSnapshot(baseState: SyncServiceState, isSyncing: Bool) async -> SyncStatusSnapshot {
        let shadows = await stateStore.shadows()
        let conflictList = await stateStore.conflicts()
        var lastError = await stateStore.lastError()
        let lastErrorIsRetryable = await stateStore.lastErrorIsRetryable()
        let pendingRecordCount = await provider?.queuedChangeCount ?? 0
        let accountState = await provider?.accountAvailability ?? (isEnabled ? .needsAttention : .disabled)

        let effectiveState: SyncServiceState
        if !isEnabled {
            effectiveState = .disabled
        } else if accountState == .noICloudAccount {
            effectiveState = .noICloudAccount
        } else if isSyncing {
            effectiveState = .syncing
        } else if !conflictList.isEmpty {
            effectiveState = .conflict
        } else if let lastError, !lastError.isEmpty {
            effectiveState = lastError.localizedCaseInsensitiveContains("internet") ? .offline : .needsAttention
        } else {
            effectiveState = baseState
        }

        let localEnvelopes: [SyncDocumentEnvelope]
        do {
            localEnvelopes = try repository.allEnvelopes(deviceID: deviceID)
        } catch {
            lastError = error.localizedDescription
            await stateStore.setLastError(error.localizedDescription, isRetryable: SyncErrorClassifier.isRetryable(error))
            await log(level: .error, operation: "coordinator.buildStatusSnapshot.localEnvelopeError", message: "Lokale Sync-Dokumente konnten für den Status nicht geladen werden.", metadata: [
                "error": error.localizedDescription
            ])
            localEnvelopes = []
        }
        let pendingLocalCount = SyncUploadPlanner.pendingRecordNames(
            envelopes: localEnvelopes,
            shadows: shadows,
            conflicts: conflictList
        ).count
        let unsyncedCount = pendingLocalCount + conflictList.count

        return SyncStatusSnapshot(
            state: effectiveState,
            service: "iCloud",
            queuedUpdates: pendingRecordCount,
            unsyncedRecords: unsyncedCount,
            lastDownloadedAt: await stateStore.lastDownloadedAt(),
            lastUploadedAt: await stateStore.lastUploadedAt(),
            lastError: lastError,
            lastErrorIsRetryable: lastErrorIsRetryable
        )
    }

    private func log(
        level: AppLogLevel,
        operation: String,
        message: String,
        metadata: [String: String] = [:]
    ) async {
        await appLogStore.log(
            level: level,
            category: .sync,
            operation: operation,
            message: message,
            metadata: metadata
        )
    }

    private func logStateStoreEvents() async {
        let events = await stateStore.drainPersistenceEvents()
        for event in events {
            await log(
                level: event.level,
                operation: event.operation,
                message: event.message,
                metadata: event.metadata
            )
        }
    }

    private func metadata(for envelope: SyncDocumentEnvelope, shadow: SyncShadow?) -> [String: String] {
        var values: [String: String] = [
            "documentID": envelope.documentID,
            "entityType": envelope.entityType.rawValue,
            "modifiedAt": envelope.modifiedAt.ISO8601Format(),
            "hasShadow": "\(shadow != nil)"
        ]

        switch envelope.payload {
        case .episode(let payload):
            values["symptomCount"] = "\(payload.symptoms.count)"
            values["triggerCount"] = "\(payload.triggers.count)"
            values["medicationCount"] = "\(payload.medications.count)"
            values["hasNotes"] = "\(!payload.notes.isEmpty)"
            values["hasWeather"] = "\(payload.weatherSnapshot != nil)"
        case .medicationDefinition(let payload):
            values["isCustom"] = "\(payload.isCustom)"
            values["category"] = payload.category
            values["sortOrder"] = "\(payload.sortOrder)"
        case .continuousMedication(let payload):
            values["hasEndDate"] = "\(payload.endDate != nil)"
            values["hasDosage"] = "\(!payload.dosage.isEmpty)"
            values["hasFrequency"] = "\(!payload.frequency.isEmpty)"
        }

        return values
    }

    private func validationFields(from error: any Error) -> [String] {
        if let validationError = error as? RemoteSyncPayloadValidationError {
            return validationError.issues
        }

        return ["payloadValidation"]
    }

    private static func hasSameUserVisibleContent(
        _ local: SyncDocumentEnvelope,
        _ remote: SyncDocumentEnvelope
    ) -> Bool {
        local.entityType == remote.entityType
            && local.deletedAt == remote.deletedAt
            && local.payload == remote.payload
    }
}

struct ClassifiedSyncError {
    let userMessage: String
    let isRetryable: Bool
}

enum SyncErrorClassifier {
    static func classify(_ error: Error) -> ClassifiedSyncError {
        if let ckError = error as? CKError {
            return classify(ckError)
        }

        return ClassifiedSyncError(
            userMessage: error.localizedDescription,
            isRetryable: isRetryable(message: error.localizedDescription)
        )
    }

    static func classify(_ error: CKError) -> ClassifiedSyncError {
        let message = error.localizedDescription
        if isCloudKitSchemaConfigurationError(error) || isCloudKitSchemaConfigurationError(message: message) {
            return ClassifiedSyncError(
                userMessage: "Sync kann aktuell nicht abgeschlossen werden, weil die Cloud-Konfiguration nicht zur App-Version passt. Deine lokalen Daten bleiben erhalten. Details: \(message)",
                isRetryable: false
            )
        }

        return ClassifiedSyncError(
            userMessage: message,
            isRetryable: isRetryable(error)
        )
    }

    static func isRetryable(_ error: Error) -> Bool {
        classify(error).isRetryable
    }

    static func isRetryable(message: String) -> Bool {
        if isCloudKitSchemaConfigurationError(message: message) {
            return false
        }

        let lowercased = message.lowercased()
        return [
            "network",
            "internet",
            "offline",
            "timed out",
            "timeout",
            "temporarily",
            "service unavailable",
            "rate limit",
            "try again",
            "erneut",
            "nicht erreichbar"
        ].contains { lowercased.contains($0) }
    }

    private static func isRetryable(_ error: CKError) -> Bool {
        if isCloudKitSchemaConfigurationError(error) || isCloudKitSchemaConfigurationError(message: error.localizedDescription) {
            return false
        }

        switch error.code {
        case .networkUnavailable,
             .networkFailure,
             .serviceUnavailable,
             .requestRateLimited,
             .zoneBusy,
             .resultsTruncated,
             .operationCancelled,
             .notAuthenticated:
            return true
        default:
            return false
        }
    }

    private static func isCloudKitSchemaConfigurationError(_ error: CKError) -> Bool {
        switch error.code {
        case .serverRejectedRequest,
             .invalidArguments,
             .zoneNotFound,
             .unknownItem:
            return true
        default:
            return false
        }
    }

    private static func isCloudKitSchemaConfigurationError(message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("cannot create new type")
            || lowercased.contains("production schema")
            || lowercased.contains("record type")
            || lowercased.contains("field")
            || lowercased.contains("schema")
    }
}
