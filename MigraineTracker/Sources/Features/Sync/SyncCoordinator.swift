import CloudKit
import Foundation
import Observation
import SwiftData
import SwiftUI

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
    private let deviceIdentityProvider: DeviceIdentityProviding
    private var provider: (any SyncProvider)?
    private let zoneID = SyncConfiguration.zoneID

    init(
        modelContainer: ModelContainer,
        appLogStore: AppLogStore,
        deviceIdentityProvider: DeviceIdentityProviding
    ) {
        self.modelContainer = modelContainer
        self.stateStore = SyncStateStore()
        self.appLogStore = appLogStore
        self.repository = LocalSyncRepository(modelContainer: modelContainer)
        self.deviceIdentityProvider = deviceIdentityProvider
        self.deviceID = deviceIdentityProvider.currentDeviceID()

        Task {
            await loadPersistedState()
        }
    }

    func loadPersistedState() async {
        isEnabled = await stateStore.syncEnabled()
        conflicts = await stateStore.conflicts()
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
        }
    }

    func setSyncEnabled(_ enabled: Bool) {
        Task {
            await stateStore.setSyncEnabled(enabled)
            isEnabled = enabled
            await log(level: .info, operation: "coordinator.setSyncEnabled", message: enabled ? "Sync wurde aktiviert." : "Sync wurde deaktiviert.")

            if enabled {
                await ensureStarted()
                await syncNow()
            } else {
                await provider?.stop()
                provider = nil
                status = await buildStatusSnapshot(baseState: .disabled, isSyncing: false)
            }
        }
    }

    func refreshStatus() {
        Task {
            status = await buildStatusSnapshot(baseState: currentBaseState(), isSyncing: false)
        }
    }

    func syncNow() async {
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
            try await provider.fetch()
            try await queueUnsyncedDocuments()
            try await provider.send()
            await stateStore.clearLastError()
            await log(level: .info, operation: "coordinator.syncNow.finish", message: "Sync-Lauf erfolgreich abgeschlossen.", metadata: [
                "conflicts": "\(await stateStore.conflicts().count)"
            ])
        } catch {
            await stateStore.setLastError(error.localizedDescription)
            await log(level: .error, operation: "coordinator.syncNow.error", message: "Sync-Lauf fehlgeschlagen.", metadata: [
                "error": error.localizedDescription
            ])
        }

        conflicts = await stateStore.conflicts()
        status = await buildStatusSnapshot(baseState: currentBaseState(), isSyncing: false)
    }

    func retryLastError() async {
        await log(level: .info, operation: "coordinator.retryLastError", message: "Fehlerhafter Sync-Lauf wird erneut versucht.")
        await syncNow()
    }

    func backupNow() async {
        await syncNow()
    }

    func resolveConflictKeepingLocal(_ conflict: SyncConflict) {
        Task {
            await stateStore.removeConflict(documentID: conflict.documentID)
            conflicts = await stateStore.conflicts()
            await log(level: .info, operation: "coordinator.resolveConflictKeepingLocal", message: "Lokale Version eines Konflikts wurde beibehalten.", metadata: [
                "documentID": conflict.documentID,
                "entityType": conflict.entityType.rawValue,
                "fields": conflict.conflictingFields.joined(separator: ",")
            ])
            status = await buildStatusSnapshot(baseState: currentBaseState(), isSyncing: false)
        }
    }

    func resolveConflictUsingRemote(_ conflict: SyncConflict) {
        Task {
            do {
                try repository.apply(remote: conflict.remote)
                await stateStore.saveShadow(SyncShadow(envelope: conflict.remote), for: conflict.documentID)
                await stateStore.removeConflict(documentID: conflict.documentID)
                conflicts = await stateStore.conflicts()
                await log(level: .info, operation: "coordinator.resolveConflictUsingRemote", message: "Cloud-Version eines Konflikts wurde übernommen.", metadata: [
                    "documentID": conflict.documentID,
                    "entityType": conflict.entityType.rawValue,
                    "fields": conflict.conflictingFields.joined(separator: ",")
                ])
                status = await buildStatusSnapshot(baseState: currentBaseState(), isSyncing: false)
            } catch {
                await stateStore.setLastError(error.localizedDescription)
                await log(level: .error, operation: "coordinator.resolveConflictUsingRemote.error", message: "Konflikt konnte nicht mit Cloud-Daten aufgelöst werden.", metadata: [
                    "documentID": conflict.documentID,
                    "error": error.localizedDescription
                ])
                status = await buildStatusSnapshot(baseState: .needsAttention, isSyncing: false)
            }
        }
    }

    private func ensureStarted() async {
        guard provider == nil else {
            return
        }

        let cloudProvider = CloudKitSyncProvider(
            stateStore: stateStore,
            zoneID: zoneID,
            appLogStore: appLogStore,
            recordProvider: { [weak self] recordID in
                await self?.recordForUpload(recordID: recordID)
            },
            eventHandler: { [weak self] event in
                await self?.handleProviderEvent(event)
            }
        )

        provider = cloudProvider

        do {
            try await cloudProvider.start()
            await log(level: .info, operation: "coordinator.ensureStarted", message: "Sync-Provider wurde initialisiert.")
        } catch {
            await stateStore.setLastError(error.localizedDescription)
            await log(level: .error, operation: "coordinator.ensureStarted.error", message: "Sync-Provider konnte nicht gestartet werden.", metadata: [
                "error": error.localizedDescription
            ])
        }
    }

    private func recordForUpload(recordID: CKRecord.ID) async -> CKRecord? {
        guard let envelope = try? repository.envelope(documentID: recordID.recordName, deviceID: deviceID) else {
            await log(level: .warning, operation: "coordinator.recordForUpload.missingEnvelope", message: "Kein lokales Dokument für Upload gefunden.", metadata: [
                "recordID": recordID.recordName
            ])
            return nil
        }

        let shadow = await stateStore.shadow(for: envelope.documentID)
        await log(level: .debug, operation: "coordinator.recordForUpload", message: "Lokales Dokument wird für Upload codiert.", metadata: metadata(for: envelope, shadow: shadow))
        return CloudKitRecordCodec.record(
            for: envelope,
            zoneID: zoneID,
            existingSystemFields: shadow?.recordSystemFields
        )
    }

    private func handleProviderEvent(_ event: SyncProviderEvent) async {
        switch event {
        case .didUpdateState(let serialization):
            await stateStore.saveEngineState(serialization)
            await log(level: .debug, operation: "coordinator.provider.didUpdateState", message: "Engine-Status wurde persistiert.")
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
            await log(level: .warning, operation: "coordinator.provider.didFailToSend", message: "Ein Teil des Uploads ist fehlgeschlagen.", metadata: [
                "count": "\(failures.count)"
            ])
            for failure in failures {
                await handleFailedSave(failure)
            }
        case .didEncounterError(let message):
            await stateStore.setLastError(message)
            await log(level: .error, operation: "coordinator.provider.didEncounterError", message: "Der Provider hat einen Fehler gemeldet.", metadata: [
                "error": message
            ])
        }

        status = await buildStatusSnapshot(baseState: currentBaseState(), isSyncing: false)
    }

    private func applyRemoteRecord(_ record: CKRecord) async {
        guard let remoteEnvelope = CloudKitRecordCodec.envelope(from: record) else {
            await log(level: .warning, operation: "coordinator.applyRemoteRecord.decodeFailed", message: "Remote-Record konnte nicht decodiert werden.", metadata: [
                "recordID": record.recordID.recordName
            ])
            return
        }

        let shadow = await stateStore.shadow(for: remoteEnvelope.documentID)
        let localEnvelope = try? repository.envelope(documentID: remoteEnvelope.documentID, deviceID: deviceID)

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

                try repository.apply(remote: merge.merged)
                await stateStore.saveShadow(
                    SyncShadow(envelope: remoteEnvelope, recordSystemFields: CloudKitRecordCodec.systemFields(for: record)),
                    for: remoteEnvelope.documentID
                )

                if merge.conflicts.isEmpty {
                    await stateStore.removeConflict(documentID: remoteEnvelope.documentID)
                    await log(level: .info, operation: "coordinator.applyRemoteRecord.merged", message: "Remote-Record wurde konfliktfrei gemergt.", metadata: metadata(for: remoteEnvelope, shadow: shadow))
                } else {
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
                    await log(level: .warning, operation: "coordinator.applyRemoteRecord.conflict", message: "Beim Mergen wurde ein Konflikt erkannt.", metadata: [
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
            await stateStore.setLastError(error.localizedDescription)
            await log(level: .error, operation: "coordinator.applyRemoteRecord.error", message: "Remote-Record konnte nicht angewendet werden.", metadata: [
                "documentID": remoteEnvelope.documentID,
                "error": error.localizedDescription
            ])
        }

        conflicts = await stateStore.conflicts()
    }

    private func handleRemoteDeletion(recordID: CKRecord.ID) async {
        guard let localEnvelope = try? repository.envelope(documentID: recordID.recordName, deviceID: deviceID) else {
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
            await stateStore.setLastError(error.localizedDescription)
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
            guard let serverRecord = failure.error.serverRecord else {
                await stateStore.setLastError(failure.error.localizedDescription)
                await log(level: .error, operation: "coordinator.handleFailedSave.serverRecordMissing", message: "Server-Record fehlt trotz Konfliktmeldung.", metadata: [
                    "recordID": failure.recordID.recordName
                ])
                return
            }

            await applyRemoteRecord(serverRecord)
        default:
            await stateStore.setLastError(failure.error.localizedDescription)
            await log(level: .error, operation: "coordinator.handleFailedSave.error", message: "Record konnte nicht gespeichert werden.", metadata: [
                "recordID": failure.recordID.recordName,
                "errorCode": "\(failure.error.code.rawValue)",
                "error": failure.error.localizedDescription
            ])
        }
    }

    private func queueUnsyncedDocuments() async throws {
        guard let provider else {
            await log(level: .warning, operation: "coordinator.queueUnsyncedDocuments.skip", message: "Keine Upload-Queue aufgebaut, da kein Provider aktiv ist.")
            return
        }

        let shadows = await stateStore.shadows()
        let conflicts = Set(await stateStore.conflicts().map(\.documentID))
        let envelopes = try repository.allEnvelopes(deviceID: deviceID)

        let pendingRecordNames = envelopes
            .filter { !conflicts.contains($0.documentID) }
            .filter { shadows[$0.documentID]?.envelope != $0 }
            .map(\.documentID)

        await log(level: .info, operation: "coordinator.queueUnsyncedDocuments", message: "Lokale Änderungen wurden für den Upload ausgewählt.", metadata: [
            "localEnvelopes": "\(envelopes.count)",
            "shadows": "\(shadows.count)",
            "conflicts": "\(conflicts.count)",
            "pendingRecords": "\(pendingRecordNames.count)",
            "recordNames": pendingRecordNames.sorted().joined(separator: ",")
        ])
        await provider.queue(recordNames: pendingRecordNames)
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
        let lastError = await stateStore.lastError()
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

        let localCount = (try? repository.allEnvelopes(deviceID: deviceID).count) ?? 0
        let unsyncedCount = max(localCount - shadows.count, 0) + conflictList.count

        return SyncStatusSnapshot(
            state: effectiveState,
            service: "iCloud",
            queuedUpdates: pendingRecordCount,
            unsyncedRecords: unsyncedCount,
            lastDownloadedAt: await stateStore.lastDownloadedAt(),
            lastUploadedAt: await stateStore.lastUploadedAt(),
            lastError: lastError
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
        }

        return values
    }
}

@MainActor
struct LocalSyncRepository {
    let modelContainer: ModelContainer

    func allEnvelopes(deviceID: String) throws -> [SyncDocumentEnvelope] {
        let context = ModelContext(modelContainer)
        let episodes = try context.fetch(FetchDescriptor<Episode>())
        let customDefinitions = try context.fetch(FetchDescriptor<MedicationDefinition>())
            .filter(\.isCustom)

        return episodes.map { $0.syncEnvelope(deviceID: deviceID) } +
            customDefinitions.map { $0.syncEnvelope(deviceID: deviceID) }
    }

    func envelope(documentID: String, deviceID: String) throws -> SyncDocumentEnvelope? {
        let envelopes = try allEnvelopes(deviceID: deviceID)
        return envelopes.first { $0.documentID == documentID }
    }

    func apply(remote envelope: SyncDocumentEnvelope) throws {
        let context = ModelContext(modelContainer)

        switch envelope.payload {
        case .episode(let payload):
            let episodeID = UUID(uuidString: payload.id) ?? UUID()
            let existing = try context.fetch(FetchDescriptor<Episode>()).first { $0.id == episodeID }
            let target = existing ?? Episode(
                id: episodeID,
                startedAt: payload.startedAt,
                endedAt: payload.endedAt,
                updatedAt: envelope.modifiedAt,
                deletedAt: envelope.deletedAt,
                type: EpisodeType(rawValue: payload.type) ?? .unclear,
                intensity: payload.intensity
            )

            target.startedAt = payload.startedAt
            target.endedAt = payload.endedAt
            target.updatedAt = envelope.modifiedAt
            target.deletedAt = envelope.deletedAt
            target.type = EpisodeType(rawValue: payload.type) ?? .unclear
            target.intensity = payload.intensity
            target.painLocation = payload.painLocation
            target.painCharacter = payload.painCharacter
            target.notes = payload.notes
            target.symptoms = payload.symptoms
            target.triggers = payload.triggers
            target.functionalImpact = payload.functionalImpact
            target.menstruationStatus = MenstruationStatus(rawValue: payload.menstruationStatus) ?? .unknown

            for medication in target.medications {
                context.delete(medication)
            }

            if let weatherSnapshot = target.weatherSnapshot {
                context.delete(weatherSnapshot)
                target.weatherSnapshot = nil
            }

            target.medications = payload.medications.map { medication in
                MedicationEntry(
                    id: UUID(uuidString: medication.id) ?? UUID(),
                    name: medication.name,
                    category: MedicationCategory(rawValue: medication.category) ?? .other,
                    dosage: medication.dosage,
                    quantity: medication.quantity,
                    takenAt: medication.takenAt,
                    effectiveness: MedicationEffectiveness(rawValue: medication.effectiveness) ?? .partial,
                    reliefStartedAt: medication.reliefStartedAt,
                    isRepeatDose: medication.isRepeatDose,
                    episode: target
                )
            }
            target.weatherSnapshot = payload.weatherSnapshot.map { weather in
                WeatherSnapshot(
                    id: UUID(uuidString: weather.id) ?? UUID(),
                    recordedAt: weather.recordedAt,
                    temperature: weather.temperature,
                    condition: weather.condition,
                    humidity: weather.humidity,
                    pressure: weather.pressure,
                    precipitation: weather.precipitation,
                    weatherCode: weather.weatherCode,
                    source: weather.source,
                    episode: target
                )
            }

            if existing == nil {
                context.insert(target)
            }
        case .medicationDefinition(let payload):
            let existing = try context.fetch(FetchDescriptor<MedicationDefinition>()).first { $0.catalogKey == payload.catalogKey }
            let target = existing ?? MedicationDefinition(
                catalogKey: payload.catalogKey,
                groupID: payload.groupID,
                groupTitle: payload.groupTitle,
                groupFooter: payload.groupFooter,
                name: payload.name,
                category: MedicationCategory(rawValue: payload.category) ?? .other,
                suggestedDosage: payload.suggestedDosage,
                sortOrder: payload.sortOrder,
                isCustom: payload.isCustom,
                createdAt: payload.createdAt,
                updatedAt: envelope.modifiedAt,
                deletedAt: envelope.deletedAt
            )

            target.groupID = payload.groupID
            target.groupTitle = payload.groupTitle
            target.groupFooter = payload.groupFooter
            target.name = payload.name
            target.category = MedicationCategory(rawValue: payload.category) ?? .other
            target.suggestedDosage = payload.suggestedDosage
            target.sortOrder = payload.sortOrder
            target.isCustom = payload.isCustom
            target.createdAt = payload.createdAt
            target.updatedAt = envelope.modifiedAt
            target.deletedAt = envelope.deletedAt

            if existing == nil {
                context.insert(target)
            }
        }

        try context.save()
    }
}

extension Episode {
    func syncEnvelope(deviceID: String) -> SyncDocumentEnvelope {
        SyncDocumentEnvelope(
            documentID: "episode:\(id.uuidString)",
            entityType: .episode,
            modifiedAt: updatedAt,
            authorDeviceID: deviceID,
            deletedAt: deletedAt,
            payload: .episode(
                SyncEpisodePayload(
                    id: id.uuidString,
                    startedAt: startedAt,
                    endedAt: endedAt,
                    type: type.rawValue,
                    intensity: intensity,
                    painLocation: painLocation,
                    painCharacter: painCharacter,
                    notes: notes,
                    symptoms: symptoms,
                    triggers: triggers,
                    functionalImpact: functionalImpact,
                    menstruationStatus: menstruationStatus.rawValue,
                    medications: medications.map {
                        SyncMedicationEntryPayload(
                            id: $0.id.uuidString,
                            name: $0.name,
                            category: $0.category.rawValue,
                            dosage: $0.dosage,
                            quantity: $0.quantity,
                            takenAt: $0.takenAt,
                            effectiveness: $0.effectiveness.rawValue,
                            reliefStartedAt: $0.reliefStartedAt,
                            isRepeatDose: $0.isRepeatDose
                        )
                    },
                    weatherSnapshot: weatherSnapshot.map {
                        SyncWeatherSnapshotPayload(
                            id: $0.id.uuidString,
                            recordedAt: $0.recordedAt,
                            temperature: $0.temperature,
                            condition: $0.condition,
                            humidity: $0.humidity,
                            pressure: $0.pressure,
                            precipitation: $0.precipitation,
                            weatherCode: $0.weatherCode,
                            source: $0.source
                        )
                    }
                )
            )
        )
    }
}

extension MedicationDefinition {
    func syncEnvelope(deviceID: String) -> SyncDocumentEnvelope {
        SyncDocumentEnvelope(
            documentID: "medicationDefinition:\(catalogKey)",
            entityType: .medicationDefinition,
            modifiedAt: updatedAt,
            authorDeviceID: deviceID,
            deletedAt: deletedAt,
            payload: .medicationDefinition(
                SyncMedicationDefinitionPayload(
                    catalogKey: catalogKey,
                    groupID: groupID,
                    groupTitle: groupTitle,
                    groupFooter: groupFooter,
                    name: name,
                    category: category.rawValue,
                    suggestedDosage: suggestedDosage,
                    sortOrder: sortOrder,
                    isCustom: isCustom,
                    createdAt: createdAt
                )
            )
        )
    }
}
