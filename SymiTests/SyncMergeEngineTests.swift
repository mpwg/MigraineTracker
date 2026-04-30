import CloudKit
import Foundation
import SwiftData
import Testing
@testable import Symi

struct SyncMergeEngineTests {
    @Test
    func syncStatusDoesNotWarnWhenLastDownloadIsStale() {
        let now = Date(timeIntervalSince1970: 200_000)
        let status = SyncStatusSnapshot(
            state: .ready,
            unsyncedRecords: 0,
            lastDownloadedAt: now.addingTimeInterval(-SyncStatusSnapshot.staleDataWarningInterval - 60),
            lastUploadedAt: now.addingTimeInterval(-300)
        )

        let warning = status.staleDataWarning(now: now, isSyncEnabled: true, openConflictCount: 0)

        #expect(warning == nil)
    }

    @Test
    func syncStatusOnlyWarnsForConflictsThatNeedDecision() {
        let status = SyncStatusSnapshot(
            state: .conflict,
            unsyncedRecords: 3,
            lastDownloadedAt: Date(timeIntervalSince1970: 1_000)
        )

        let conflictWarning = status.staleDataWarning(
            now: Date(timeIntervalSince1970: 2_000),
            isSyncEnabled: true,
            openConflictCount: 2
        )
        let unsyncedWarning = status.staleDataWarning(
            now: Date(timeIntervalSince1970: 2_000),
            isSyncEnabled: true,
            openConflictCount: 0
        )

        #expect(conflictWarning?.contains("2 Sync-Konflikte") == true)
        #expect(unsyncedWarning == nil)
    }

    @Test
    func syncStatusDoesNotWarnWhenDisabledOrFresh() {
        let now = Date(timeIntervalSince1970: 10_000)
        let status = SyncStatusSnapshot(
            state: .ready,
            unsyncedRecords: 0,
            lastDownloadedAt: now.addingTimeInterval(-300),
            lastUploadedAt: now.addingTimeInterval(-120)
        )

        #expect(status.staleDataWarning(now: now, isSyncEnabled: false, openConflictCount: 0) == nil)
        #expect(status.staleDataWarning(now: now, isSyncEnabled: true, openConflictCount: 0) == nil)
    }

    @Test
    func corruptSyncStateFileStartsWithCleanStateAndCanPersistAgain() async throws {
        let baseDirectory = try makeTemporaryDirectory()
        let syncDirectory = baseDirectory.appendingPathComponent("Symi", isDirectory: true)
        try FileManager.default.createDirectory(at: syncDirectory, withIntermediateDirectories: true)
        let syncStateURL = syncDirectory.appendingPathComponent("sync-state.json")
        try Data("{ keine gültige Sync-State-Datei".utf8).write(to: syncStateURL)

        let stateStore = SyncStateStore(baseDirectoryURL: baseDirectory)

        #expect(await stateStore.syncEnabled() == false)
        #expect(await stateStore.lastError() != nil)

        let events = await stateStore.drainPersistenceEvents()
        #expect(events.first?.operation == "stateStore.load.error")
        #expect(events.first?.level == .error)

        let backupURLs = try FileManager.default.contentsOfDirectory(
            at: syncDirectory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.lastPathComponent.hasPrefix("sync-state.schema-1.corrupt-") }
        #expect(backupURLs.count == 1)
        #expect(try Data(contentsOf: backupURLs[0]) == Data("{ keine gültige Sync-State-Datei".utf8))

        await stateStore.setSyncEnabled(true)
        let persistedData = try Data(contentsOf: syncStateURL)
        let persistedObject = try #require(
            JSONSerialization.jsonObject(with: persistedData) as? [String: Any]
        )
        #expect(persistedObject["schemaVersion"] as? Int == 1)
        #expect(persistedObject["syncEnabled"] as? Bool == true)
    }

    @Test
    func partialSyncStateFileIsBackedUpAndReported() async throws {
        let baseDirectory = try makeTemporaryDirectory()
        let syncDirectory = baseDirectory.appendingPathComponent("Symi", isDirectory: true)
        try FileManager.default.createDirectory(at: syncDirectory, withIntermediateDirectories: true)
        let syncStateURL = syncDirectory.appendingPathComponent("sync-state.json")
        try Data("{\"schemaVersion\":1,\"syncEnabled\":true,\"shadows\":".utf8).write(to: syncStateURL)

        let stateStore = SyncStateStore(baseDirectoryURL: baseDirectory)

        #expect(await stateStore.syncEnabled() == false)
        #expect(await stateStore.lastError()?.contains("zurückgesetzt") == true)

        let backupURLs = try FileManager.default.contentsOfDirectory(
            at: syncDirectory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.lastPathComponent.hasPrefix("sync-state.schema-1.corrupt-") }
        #expect(backupURLs.count == 1)
    }

    @Test
    func syncStateWriteFailureIsReportedInStatusAndLogEvents() async throws {
        let baseDirectory = try makeTemporaryDirectory()
        let syncDirectory = baseDirectory.appendingPathComponent("Symi", isDirectory: true)
        let syncStateURL = syncDirectory.appendingPathComponent("sync-state.json")
        try FileManager.default.createDirectory(at: syncStateURL, withIntermediateDirectories: true)
        let stateStore = SyncStateStore(baseDirectoryURL: baseDirectory)

        await stateStore.setSyncEnabled(true)

        let lastError = try #require(await stateStore.lastError())
        #expect(lastError.contains("konnte nicht geschrieben werden"))

        let events = await stateStore.drainPersistenceEvents()
        let writeError = try #require(events.first { $0.operation == "stateStore.persist.error" })
        #expect(writeError.level == .error)
        #expect(writeError.metadata["path"] == syncStateURL.path)
    }

    @Test
    @MainActor
    func corruptRecordSystemFieldsPrepareFreshRecordWithoutCrashing() throws {
        let envelope = definitionEnvelope(name: "Sumatriptan", deletedAt: nil)
        let corruptSystemFields = Data("keine gültigen Systemfelder".utf8)
        var fallbackReason: CloudKitRecordSystemFieldsFallbackReason?

        let record = try #require(
            CloudKitRecordCodec.record(
                for: envelope,
                zoneID: syncTestZoneID,
                existingSystemFields: corruptSystemFields,
                systemFieldsFallback: { reason in
                    fallbackReason = reason
                }
            )
        )

        #expect(record.recordID.recordName == envelope.documentID)
        #expect(fallbackReason == .undecodableArchive)
        #expect(CloudKitRecordCodec.envelope(from: record) == envelope)
    }

    @Test
    @MainActor
    func cloudKitRecordCodecEnforcesPayloadByteBudget() throws {
        let acceptedEnvelope = episodeEnvelopeNearCloudKitPayloadBudget()
        let acceptedByteCount = try #require(CloudKitRecordCodec.payloadByteCount(for: acceptedEnvelope))

        #expect(acceptedByteCount <= SyncPayloadSchema.maximumCloudKitPayloadBytes)
        #expect(try record(from: acceptedEnvelope).recordID.recordName == acceptedEnvelope.documentID)

        let oversizedEnvelope = oversizedEpisodeEnvelope()
        let oversizedByteCount = try #require(CloudKitRecordCodec.payloadByteCount(for: oversizedEnvelope))

        #expect(oversizedByteCount > SyncPayloadSchema.maximumCloudKitPayloadBytes)
        #expect(
            CloudKitRecordCodec.record(
                for: oversizedEnvelope,
                zoneID: syncTestZoneID,
                existingSystemFields: nil
            ) == nil
        )
    }

    @Test
    func cloudKitProviderStateSerializesConcurrentQueueAccess() async {
        let state = CloudKitSyncProviderState()
        let recordNames = (0..<80).map { "record-\($0)" }

        await withTaskGroup(of: Void.self) { group in
            for recordName in recordNames {
                group.addTask {
                    _ = await state.queue(recordNames: [recordName], zoneID: syncTestZoneID)
                }
            }
        }

        #expect(await state.queuedChangeCount == recordNames.count)
    }

    @Test
    func cloudKitProviderStateRemovesSentRecordsAcrossConcurrentCallbacks() async {
        let state = CloudKitSyncProviderState()
        let recordNames = (0..<60).map { "record-\($0)" }
        _ = await state.queue(recordNames: recordNames, zoneID: syncTestZoneID)

        await withTaskGroup(of: Void.self) { group in
            for chunk in recordNames.chunked(into: 5) {
                group.addTask {
                    await state.removeSentRecordNames(chunk)
                }
            }
        }

        #expect(await state.queuedChangeCount == 0)
    }

    @Test
    @MainActor
    func cloudKitRecordCodecRejectsEnvelopeMetadataMismatch() throws {
        let envelope = definitionEnvelope(name: "Sumatriptan", deletedAt: nil)
        let record = try record(from: envelope)

        record["schemaVersion"] = NSNumber(value: envelope.schemaVersion + 1)

        #expect(CloudKitRecordCodec.envelope(from: record) == nil)
    }

    @Test
    @MainActor
    func syncPayloadFuzzCasesRoundTripWithinCloudKitBudget() throws {
        for seed in 0..<32 {
            let envelope = fuzzedEpisodeEnvelope(seed: seed)
            let byteCount = try #require(CloudKitRecordCodec.payloadByteCount(for: envelope))
            let record = try record(from: envelope)

            #expect(byteCount <= SyncPayloadSchema.maximumCloudKitPayloadBytes)
            #expect(CloudKitRecordCodec.envelope(from: record) == envelope)
        }
    }

    @Test
    @MainActor
    func remoteValidatorRejectsUnsupportedSchemaVersionAndPayloadTypeMismatch() throws {
        var unsupportedVersion = definitionEnvelope(name: "Sumatriptan", deletedAt: nil)
        unsupportedVersion.schemaVersion = SyncPayloadSchema.currentVersion(for: unsupportedVersion.entityType) + 1

        #expect(throws: RemoteSyncPayloadValidationError.self) {
            try RemoteSyncPayloadValidator.validate(unsupportedVersion)
        }

        let mismatchedEnvelope = SyncDocumentEnvelope(
            documentID: unsupportedVersion.documentID,
            entityType: .episode,
            modifiedAt: unsupportedVersion.modifiedAt,
            authorDeviceID: unsupportedVersion.authorDeviceID,
            payload: unsupportedVersion.payload
        )

        #expect(throws: RemoteSyncPayloadValidationError.self) {
            try RemoteSyncPayloadValidator.validate(mismatchedEnvelope)
        }
    }

    @Test
    @MainActor
    func conflictFreeRemoteMergeStoresShadowForMergedState() async throws {
        let stack = try makeSyncTestStack()
        let documentID = try insertBaseEpisode(in: stack.container)
        let baseEnvelope = try requireEnvelope(from: stack.repository, documentID: documentID)
        await stack.stateStore.saveShadow(SyncShadow(envelope: baseEnvelope), for: documentID)

        try updateEpisode(documentID: documentID, in: stack.container) { episode in
            episode.notes = "lokal"
            episode.updatedAt = Date(timeIntervalSince1970: 2_000)
        }
        let localEnvelope = try requireEnvelope(from: stack.repository, documentID: documentID)
        let remoteEnvelope = episodeEnvelope(from: baseEnvelope, modifiedAt: Date(timeIntervalSince1970: 3_000)) { payload in
            payload.symptoms = ["Aura", "Übelkeit"]
        }
        let expectedMerge = SyncMergeEngine.merge(base: baseEnvelope, local: localEnvelope, remote: remoteEnvelope)

        await stack.coordinator.applyRemoteRecord(try record(from: remoteEnvelope))

        let storedEnvelope = try requireEnvelope(from: stack.repository, documentID: documentID)
        let storedShadow = await stack.stateStore.shadow(for: documentID)
        let conflicts = await stack.stateStore.conflicts()

        #expect(expectedMerge.conflicts.isEmpty)
        #expect(storedEnvelope == expectedMerge.merged)
        #expect(storedShadow?.envelope == expectedMerge.merged)
        #expect(conflicts.isEmpty)
    }

    @Test
    @MainActor
    func localSyncRepositoryIncludesContinuousMedicationChecksAndHealthContext() throws {
        let stack = try makeSyncTestStack()
        let context = ModelContext(stack.container)
        let episodeID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let medicationID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-000000000001")!
        let checkID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-000000000002")!
        let episode = Episode(
            id: episodeID,
            startedAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 2_000),
            type: .migraine,
            intensity: 7,
            notes: "mit Kontext",
            continuousMedicationChecks: [
                ContinuousMedicationCheck(
                    id: checkID,
                    continuousMedicationID: medicationID,
                    name: "Metoprolol",
                    dosage: "47,5 mg",
                    frequency: "morgens",
                    wasTaken: false
                )
            ]
        )
        let continuousMedication = ContinuousMedication(
            id: medicationID,
            name: "Metoprolol",
            dosage: "47,5 mg",
            frequency: "morgens",
            startDate: Date(timeIntervalSince1970: 500),
            updatedAt: Date(timeIntervalSince1970: 1_500)
        )
        context.insert(episode)
        context.insert(continuousMedication)
        try context.save()
        try stack.healthContextStore.save(sampleHealthContext(), for: episodeID)

        let envelopes = try stack.repository.allEnvelopes(deviceID: syncTestDeviceID)
        let episodePayload = try #require(envelopes.first { $0.documentID == "episode:\(episodeID.uuidString)" }?.payload.episodePayload)
        let continuousMedicationPayload = try #require(
            envelopes.first { $0.documentID == "continuousMedication:\(medicationID.uuidString)" }?.payload.continuousMedicationPayload
        )

        #expect(episodePayload.continuousMedicationChecks.first?.id == checkID.uuidString)
        #expect(episodePayload.healthContext?.stepCount == 4_200)
        #expect(continuousMedicationPayload.name == "Metoprolol")
    }

    @Test
    @MainActor
    func remoteEpisodeSyncAppliesContinuousMedicationChecksAndHealthContext() throws {
        let stack = try makeSyncTestStack()
        let episodeID = UUID(uuidString: "22222222-3333-4444-5555-666666666666")!
        let checkID = UUID(uuidString: "BBBBBBBB-CCCC-DDDD-EEEE-000000000001")!
        let medicationID = UUID(uuidString: "BBBBBBBB-CCCC-DDDD-EEEE-000000000002")!
        let remoteEnvelope = SyncDocumentEnvelope(
            documentID: "episode:\(episodeID.uuidString)",
            entityType: .episode,
            modifiedAt: Date(timeIntervalSince1970: 2_000),
            authorDeviceID: "device-remote",
            payload: .episode(
                SyncEpisodePayload(
                    id: episodeID.uuidString,
                    startedAt: Date(timeIntervalSince1970: 1_000),
                    endedAt: nil,
                    type: "Migräne",
                    intensity: 6,
                    painLocation: "",
                    painCharacter: "",
                    notes: "remote",
                    symptoms: [],
                    triggers: [],
                    functionalImpact: "",
                    menstruationStatus: "Nicht angegeben",
                    medications: [],
                    continuousMedicationChecks: [
                        SyncContinuousMedicationCheckPayload(
                            id: checkID.uuidString,
                            continuousMedicationID: medicationID.uuidString,
                            name: "Magnesium",
                            dosage: "300 mg",
                            frequency: "abends",
                            wasTaken: true
                        )
                    ],
                    weatherSnapshot: nil,
                    healthContext: sampleHealthContext()
                )
            )
        )

        try stack.repository.apply(remote: remoteEnvelope)

        let context = ModelContext(stack.container)
        let episode = try #require(try context.fetch(FetchDescriptor<Episode>()).first { $0.id == episodeID })
        let healthContext = stack.healthContextStore.load(for: episodeID)

        #expect(episode.typeRaw == "migraine")
        #expect(episode.menstruationStatusRaw == "unknown")
        #expect(episode.continuousMedicationChecks.first?.name == "Magnesium")
        #expect(healthContext?.stepCount == 4_200)
    }

    @Test
    @MainActor
    func invalidRemoteEpisodeIDIsRejectedWithoutCreatingLocalEpisode() async throws {
        let stack = try makeSyncTestStack()
        let remoteEnvelope = SyncDocumentEnvelope(
            documentID: "episode:defekt",
            entityType: .episode,
            modifiedAt: Date(timeIntervalSince1970: 2_000),
            authorDeviceID: "device-remote",
            payload: .episode(
                SyncEpisodePayload(
                    id: "defekt",
                    startedAt: Date(timeIntervalSince1970: 1_000),
                    endedAt: nil,
                    type: EpisodeType.migraine.rawValue,
                    intensity: 6,
                    painLocation: "",
                    painCharacter: "",
                    notes: "remote",
                    symptoms: [],
                    triggers: [],
                    functionalImpact: "",
                    menstruationStatus: MenstruationStatus.unknown.rawValue,
                    medications: [],
                    weatherSnapshot: nil
                )
            )
        )

        await stack.coordinator.applyRemoteRecord(try record(from: remoteEnvelope))

        let context = ModelContext(stack.container)
        let episodes = try context.fetch(FetchDescriptor<Episode>())
        let conflicts = await stack.stateStore.conflicts()
        let lastError = await stack.stateStore.lastError()

        #expect(episodes.isEmpty)
        #expect(conflicts.isEmpty)
        #expect(lastError?.contains("episode.id ist keine gültige UUID") == true)
    }

    @Test
    @MainActor
    func invalidRemoteEnumValueCreatesConflictForExistingLocalDocument() async throws {
        let stack = try makeSyncTestStack()
        let documentID = try insertBaseEpisode(in: stack.container)
        let baseEnvelope = try requireEnvelope(from: stack.repository, documentID: documentID)
        await stack.stateStore.saveShadow(SyncShadow(envelope: baseEnvelope), for: documentID)
        let remoteEnvelope = episodeEnvelope(from: baseEnvelope, modifiedAt: Date(timeIntervalSince1970: 3_000)) { payload in
            payload.type = "cluster"
        }

        await stack.coordinator.applyRemoteRecord(try record(from: remoteEnvelope))

        let storedEnvelope = try requireEnvelope(from: stack.repository, documentID: documentID)
        let conflict = try #require(await stack.stateStore.conflicts().first)
        let lastError = await stack.stateStore.lastError()

        #expect(storedEnvelope == baseEnvelope)
        #expect(conflict.remote == remoteEnvelope)
        #expect(conflict.conflictingFields == ["episode.type enthält einen unbekannten Wert"])
        #expect(lastError?.contains("episode.type enthält einen unbekannten Wert") == true)
    }

    @Test
    @MainActor
    func conflictRemoteMergeLeavesLocalStateUntouchedUntilResolution() async throws {
        let stack = try makeSyncTestStack()
        let documentID = try insertBaseEpisode(in: stack.container)
        let baseEnvelope = try requireEnvelope(from: stack.repository, documentID: documentID)
        await stack.stateStore.saveShadow(SyncShadow(envelope: baseEnvelope), for: documentID)

        try updateEpisode(documentID: documentID, in: stack.container) { episode in
            episode.notes = "lokal"
            episode.updatedAt = Date(timeIntervalSince1970: 2_000)
        }
        let localEnvelope = try requireEnvelope(from: stack.repository, documentID: documentID)
        let remoteEnvelope = episodeEnvelope(from: baseEnvelope, modifiedAt: Date(timeIntervalSince1970: 3_000)) { payload in
            payload.notes = "remote"
        }

        await stack.coordinator.applyRemoteRecord(try record(from: remoteEnvelope))

        let storedEnvelope = try requireEnvelope(from: stack.repository, documentID: documentID)
        let storedShadow = await stack.stateStore.shadow(for: documentID)
        let conflicts = await stack.stateStore.conflicts()
        let conflict = try #require(conflicts.first)

        #expect(storedEnvelope == localEnvelope)
        #expect(storedShadow?.envelope == remoteEnvelope)
        #expect(conflict.local == localEnvelope)
        #expect(conflict.remote == remoteEnvelope)
        #expect(conflict.conflictingFields == ["notes"])
    }

    @Test
    func remoteOnlyChangeIsApplied() {
        let base = episodeEnvelope(notes: "alt", symptoms: ["Aura"])
        let local = base
        let remote = episodeEnvelope(notes: "neu", symptoms: ["Aura"])

        let result = SyncMergeEngine.merge(base: base, local: local, remote: remote)

        #expect(result.conflicts.isEmpty)
        #expect(result.merged.payload.episodePayload?.notes == "neu")
    }

    @Test
    func differentFieldsMergeWithoutConflict() {
        let base = episodeEnvelope(notes: "alt", symptoms: ["Aura"])
        let local = episodeEnvelope(notes: "lokal", symptoms: ["Aura"])
        let remote = episodeEnvelope(notes: "alt", symptoms: ["Aura", "Übelkeit"])

        let result = SyncMergeEngine.merge(base: base, local: local, remote: remote)

        #expect(result.conflicts.isEmpty)
        #expect(result.merged.payload.episodePayload?.notes == "lokal")
        #expect(result.merged.payload.episodePayload?.symptoms == ["Aura", "Übelkeit"])
    }

    @Test
    func sameFieldConflictIsReported() {
        let base = episodeEnvelope(notes: "alt", symptoms: ["Aura"])
        let local = episodeEnvelope(notes: "lokal", symptoms: ["Aura"])
        let remote = episodeEnvelope(notes: "remote", symptoms: ["Aura"])

        let result = SyncMergeEngine.merge(base: base, local: local, remote: remote)

        #expect(result.conflicts == ["notes"])
        #expect(result.merged.payload.episodePayload?.notes == "lokal")
    }

    @Test
    func continuousMedicationConflictIsReported() {
        let base = continuousMedicationEnvelope(name: "Metoprolol", dosage: "47,5 mg")
        let local = continuousMedicationEnvelope(name: "Metoprolol", dosage: "95 mg")
        let remote = continuousMedicationEnvelope(name: "Metoprolol", dosage: "50 mg")

        let result = SyncMergeEngine.merge(base: base, local: local, remote: remote)

        #expect(result.conflicts == ["dosage"])
        #expect(result.merged.payload.continuousMedicationPayload?.dosage == "95 mg")
    }

    @Test
    func medicationEntriesMergeByStableIdentifier() {
        let base = episodeEnvelope(
            notes: "alt",
            symptoms: [],
            medications: [
                .init(
                    id: "med-1",
                    name: "Ibuprofen",
                    category: "NSAR",
                    dosage: "400 mg",
                    quantity: 1,
                    takenAt: .distantPast,
                    effectiveness: "Teilweise",
                    reliefStartedAt: nil,
                    isRepeatDose: false
                )
            ]
        )

        let local = episodeEnvelope(
            notes: "alt",
            symptoms: [],
            medications: [
                .init(
                    id: "med-1",
                    name: "Ibuprofen",
                    category: "NSAR",
                    dosage: "600 mg",
                    quantity: 1,
                    takenAt: .distantPast,
                    effectiveness: "Teilweise",
                    reliefStartedAt: nil,
                    isRepeatDose: false
                )
            ]
        )

        let remote = episodeEnvelope(
            notes: "alt",
            symptoms: [],
            medications: [
                .init(
                    id: "med-1",
                    name: "Ibuprofen",
                    category: "NSAR",
                    dosage: "400 mg",
                    quantity: 2,
                    takenAt: .distantPast,
                    effectiveness: "Teilweise",
                    reliefStartedAt: nil,
                    isRepeatDose: false
                )
            ]
        )

        let result = SyncMergeEngine.merge(base: base, local: local, remote: remote)
        let medication = result.merged.payload.episodePayload?.medications.first

        #expect(result.conflicts.isEmpty)
        #expect(medication?.dosage == "600 mg")
        #expect(medication?.quantity == 2)
    }

    @Test
    func deleteMarkerMergesFromRemote() {
        let base = definitionEnvelope(name: "Sumatriptan", deletedAt: nil)
        let local = definitionEnvelope(name: "Sumatriptan", deletedAt: nil)
        let remoteDeletionDate = Date(timeIntervalSince1970: 100)
        let remote = definitionEnvelope(name: "Sumatriptan", deletedAt: remoteDeletionDate)

        let result = SyncMergeEngine.merge(base: base, local: local, remote: remote)

        #expect(result.conflicts.isEmpty)
        #expect(result.merged.deletedAt == remoteDeletionDate)
    }

    @Test
    func uploadPlannerSkipsCurrentShadowsAndConflictedDocuments() {
        var current = definitionEnvelope(name: "Sumatriptan", deletedAt: nil)
        var changed = definitionEnvelope(name: "Ibuprofen", deletedAt: nil)
        var changedBase = definitionEnvelope(name: "Ibuprofen alt", deletedAt: nil)
        var conflicted = definitionEnvelope(name: "Zolmitriptan", deletedAt: nil)
        current.documentID = "definition-current"
        changed.documentID = "definition-changed"
        changedBase.documentID = changed.documentID
        conflicted.documentID = "definition-conflicted"
        let currentShadow = SyncShadow(envelope: current)
        let changedShadow = SyncShadow(envelope: changedBase)
        let conflict = SyncConflict(
            documentID: conflicted.documentID,
            entityType: conflicted.entityType,
            base: nil,
            local: conflicted,
            remote: conflicted,
            conflictingFields: ["name"]
        )

        let pending = SyncUploadPlanner.pendingRecordNames(
            envelopes: [current, changed, conflicted],
            shadows: [
                current.documentID: currentShadow,
                changed.documentID: changedShadow
            ],
            conflicts: [conflict]
        )

        #expect(pending == [changed.documentID])
    }

    @Test
    @MainActor
    func manualSyncUploadsLocalChangeAndClearsUnsyncedRecords() async throws {
        let fakeProvider = FakeSyncProvider()
        let stack = try makeSyncTestStack(provider: fakeProvider)
        await stack.stateStore.setSyncEnabled(true)
        let documentID = try insertBaseEpisode(in: stack.container)

        await stack.coordinator.loadPersistedState()
        await stack.coordinator.syncNow()

        let shadow = await stack.stateStore.shadow(for: documentID)

        #expect(shadow?.envelope.documentID == documentID)
        #expect(stack.coordinator.status.unsyncedRecords == 0)
        #expect(await fakeProvider.sentRecordNames.contains(documentID))
    }

    @Test
    @MainActor
    func failedManualSyncKeepsNonRetryableSchemaErrorVisible() async throws {
        let fakeProvider = FakeSyncProvider(
            failedSaveError: productionSchemaCKError()
        )
        let stack = try makeSyncTestStack(provider: fakeProvider)
        await stack.stateStore.setSyncEnabled(true)
        _ = try insertBaseEpisode(in: stack.container)

        await stack.coordinator.loadPersistedState()
        await stack.coordinator.syncNow()

        #expect(stack.coordinator.status.lastError?.contains("Cloud-Konfiguration") == true)
        #expect(stack.coordinator.status.lastErrorIsRetryable == false)
        #expect(stack.coordinator.status.unsyncedRecords == 1)
    }

    @Test
    @MainActor
    func existingServerRecordRepairsShadowAndClearsUnsyncedRecord() async throws {
        let fakeProvider = FakeSyncProvider(
            failedSaveError: insertAlreadyExistsCKError()
        )
        let stack = try makeSyncTestStack(provider: fakeProvider)
        await stack.stateStore.setSyncEnabled(true)
        let documentID = try insertBaseEpisode(in: stack.container)
        let envelope = try requireEnvelope(from: stack.repository, documentID: documentID)
        fakeProvider.serverRecordForFailure = try record(from: envelope)

        await stack.coordinator.loadPersistedState()
        await stack.coordinator.syncNow()

        let shadow = await stack.stateStore.shadow(for: documentID)

        #expect(shadow?.envelope == envelope)
        #expect(shadow?.recordSystemFields != nil)
        #expect(stack.coordinator.status.lastError == nil)
        #expect(stack.coordinator.status.unsyncedRecords == 0)
    }

    @Test
    @MainActor
    func cloudKitProductionSchemaErrorIsNotRetryable() {
        let classified = SyncErrorClassifier.classify(productionSchemaCKError())

        #expect(classified.isRetryable == false)
        #expect(classified.userMessage.contains("Cloud-Konfiguration") == true)
    }
}

private func episodeEnvelope(
    notes: String,
    symptoms: [String],
    medications: [SyncMedicationEntryPayload] = []
) -> SyncDocumentEnvelope {
    SyncDocumentEnvelope(
        documentID: "episode-1",
        entityType: .episode,
        modifiedAt: .now,
        authorDeviceID: "device-a",
        payload: .episode(
            SyncEpisodePayload(
                id: "episode-1",
                startedAt: .distantPast,
                endedAt: nil,
                type: "Migräne",
                intensity: 6,
                painLocation: "links",
                painCharacter: "pochend",
                notes: notes,
                symptoms: symptoms,
                triggers: [],
                functionalImpact: "",
                menstruationStatus: "Nicht angegeben",
                medications: medications,
                weatherSnapshot: nil
            )
        )
    )
}

@MainActor
private func episodeEnvelopeNearCloudKitPayloadBudget() -> SyncDocumentEnvelope {
    var lowerBound = 0
    var upperBound = SyncPayloadSchema.maximumCloudKitPayloadBytes
    var best = episodeEnvelope(notes: "", symptoms: [])

    while lowerBound <= upperBound {
        let midpoint = (lowerBound + upperBound) / 2
        let candidate = episodeEnvelope(notes: String(repeating: "a", count: midpoint), symptoms: ["Aura"])
        let byteCount = CloudKitRecordCodec.payloadByteCount(for: candidate) ?? Int.max

        if byteCount <= SyncPayloadSchema.maximumCloudKitPayloadBytes {
            best = candidate
            lowerBound = midpoint + 1
        } else {
            upperBound = midpoint - 1
        }
    }

    return best
}

@MainActor
private func oversizedEpisodeEnvelope() -> SyncDocumentEnvelope {
    var notes = String(repeating: "a", count: SyncPayloadSchema.maximumCloudKitPayloadBytes)
    var envelope = episodeEnvelope(notes: notes, symptoms: ["Aura"])

    while (CloudKitRecordCodec.payloadByteCount(for: envelope) ?? 0) <= SyncPayloadSchema.maximumCloudKitPayloadBytes {
        notes += "übel "
        envelope = episodeEnvelope(notes: notes, symptoms: ["Aura"])
    }

    return envelope
}

private func fuzzedEpisodeEnvelope(seed: Int) -> SyncDocumentEnvelope {
    let fragments = [
        "Migräne",
        "Übelkeit",
        "Aura",
        "Lärm",
        "Licht",
        "Stress",
        "Schlaf",
        "Wärme"
    ]
    let notes = (0...seed).map { index in
        fragments[(seed + index) % fragments.count]
    }.joined(separator: " · ")
    let symptoms = Array(fragments.prefix((seed % fragments.count) + 1))

    var envelope = episodeEnvelope(
        notes: notes,
        symptoms: symptoms,
        medications: [
            SyncMedicationEntryPayload(
                id: UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", seed + 1))")!.uuidString,
                name: "Ibuprofen \(seed)",
                category: MedicationCategory.nsar.rawValue,
                dosage: "\(200 + seed) mg",
                quantity: max(1, seed % 4),
                takenAt: Date(timeIntervalSince1970: TimeInterval(seed * 60)),
                effectiveness: MedicationEffectiveness.partial.rawValue,
                reliefStartedAt: nil,
                isRepeatDose: seed.isMultiple(of: 3)
            )
        ]
    )
    envelope.modifiedAt = Date(timeIntervalSince1970: TimeInterval(seed + 1_000))
    return envelope
}

private let syncTestDeviceID = "device-local"
private let syncTestZoneID = CKRecordZone.ID(zoneName: "SyncTests", ownerName: CKCurrentUserDefaultName)

private struct SyncTestStack {
    let container: ModelContainer
    let stateStore: SyncStateStore
    let coordinator: SyncCoordinator
    let repository: LocalSyncRepository
    let healthContextStore: HealthContextStore
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { startIndex in
            Array(self[startIndex..<Swift.min(startIndex + size, count)])
        }
    }
}

@MainActor
private func makeSyncTestStack(provider: FakeSyncProvider? = nil) throws -> SyncTestStack {
    let schema = Schema(versionedSchema: SymiSchemaV6.self)
    let configuration = ModelConfiguration(
        "sync-tests-\(UUID().uuidString)",
        schema: schema,
        isStoredInMemoryOnly: true,
        cloudKitDatabase: .none
    )
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let stateStore = SyncStateStore(baseDirectoryURL: try makeTemporaryDirectory())
    let appLogStore = AppLogStore(baseDirectoryURL: try makeTemporaryDirectory())
    let healthContextStore = HealthContextStore(baseURL: try makeTemporaryDirectory())
    let coordinator = SyncCoordinator(
        modelContainer: container,
        appLogStore: appLogStore,
        healthContextStore: healthContextStore,
        stateStore: stateStore,
        deviceID: syncTestDeviceID,
        autostart: false,
        providerFactory: { _, _, _, recordProvider, eventHandler in
            if let provider {
                provider.install(recordProvider: recordProvider, eventHandler: eventHandler)
                return provider
            }

            return CloudKitSyncProvider(
                stateStore: stateStore,
                zoneID: syncTestZoneID,
                appLogStore: appLogStore,
                recordProvider: recordProvider,
                eventHandler: eventHandler
            )
        }
    )
    let repository = LocalSyncRepository(modelContainer: container, healthContextStore: healthContextStore)

    return SyncTestStack(
        container: container,
        stateStore: stateStore,
        coordinator: coordinator,
        repository: repository,
        healthContextStore: healthContextStore
    )
}

private final class FakeSyncProvider: SyncProvider, @unchecked Sendable {
    private let lock = NSLock()
    private let failedSaveError: CKError?
    var serverRecordForFailure: CKRecord?
    private var queuedRecordNames: [String] = []
    private var _sentRecordNames: [String] = []
    private var recordProvider: (@Sendable (CKRecord.ID) async -> CKRecord?)?
    private var eventHandler: (@Sendable (SyncProviderEvent) async -> Void)?

    init(failedSaveError: CKError? = nil) {
        self.failedSaveError = failedSaveError
    }

    var sentRecordNames: [String] {
        get async {
            lock.withLock {
                _sentRecordNames
            }
        }
    }

    var queuedChangeCount: Int {
        get async {
            lock.withLock {
                queuedRecordNames.count
            }
        }
    }

    var accountAvailability: SyncServiceState {
        get async {
            .ready
        }
    }

    func install(
        recordProvider: @escaping @Sendable (CKRecord.ID) async -> CKRecord?,
        eventHandler: @escaping @Sendable (SyncProviderEvent) async -> Void
    ) {
        lock.withLock {
            self.recordProvider = recordProvider
            self.eventHandler = eventHandler
        }
    }

    func start() async throws {}

    func stop() async {
        lock.withLock {
            queuedRecordNames.removeAll()
        }
    }

    func queue(recordNames: [String]) async {
        lock.withLock {
            queuedRecordNames.append(contentsOf: recordNames)
        }
    }

    func fetch() async throws {}

    func send() async throws {
        let snapshot = lock.withLock {
            (queuedRecordNames, recordProvider, eventHandler)
        }

        guard let recordProvider = snapshot.1, let eventHandler = snapshot.2 else {
            return
        }

        var records: [CKRecord] = []
        var failures: [SyncFailedRecordSave] = []
        for recordName in snapshot.0 {
            let recordID = CKRecord.ID(recordName: recordName, zoneID: syncTestZoneID)
            if let record = await recordProvider(recordID) {
                if let failedSaveError {
                    let serverRecord = lock.withLock {
                        serverRecordForFailure
                    }
                    failures.append(SyncFailedRecordSave(recordID: record.recordID, error: failedSaveError, serverRecord: serverRecord))
                } else {
                    records.append(record)
                }
            }
        }

        lock.withLock {
            _sentRecordNames.append(contentsOf: records.map { $0.recordID.recordName })
            if failures.isEmpty {
                queuedRecordNames.removeAll()
            }
        }
        if !records.isEmpty {
            await eventHandler(.didSendRecords(records))
        }
        if !failures.isEmpty {
            await eventHandler(.didFailToSend(failures))
        }
    }
}

private func productionSchemaCKError() -> CKError {
    let error = NSError(
        domain: CKError.errorDomain,
        code: CKError.serverRejectedRequest.rawValue,
        userInfo: [
            NSLocalizedDescriptionKey: "Cannot create new type SyncDocument in production schema"
        ]
    )

    return CKError(_nsError: error)
}

private func insertAlreadyExistsCKError() -> CKError {
    let error = NSError(
        domain: CKError.errorDomain,
        code: CKError.serverRecordChanged.rawValue,
        userInfo: [
            NSLocalizedDescriptionKey: "record to insert already exists"
        ]
    )

    return CKError(_nsError: error)
}

@MainActor
private func insertBaseEpisode(in container: ModelContainer) throws -> String {
    let episodeID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE") ?? UUID()
    let context = ModelContext(container)
    let episode = Episode(
        id: episodeID,
        startedAt: Date(timeIntervalSince1970: 1_000),
        updatedAt: Date(timeIntervalSince1970: 1_000),
        type: .migraine,
        intensity: 5,
        notes: "alt",
        symptoms: ["Aura"]
    )
    context.insert(episode)
    try context.save()
    return "episode:\(episodeID.uuidString)"
}

@MainActor
private func updateEpisode(
    documentID: String,
    in container: ModelContainer,
    apply: (Episode) -> Void
) throws {
    let episodeID = try #require(UUID(uuidString: documentID.replacingOccurrences(of: "episode:", with: "")))
    let context = ModelContext(container)
    let episodes = try context.fetch(FetchDescriptor<Episode>())
    let episode = try #require(episodes.first { $0.id == episodeID })
    apply(episode)
    try context.save()
}

private func episodeEnvelope(
    from base: SyncDocumentEnvelope,
    modifiedAt: Date,
    update: (inout SyncEpisodePayload) -> Void
) -> SyncDocumentEnvelope {
    var envelope = base
    envelope.modifiedAt = modifiedAt
    envelope.authorDeviceID = "device-remote"

    guard case .episode(var payload) = envelope.payload else {
        return envelope
    }

    update(&payload)
    envelope.payload = .episode(payload)
    return envelope
}

@MainActor
private func record(from envelope: SyncDocumentEnvelope) throws -> CKRecord {
    try #require(
        CloudKitRecordCodec.record(
            for: envelope,
            zoneID: syncTestZoneID,
            existingSystemFields: nil
        )
    )
}

@MainActor
private func requireEnvelope(from repository: LocalSyncRepository, documentID: String) throws -> SyncDocumentEnvelope {
    let envelope = try repository.envelope(documentID: documentID, deviceID: syncTestDeviceID)
    return try #require(envelope)
}

private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

private func definitionEnvelope(name: String, deletedAt: Date?) -> SyncDocumentEnvelope {
    SyncDocumentEnvelope(
        documentID: "definition-1",
        entityType: .medicationDefinition,
        modifiedAt: Date(timeIntervalSince1970: 1_000),
        authorDeviceID: "device-a",
        deletedAt: deletedAt,
        payload: .medicationDefinition(
            SyncMedicationDefinitionPayload(
                catalogKey: "custom:1",
                groupID: "custom",
                groupTitle: "Eigene Medikamente",
                groupFooter: nil,
                name: name,
                category: "Triptan",
                suggestedDosage: "50 mg",
                sortOrder: 1,
                isCustom: true,
                createdAt: .distantPast
            )
        )
    )
}

private func continuousMedicationEnvelope(name: String, dosage: String) -> SyncDocumentEnvelope {
    SyncDocumentEnvelope(
        documentID: "continuousMedication-1",
        entityType: .continuousMedication,
        modifiedAt: Date(timeIntervalSince1970: 1_000),
        authorDeviceID: "device-a",
        payload: .continuousMedication(
            SyncContinuousMedicationPayload(
                id: "continuousMedication-1",
                name: name,
                dosage: dosage,
                frequency: "morgens",
                startDate: .distantPast,
                endDate: nil,
                createdAt: .distantPast
            )
        )
    )
}

private func sampleHealthContext() -> HealthContextSnapshotData {
    HealthContextSnapshotData(
        recordedAt: Date(timeIntervalSince1970: 1_200),
        source: "Test",
        sleepMinutes: 420,
        stepCount: 4_200,
        averageHeartRate: nil,
        restingHeartRate: 62,
        heartRateVariability: nil,
        menstrualFlow: nil,
        symptoms: []
    )
}

private extension SyncDocumentEnvelope.Payload {
    var episodePayload: SyncEpisodePayload? {
        guard case .episode(let payload) = self else {
            return nil
        }

        return payload
    }

    var continuousMedicationPayload: SyncContinuousMedicationPayload? {
        guard case .continuousMedication(let payload) = self else {
            return nil
        }

        return payload
    }
}
