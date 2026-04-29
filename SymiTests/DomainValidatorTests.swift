import Foundation
import SwiftData
import Testing
@testable import Symi

@MainActor
struct DomainValidatorTests {
    @Test
    func domainValidatorReportsEpisodeMedicationAndWeatherInvariants() throws {
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let episode = Episode(
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(-60),
            type: .migraine,
            intensity: 11
        )
        episode.medications = [
            MedicationEntry(
                name: " ",
                category: .triptan,
                dosage: "50 mg",
                quantity: -1,
                takenAt: startedAt,
                effectiveness: .partial,
                episode: episode
            )
        ]
        episode.continuousMedicationChecks = [
            ContinuousMedicationCheck(
                continuousMedicationID: UUID(),
                name: "",
                wasTaken: true,
                episode: episode
            )
        ]
        episode.weatherSnapshot = WeatherSnapshot(
            recordedAt: startedAt,
            condition: "Regen",
            source: "Apple Weather",
            contextRangeStart: startedAt,
            contextRangeEnd: startedAt.addingTimeInterval(-60),
            episode: episode
        )

        let issues = DomainValidator.episodeIssues(for: episode)

        #expect(issues.contains { $0.contains("endedAt") })
        #expect(issues.contains { $0.contains("intensity") })
        #expect(issues.contains { $0.contains("medications[0].name") })
        #expect(issues.contains { $0.contains("quantity") })
        #expect(issues.contains { $0.contains("continuousMedicationChecks[0].name") })
        #expect(issues.contains { $0.contains("contextRangeEnd") })
    }

    @Test
    func swiftDataEpisodeRepositoryRejectsInvalidDraftMedicationName() throws {
        let repository = SwiftDataEpisodeRepository(
            modelContainer: try makeInMemoryContainer(),
            healthContextStore: HealthContextStore(baseURL: try makeTemporaryDirectory())
        )
        var draft = EpisodeDraft.makeNew(initialStartedAt: Date(timeIntervalSince1970: 1_700_000_000))
        draft.medications = [
            MedicationSelectionDraft(
                selectionKey: "invalid",
                name: " ",
                category: .triptan,
                dosage: "50 mg",
                quantity: 1,
                isSelected: true
            )
        ]

        #expect(throws: DomainValidationError.self) {
            try repository.save(draft: draft, weatherSnapshot: nil, healthContext: nil)
        }
    }

    @Test
    func continuousMedicationRepositoryRejectsEmptyNameAndInvalidEndDate() throws {
        let repository = SwiftDataContinuousMedicationRepository(modelContainer: try makeInMemoryContainer())
        let startDate = Date(timeIntervalSince1970: 1_700_000_000)
        let draft = ContinuousMedicationDraft(
            name: " ",
            dosage: "50 mg",
            frequency: "täglich",
            startDate: startDate,
            endDate: startDate.addingTimeInterval(-86_400)
        )

        #expect(throws: DomainValidationError.self) {
            try repository.save(draft)
        }
    }

    @Test
    func backupImportPreviewRejectsInvalidDomainPayload() throws {
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let episode = Episode(
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(-60),
            type: .migraine,
            intensity: 8
        )
        let snapshot = DataTransferSnapshot(
            episodes: [EpisodePayload(episode: episode)],
            customMedicationDefinitions: []
        )

        #expect(throws: DomainValidationError.self) {
            _ = try snapshot.previewImport(into: ModelContext(try makeInMemoryContainer()))
        }
    }

    @Test
    func remoteSyncValidatorRejectsInvalidDomainPayload() throws {
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let episodeID = UUID()
        let envelope = SyncDocumentEnvelope(
            documentID: "episode:\(episodeID.uuidString)",
            entityType: .episode,
            modifiedAt: startedAt,
            authorDeviceID: "device",
            payload: .episode(
                SyncEpisodePayload(
                    id: episodeID.uuidString,
                    startedAt: startedAt,
                    endedAt: startedAt.addingTimeInterval(-60),
                    type: EpisodeType.migraine.rawValue,
                    intensity: 0,
                    painLocation: "",
                    painCharacter: "",
                    notes: "",
                    symptoms: [],
                    triggers: [],
                    functionalImpact: "",
                    menstruationStatus: MenstruationStatus.unknown.rawValue,
                    medications: [
                        SyncMedicationEntryPayload(
                            id: UUID().uuidString,
                            name: "",
                            category: MedicationCategory.triptan.rawValue,
                            dosage: "50 mg",
                            quantity: -1,
                            takenAt: startedAt,
                            effectiveness: MedicationEffectiveness.partial.rawValue,
                            reliefStartedAt: nil,
                            isRepeatDose: false
                        )
                    ],
                    weatherSnapshot: nil
                )
            )
        )

        #expect(throws: RemoteSyncPayloadValidationError.self) {
            try RemoteSyncPayloadValidator.validate(envelope)
        }
    }

    @Test
    func startupMaintenanceRejectsInvalidPersistedDomainData() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        context.insert(Episode(startedAt: .now, type: .migraine, intensity: 12))
        try context.save()

        #expect(throws: DomainValidationError.self) {
            try StartupMaintenanceService.normalizePersistentEnumValues(in: container)
        }
    }
}

private func makeInMemoryContainer() throws -> ModelContainer {
    let schema = Schema(versionedSchema: SymiSchemaV6.self)
    let configuration = ModelConfiguration(
        "domain-validator-tests-\(UUID().uuidString)",
        schema: schema,
        isStoredInMemoryOnly: true,
        cloudKitDatabase: .none
    )
    return try ModelContainer(for: schema, configurations: [configuration])
}

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "SymiDomainValidatorTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
