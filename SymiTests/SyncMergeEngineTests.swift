import CloudKit
import Foundation
import SwiftData
import Testing
@testable import Symi

struct SyncMergeEngineTests {
    @Test
    func corruptSyncStateFileStartsWithCleanStateAndCanPersistAgain() async throws {
        let baseDirectory = try makeTemporaryDirectory()
        let syncDirectory = baseDirectory.appendingPathComponent("Symi", isDirectory: true)
        try FileManager.default.createDirectory(at: syncDirectory, withIntermediateDirectories: true)
        let syncStateURL = syncDirectory.appendingPathComponent("sync-state.json")
        try Data("{ keine gültige Sync-State-Datei".utf8).write(to: syncStateURL)

        let stateStore = SyncStateStore(baseDirectoryURL: baseDirectory)

        #expect(await stateStore.syncEnabled() == false)

        await stateStore.setSyncEnabled(true)
        let persistedData = try Data(contentsOf: syncStateURL)
        let persistedObject = try #require(
            JSONSerialization.jsonObject(with: persistedData) as? [String: Any]
        )
        #expect(persistedObject["syncEnabled"] as? Bool == true)
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

private let syncTestDeviceID = "device-local"
private let syncTestZoneID = CKRecordZone.ID(zoneName: "SyncTests", ownerName: CKCurrentUserDefaultName)

@MainActor
private func makeSyncTestStack() throws -> (
    container: ModelContainer,
    stateStore: SyncStateStore,
    coordinator: SyncCoordinator,
    repository: LocalSyncRepository,
    healthContextStore: HealthContextStore
) {
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
        autostart: false
    )
    let repository = LocalSyncRepository(modelContainer: container, healthContextStore: healthContextStore)

    return (container, stateStore, coordinator, repository, healthContextStore)
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
