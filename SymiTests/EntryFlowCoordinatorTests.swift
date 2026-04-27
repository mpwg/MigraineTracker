import Foundation
import Testing
@testable import Symi

@MainActor
struct EntryFlowCoordinatorTests {
    @Test
    func flowHasFiveOrderedSteps() {
        #expect(EntryFlowCoordinator.steps == [.headache, .medication, .triggers, .note, .review])
    }

    @Test
    func triggerCatalogContainsRequiredContextOptions() {
        let coordinator = makeCoordinator()
        let requiredTriggers = ["Wetter", "Stress", "Erhöhte Arbeitsbelastung", "Regel", "Schlafdauer", "Sport"]

        for trigger in requiredTriggers {
            #expect(coordinator.triggerOptions.contains(trigger))
        }
    }

    @Test
    func draftSurvivesForwardAndBackNavigation() {
        let coordinator = makeCoordinator()
        coordinator.draft.intensity = 8
        coordinator.continueToNextStep()
        coordinator.continueToNextStep()

        coordinator.path.removeLast()

        #expect(coordinator.currentStep == .medication)
        #expect(coordinator.draft.intensity == 8)
    }

    @Test
    func optionalStepsCanBeSkipped() {
        let coordinator = makeCoordinator()
        coordinator.continueToNextStep()

        coordinator.skipCurrentStep()

        #expect(coordinator.currentStep == .triggers)
        #expect(coordinator.draft.medications.isEmpty)
        #expect(coordinator.draft.continuousMedicationChecks.isEmpty)
    }

    @Test
    func medicationStepStoresContinuousMedicationChecksSeparatelyFromAcuteMedication() async {
        let repository = EntryFlowContinuousMedicationRepositoryMock(activeMedications: [
            ContinuousMedicationRecord(
                id: UUID(),
                name: "Metoprolol",
                dosage: "50 mg",
                frequency: "täglich",
                startDate: .now,
                endDate: nil,
                createdAt: .now,
                updatedAt: .now
            )
        ])
        let coordinator = makeCoordinator(continuousMedicationRepository: repository)
        await coordinator.continuousMedicationController.reload(for: .now)
        coordinator.draft.continuousMedicationChecks = coordinator.continuousMedicationController.makeDefaultChecks()
        coordinator.draft.continuousMedicationChecks[0].wasTaken = false

        coordinator.continueToNextStep()
        coordinator.continueToNextStep()

        #expect(coordinator.draft.continuousMedicationChecks.count == 1)
        #expect(coordinator.draft.continuousMedicationChecks[0].name == "Metoprolol")
        #expect(coordinator.draft.continuousMedicationChecks[0].wasTaken == false)
        #expect(coordinator.draft.medications.isEmpty)
    }

    @Test
    func reviewEditNavigatesBackToSelectedStep() {
        let coordinator = makeCoordinator()
        coordinator.continueToNextStep()
        coordinator.continueToNextStep()
        coordinator.continueToNextStep()
        coordinator.continueToNextStep()

        coordinator.edit(.triggers)

        #expect(coordinator.currentStep == .triggers)
        #expect(coordinator.path == [.medication, .triggers])
    }

    @Test
    func headacheStepCanSaveDirectlyThroughRepository() async throws {
        let repository = EntryFlowEpisodeRepositoryMock()
        let coordinator = makeCoordinator(repository: repository)
        coordinator.draft.type = .unclear
        coordinator.draft.intensity = 4
        coordinator.draft.selectedPainLocations = ["Schläfen", "Stirn"]

        coordinator.saveHeadacheOnly()
        try await waitForSaveResult(on: coordinator)

        #expect(repository.lastSavedDraft?.type == .headache)
        #expect(repository.lastSavedDraft?.intensity == 4)
        #expect(repository.lastSavedDraft?.resolvedPainLocation == "Schläfen, Stirn")
        #expect(coordinator.saveResult == .saved(repository.savedID))
    }

    @Test
    func headacheStepNormalizesNewIntensityRange() async throws {
        let repository = EntryFlowEpisodeRepositoryMock()
        let coordinator = makeCoordinator(repository: repository)
        coordinator.draft.intensity = 0

        coordinator.saveHeadacheOnly()
        try await waitForSaveResult(on: coordinator)

        #expect(repository.lastSavedDraft?.intensity == 1)
    }

    @Test
    func reviewSaveFinalizesDraftWithWeatherAndHealthContext() async throws {
        let repository = EntryFlowEpisodeRepositoryMock()
        let weatherContext = EntryFlowWeatherContextMock(snapshot: makeWeatherSnapshot())
        let healthService = EntryFlowHealthServiceMock(snapshot: makeHealthContext())
        let coordinator = makeCoordinator(
            repository: repository,
            weatherContextService: weatherContext,
            healthService: healthService
        )
        coordinator.draft.intensity = 7
        coordinator.draft.selectedPainLocations = ["Stirn"]
        coordinator.draft.selectedTriggers = ["Stress"]

        coordinator.continueToNextStep()
        coordinator.continueToNextStep()
        coordinator.continueToNextStep()
        coordinator.continueToNextStep()
        coordinator.saveFromReview()
        try await waitForSaveResult(on: coordinator)

        #expect(repository.saveCount == 1)
        #expect(repository.lastSavedDraft?.type == .headache)
        #expect(repository.lastSavedDraft?.intensity == 7)
        #expect(repository.lastSavedDraft?.resolvedPainLocation == "Stirn")
        #expect(repository.lastWeatherSnapshot == makeWeatherSnapshot())
        #expect(repository.lastHealthContext == makeHealthContext())
        #expect(healthService.writtenEpisodeID == repository.savedID)
    }

    @Test
    func startedAtPresetsUpdateDraftTime() {
        let calendar = Calendar(identifier: .gregorian)
        let coordinator = makeCoordinator()
        let referenceDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 26, hour: 15, minute: 30))!

        coordinator.selectDayPartPreset(.abends, referenceDate: referenceDate, calendar: calendar)
        let selectedHour = calendar.component(.hour, from: coordinator.draft.startedAt)

        #expect(EntryDayPartPreset.abends.dayPart == .abends)
        #expect(selectedHour == 19)
        #expect(EntryStartedAtPreset.oneHourAgo.date(relativeTo: referenceDate, calendar: calendar) == referenceDate.addingTimeInterval(-3_600))
    }

    @Test
    func cancelDiscardsDraftExplicitly() {
        let coordinator = makeCoordinator()
        coordinator.draft.intensity = 9
        coordinator.continueToNextStep()

        coordinator.cancel()

        #expect(coordinator.isCancelled)
        #expect(coordinator.path.isEmpty)
        #expect(coordinator.draft.intensity == 4)
    }

    @Test
    func reviewSaveAllowsMissingTriggersAndWeatherData() async throws {
        let repository = EntryFlowEpisodeRepositoryMock()
        let coordinator = makeCoordinator(repository: repository)
        coordinator.draft.intensity = 4

        coordinator.continueToNextStep()
        coordinator.skipCurrentStep()
        coordinator.skipCurrentStep()
        coordinator.skipCurrentStep()
        coordinator.saveFromReview()
        try await waitForSaveResult(on: coordinator)

        #expect(repository.saveCount == 1)
        #expect(repository.lastSavedDraft?.selectedTriggers.isEmpty == true)
        #expect(repository.lastWeatherSnapshot == nil)
        #expect(coordinator.saveResult == .saved(repository.savedID))
    }

    private func makeCoordinator(
        repository: EntryFlowEpisodeRepositoryMock = EntryFlowEpisodeRepositoryMock(),
        medicationRepository: EntryFlowMedicationRepositoryMock = EntryFlowMedicationRepositoryMock(),
        continuousMedicationRepository: EntryFlowContinuousMedicationRepositoryMock = EntryFlowContinuousMedicationRepositoryMock(),
        weatherContextService: EntryFlowWeatherContextMock = EntryFlowWeatherContextMock(),
        healthService: EntryFlowHealthServiceMock = EntryFlowHealthServiceMock()
    ) -> EntryFlowCoordinator {
        EntryFlowCoordinator(
            episodeRepository: repository,
            medicationRepository: medicationRepository,
            continuousMedicationRepository: continuousMedicationRepository,
            weatherContextService: weatherContextService,
            healthService: healthService,
            autoloadMedications: false
        )
    }

    private func makeWeatherSnapshot() -> WeatherSnapshotData {
        WeatherSnapshotData(
            recordedAt: Date(timeIntervalSince1970: 1_776_000_000),
            condition: "Leichter Regen",
            temperature: 12.5,
            humidity: 72,
            pressure: 1_013,
            precipitation: 1.2,
            weatherCode: 63,
            source: "Test"
        )
    }

    private func makeHealthContext() -> HealthContextSnapshotData {
        HealthContextSnapshotData(
            recordedAt: Date(timeIntervalSince1970: 1_776_000_000),
            source: "Test",
            sleepMinutes: 420,
            stepCount: nil,
            averageHeartRate: nil,
            restingHeartRate: nil,
            heartRateVariability: nil,
            menstrualFlow: nil,
            symptoms: []
        )
    }

    private func waitForSaveResult(on coordinator: EntryFlowCoordinator) async throws {
        for _ in 0 ..< 100 {
            if coordinator.saveResult != nil {
                return
            }
            await Task.yield()
        }

        throw EntryFlowTestError.timedOut
    }
}

private enum EntryFlowTestError: Error {
    case timedOut
}

private final class EntryFlowEpisodeRepositoryMock: EpisodeRepository, @unchecked Sendable {
    let savedID = UUID()
    var lastSavedDraft: EpisodeDraft?
    var lastWeatherSnapshot: WeatherSnapshotData?
    var lastHealthContext: HealthContextSnapshotData?
    var saveCount = 0

    func fetchRecent() throws -> [EpisodeRecord] { [] }
    func fetchByDay(_ day: Date) throws -> [EpisodeRecord] { [] }
    func fetchByMonth(_ month: Date) throws -> [EpisodeRecord] { [] }
    func load(id: UUID) throws -> EpisodeRecord? { nil }

    func save(draft: EpisodeDraft, weatherSnapshot: WeatherSnapshotData?, healthContext: HealthContextSnapshotData?) throws -> UUID {
        saveCount += 1
        lastSavedDraft = draft
        lastWeatherSnapshot = weatherSnapshot
        lastHealthContext = healthContext
        return savedID
    }

    func softDelete(id: UUID) throws {}
    func restore(id: UUID) throws {}
    func fetchDeleted() throws -> [EpisodeRecord] { [] }
}

private final class EntryFlowMedicationRepositoryMock: MedicationCatalogRepository, @unchecked Sendable {
    func fetchDefinitions(searchText: String?) throws -> [MedicationDefinitionRecord] { [] }

    func saveCustomDefinition(_ draft: CustomMedicationDefinitionDraft) throws -> MedicationDefinitionRecord {
        MedicationDefinitionRecord(
            catalogKey: draft.id,
            groupID: "custom-medications",
            groupTitle: "Eigene Medikamente",
            groupFooter: nil,
            name: draft.name,
            category: draft.category,
            suggestedDosage: draft.dosage,
            sortOrder: 1,
            isCustom: true,
            isDeleted: false
        )
    }

    func softDeleteCustomDefinition(catalogKey: String) throws {}
    func fetchDeletedDefinitions() throws -> [MedicationDefinitionRecord] { [] }
}

private final class EntryFlowContinuousMedicationRepositoryMock: ContinuousMedicationRepository, @unchecked Sendable {
    let activeMedications: [ContinuousMedicationRecord]

    init(activeMedications: [ContinuousMedicationRecord] = []) {
        self.activeMedications = activeMedications
    }

    func fetchAll() throws -> [ContinuousMedicationRecord] { [] }
    func fetchActive(on date: Date) throws -> [ContinuousMedicationRecord] { activeMedications }
    func save(_ draft: ContinuousMedicationDraft) throws -> ContinuousMedicationRecord {
        ContinuousMedicationRecord(
            id: draft.id ?? UUID(),
            name: draft.name,
            dosage: draft.dosage,
            frequency: draft.frequency,
            startDate: draft.startDate,
            endDate: draft.endDate,
            createdAt: .now,
            updatedAt: .now
        )
    }
    func delete(id: UUID) throws {}
}

@MainActor
private final class EntryFlowWeatherContextMock: EpisodeWeatherContextProviding {
    let snapshot: WeatherSnapshotData?

    init(snapshot: WeatherSnapshotData? = nil) {
        self.snapshot = snapshot
    }

    func loadWeather(
        for startedAt: Date,
        originalStartedAt: Date?,
        originalSnapshot: WeatherSnapshotData?
    ) async -> WeatherLoadState {
        snapshot.map { .loaded($0) } ?? .unavailable("Kein Wetter verfügbar.")
    }

    func snapshotForSave(
        startedAt: Date,
        currentState: WeatherLoadState,
        originalStartedAt: Date?,
        originalSnapshot: WeatherSnapshotData?
    ) async throws -> EpisodeWeatherSnapshotResolution {
        EpisodeWeatherSnapshotResolution(
            snapshot: snapshot,
            state: snapshot.map { .loaded($0) } ?? .unavailable("Kein Wetter verfügbar.")
        )
    }
}

private final class EntryFlowHealthServiceMock: HealthService {
    let snapshot: HealthContextSnapshotData?
    var writtenEpisodeID: UUID?

    init(snapshot: HealthContextSnapshotData? = nil) {
        self.snapshot = snapshot
    }

    var readDefinitions: [HealthDataTypeDefinition] { [] }
    var writeDefinitions: [HealthDataTypeDefinition] { [] }

    func authorizationSnapshot() -> HealthAuthorizationSnapshot { .unavailable }
    func setEnabled(_ enabled: Bool, for type: HealthDataTypeID, direction: HealthDataDirection) {}
    func requestReadAuthorization() async throws {}
    func requestWriteAuthorization() async throws {}
    func contextSnapshot(for draft: EpisodeDraft) async throws -> HealthContextSnapshotData? { snapshot }

    func writeEpisode(id: UUID, draft: EpisodeDraft) async throws {
        writtenEpisodeID = id
    }
}
