import CloudKit
import Foundation
import SwiftData
import Testing
@testable import Symi

struct SyncMergeEngineTests {
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
    repository: LocalSyncRepository
) {
    let schema = Schema(versionedSchema: SymiSchemaV5.self)
    let configuration = ModelConfiguration(
        "sync-tests-\(UUID().uuidString)",
        schema: schema,
        isStoredInMemoryOnly: true,
        cloudKitDatabase: .none
    )
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let stateStore = SyncStateStore(baseDirectoryURL: try makeTemporaryDirectory())
    let appLogStore = AppLogStore(baseDirectoryURL: try makeTemporaryDirectory())
    let coordinator = SyncCoordinator(
        modelContainer: container,
        appLogStore: appLogStore,
        stateStore: stateStore,
        deviceID: syncTestDeviceID,
        autostart: false
    )
    let repository = LocalSyncRepository(modelContainer: container)

    return (container, stateStore, coordinator, repository)
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

private extension SyncDocumentEnvelope.Payload {
    var episodePayload: SyncEpisodePayload? {
        guard case .episode(let payload) = self else {
            return nil
        }

        return payload
    }
}
