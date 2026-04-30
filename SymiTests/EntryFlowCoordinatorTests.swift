import Foundation
import os
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
        let requiredTriggers = EpisodeTriggerOption.allCases.map(\.displayLabel)

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
        coordinator.draft.selectedIntensityLevel = .medium
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
                updatedAt: .now,
                deletedAt: nil
            )
        ])
        let coordinator = makeCoordinator(continuousMedicationRepository: repository)
        coordinator.draft.selectedIntensityLevel = .medium
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
        coordinator.draft.selectedIntensityLevel = .medium
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
        #expect(coordinator.saveResult == .saved(repository.savedID, healthWarning: nil))
    }

    @Test
    func headacheStepRequiresSelectedIntensityBeforeSaving() async throws {
        let repository = EntryFlowEpisodeRepositoryMock()
        let coordinator = makeCoordinator(repository: repository)

        coordinator.saveHeadacheOnly()

        #expect(repository.lastSavedDraft == nil)
        #expect(coordinator.saveResult == nil)
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
    func reviewSaveSurfacesHealthContextFailureWithoutBlockingLocalSave() async throws {
        let repository = EntryFlowEpisodeRepositoryMock()
        let healthService = EntryFlowHealthServiceMock(contextError: EntryFlowHealthError.context)
        let coordinator = makeCoordinator(repository: repository, healthService: healthService)
        coordinator.draft.intensity = 4

        coordinator.saveHeadacheOnly()
        try await waitForSaveResult(on: coordinator)

        #expect(repository.saveCount == 1)
        #expect(repository.lastHealthContext == nil)
        #expect(coordinator.saveResult == .saved(
            repository.savedID,
            healthWarning: EpisodeHealthSaveWarning.contextUnavailable.message
        ))
    }

    @Test
    func reviewSaveSurfacesHealthWriteFailureWithoutBlockingLocalSave() async throws {
        let repository = EntryFlowEpisodeRepositoryMock()
        let healthService = EntryFlowHealthServiceMock(writeError: EntryFlowHealthError.write)
        let coordinator = makeCoordinator(repository: repository, healthService: healthService)
        coordinator.draft.intensity = 4

        coordinator.saveHeadacheOnly()
        try await waitForSaveResult(on: coordinator)

        #expect(repository.saveCount == 1)
        #expect(healthService.writtenEpisodeID == repository.savedID)
        #expect(coordinator.saveResult == .saved(
            repository.savedID,
            healthWarning: EpisodeHealthSaveWarning.writeFailed.message
        ))
    }

    @Test
    func editorSaveSurfacesHealthWriteFailureWithoutBlockingLocalSave() async throws {
        let repository = EntryFlowEpisodeRepositoryMock()
        let healthService = EntryFlowHealthServiceMock(writeError: EntryFlowHealthError.write)
        let controller = EpisodeEditorController(
            episodeID: nil,
            initialStartedAt: nil,
            episodeRepository: repository,
            medicationRepository: EntryFlowMedicationRepositoryMock(),
            syncService: EntryFlowSyncServiceMock(),
            weatherContextService: EntryFlowWeatherContextMock(),
            healthService: healthService
        )
        controller.draft.intensity = 4

        controller.save(onSaved: nil, onDismiss: {})
        try await waitForEditorSave(on: controller)

        #expect(repository.saveCount == 1)
        #expect(healthService.writtenEpisodeID == repository.savedID)
        #expect(controller.healthSaveWarningMessage == EpisodeHealthSaveWarning.writeFailed.message)
        #expect(controller.validationMessage == EpisodeHealthSaveWarning.writeFailed.message)
        #expect(controller.saveMessageVisible)
    }

    @Test
    func startedAtPresetsUpdateDraftTime() {
        let calendar = Calendar(identifier: .gregorian)
        let coordinator = makeCoordinator()
        let referenceDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 26, hour: 15, minute: 30))!

        coordinator.selectDayPart(.abends, referenceDate: referenceDate, calendar: calendar)
        let selectedHour = calendar.component(.hour, from: coordinator.draft.startedAt)

        #expect(EpisodeDayPart.abends.representativeHour == 19)
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
        #expect(coordinator.draft.selectedIntensityLevel == nil)
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
        #expect(coordinator.saveResult == .saved(repository.savedID, healthWarning: nil))
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

    private func waitForEditorSave(on controller: EpisodeEditorController) async throws {
        for _ in 0 ..< 100 {
            if controller.saveMessageVisible || controller.validationMessage != nil {
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

private enum EntryFlowHealthError: Error {
    case context
    case write
}

private final class EntryFlowEpisodeRepositoryMock: EpisodeRepository, Sendable {
    private struct State: Sendable {
        var lastSavedDraft: EpisodeDraft?
        var lastWeatherSnapshot: WeatherSnapshotData?
        var lastHealthContext: HealthContextSnapshotData?
        var saveCount = 0
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    let savedID = UUID()

    var lastSavedDraft: EpisodeDraft? {
        state.withLock(\.lastSavedDraft)
    }
    var lastWeatherSnapshot: WeatherSnapshotData? {
        state.withLock(\.lastWeatherSnapshot)
    }
    var lastHealthContext: HealthContextSnapshotData? {
        state.withLock(\.lastHealthContext)
    }
    var saveCount: Int {
        state.withLock(\.saveCount)
    }

    func fetchRecent() throws -> [EpisodeRecord] { [] }
    func fetchByDay(_ day: Date) throws -> [EpisodeRecord] { [] }
    func fetchByMonth(_ month: Date) throws -> [EpisodeRecord] { [] }
    func load(id: UUID) throws -> EpisodeRecord? { nil }

    func save(draft: EpisodeDraft, weatherSnapshot: WeatherSnapshotData?, healthContext: HealthContextSnapshotData?) throws -> UUID {
        state.withLock {
            $0.saveCount += 1
            $0.lastSavedDraft = draft
            $0.lastWeatherSnapshot = weatherSnapshot
            $0.lastHealthContext = healthContext
        }
        return savedID
    }

    func softDelete(id: UUID) throws {}
    func restore(id: UUID) throws {}
    func fetchDeleted() throws -> [EpisodeRecord] { [] }
}

private final class EntryFlowMedicationRepositoryMock: MedicationCatalogRepository, Sendable {
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

private final class EntryFlowContinuousMedicationRepositoryMock: ContinuousMedicationRepository, Sendable {
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
            updatedAt: .now,
            deletedAt: nil
        )
    }
    func delete(id: UUID) throws {}
}

private final class EntryFlowSyncServiceMock: SyncService {
    var isEnabled = false
    var status = SyncStatusSnapshot()
    var conflicts: [SyncConflict] = []

    func setSyncEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    func refreshStatus() {}
    func syncNow() async {}
    func disableSyncAndDeleteCloudData() async {}
    func retryLastError() async {}
    func resolveConflictKeepingLocal(_ conflict: SyncConflict) async {}
    func resolveConflictUsingRemote(_ conflict: SyncConflict) async {}
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
    let contextError: Error?
    let writeError: Error?
    var writtenEpisodeID: UUID?

    init(snapshot: HealthContextSnapshotData? = nil, contextError: Error? = nil, writeError: Error? = nil) {
        self.snapshot = snapshot
        self.contextError = contextError
        self.writeError = writeError
    }

    var readDefinitions: [HealthDataTypeDefinition] { [] }
    var writeDefinitions: [HealthDataTypeDefinition] { [] }

    func authorizationSnapshot() -> HealthAuthorizationSnapshot { .unavailable }
    func setEnabled(_ enabled: Bool, for type: HealthDataTypeID, direction: HealthDataDirection) {}
    func requestReadAuthorization() async throws {}
    func requestWriteAuthorization() async throws {}
    func contextSnapshot(for draft: EpisodeDraft) async throws -> HealthContextSnapshotData? {
        if let contextError {
            throw contextError
        }

        return snapshot
    }

    func writeEpisode(id: UUID, draft: EpisodeDraft) async throws {
        writtenEpisodeID = id
        if let writeError {
            throw writeError
        }
    }
}
