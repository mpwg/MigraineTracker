import Foundation
import Testing
@testable import Symi

struct SyncMergeEngineTests {
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

private func definitionEnvelope(name: String, deletedAt: Date?) -> SyncDocumentEnvelope {
    SyncDocumentEnvelope(
        documentID: "definition-1",
        entityType: .medicationDefinition,
        modifiedAt: .now,
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
