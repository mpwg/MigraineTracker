import CloudKit
import Foundation
import SwiftData
import SwiftUI
import UIKit

@MainActor
final class SyncCoordinator: ObservableObject {
    @Published private(set) var status = SyncStatusSnapshot()
    @Published private(set) var conflicts: [SyncConflict] = []
    @Published private(set) var isEnabled = false

    private let modelContainer: ModelContainer
    private let stateStore: SyncStateStore
    private let repository: LocalSyncRepository
    private let deviceID: String
    private var provider: (any SyncProvider)?
    private let zoneID = SyncConfiguration.zoneID

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.stateStore = SyncStateStore()
        self.repository = LocalSyncRepository(modelContainer: modelContainer)
        self.deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString

        Task {
            await loadPersistedState()
        }
    }

    func loadPersistedState() async {
        isEnabled = await stateStore.syncEnabled()
        conflicts = await stateStore.conflicts()
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
            status = await buildStatusSnapshot(baseState: .disabled, isSyncing: false)
            return
        }

        await ensureStarted()

        guard let provider else {
            status = await buildStatusSnapshot(baseState: .needsAttention, isSyncing: false)
            return
        }

        status = await buildStatusSnapshot(baseState: .syncing, isSyncing: true)

        do {
            try await provider.fetch()
            try await queueUnsyncedDocuments()
            try await provider.send()
            await stateStore.clearLastError()
        } catch {
            await stateStore.setLastError(error.localizedDescription)
        }

        conflicts = await stateStore.conflicts()
        status = await buildStatusSnapshot(baseState: currentBaseState(), isSyncing: false)
    }

    func retryLastError() async {
        await syncNow()
    }

    func backupNow() async {
        await syncNow()
    }

    func resolveConflictKeepingLocal(_ conflict: SyncConflict) {
        Task {
            await stateStore.removeConflict(documentID: conflict.documentID)
            conflicts = await stateStore.conflicts()
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
                status = await buildStatusSnapshot(baseState: currentBaseState(), isSyncing: false)
            } catch {
                await stateStore.setLastError(error.localizedDescription)
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
        } catch {
            await stateStore.setLastError(error.localizedDescription)
        }
    }

    private func recordForUpload(recordID: CKRecord.ID) async -> CKRecord? {
        guard let envelope = try? repository.envelope(documentID: recordID.recordName, deviceID: deviceID) else {
            return nil
        }

        let shadow = await stateStore.shadow(for: envelope.documentID)
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
        case .didFetchRecords(let records):
            for record in records {
                await applyRemoteRecord(record)
            }
            await stateStore.setLastDownloadedAt(.now)
        case .didDeleteRecords(let recordIDs):
            for recordID in recordIDs {
                await handleRemoteDeletion(recordID: recordID)
            }
            await stateStore.setLastDownloadedAt(.now)
        case .didSendRecords(let records):
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
            for failure in failures {
                await handleFailedSave(failure)
            }
        case .didEncounterError(let message):
            await stateStore.setLastError(message)
        }

        status = await buildStatusSnapshot(baseState: currentBaseState(), isSyncing: false)
    }

    private func applyRemoteRecord(_ record: CKRecord) async {
        guard let remoteEnvelope = CloudKitRecordCodec.envelope(from: record) else {
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
                }
            } else {
                try repository.apply(remote: remoteEnvelope)
                await stateStore.saveShadow(
                    SyncShadow(envelope: remoteEnvelope, recordSystemFields: CloudKitRecordCodec.systemFields(for: record)),
                    for: remoteEnvelope.documentID
                )
            }
        } catch {
            await stateStore.setLastError(error.localizedDescription)
        }

        conflicts = await stateStore.conflicts()
    }

    private func handleRemoteDeletion(recordID: CKRecord.ID) async {
        guard let localEnvelope = try? repository.envelope(documentID: recordID.recordName, deviceID: deviceID) else {
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
        } catch {
            await stateStore.setLastError(error.localizedDescription)
        }
    }

    private func handleFailedSave(_ failure: SyncFailedRecordSave) async {
        switch failure.error.code {
        case .serverRecordChanged:
            guard let serverRecord = failure.error.serverRecord else {
                await stateStore.setLastError(failure.error.localizedDescription)
                return
            }

            await applyRemoteRecord(serverRecord)
        default:
            await stateStore.setLastError(failure.error.localizedDescription)
        }
    }

    private func queueUnsyncedDocuments() async throws {
        guard let provider else {
            return
        }

        let shadows = await stateStore.shadows()
        let conflicts = Set(await stateStore.conflicts().map(\.documentID))
        let envelopes = try repository.allEnvelopes(deviceID: deviceID)

        let pendingRecordNames = envelopes
            .filter { !conflicts.contains($0.documentID) }
            .filter { shadows[$0.documentID]?.envelope != $0 }
            .map(\.documentID)

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
