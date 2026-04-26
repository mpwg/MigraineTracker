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
    func startedAtPresetsUpdateDraftTime() {
        let calendar = Calendar(identifier: .gregorian)
        let coordinator = makeCoordinator()
        let referenceDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 26, hour: 15, minute: 30))!

        coordinator.selectStartedAtPreset(.todayMorning, calendar: calendar)
        let morningHour = calendar.component(.hour, from: coordinator.draft.startedAt)

        #expect(EntryStartedAtPreset.todayMorning.dayPart == .morgens)
        #expect(morningHour == 8)
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
        #expect(coordinator.draft.intensity == 5)
    }

    private func makeCoordinator(
        repository: EntryFlowEpisodeRepositoryMock = EntryFlowEpisodeRepositoryMock(),
        medicationRepository: EntryFlowMedicationRepositoryMock = EntryFlowMedicationRepositoryMock()
    ) -> EntryFlowCoordinator {
        EntryFlowCoordinator(
            episodeRepository: repository,
            medicationRepository: medicationRepository,
            autoloadMedications: false
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

    func fetchRecent() throws -> [EpisodeRecord] { [] }
    func fetchByDay(_ day: Date) throws -> [EpisodeRecord] { [] }
    func fetchByMonth(_ month: Date) throws -> [EpisodeRecord] { [] }
    func load(id: UUID) throws -> EpisodeRecord? { nil }

    func save(draft: EpisodeDraft, weatherSnapshot: WeatherSnapshotData?, healthContext: HealthContextSnapshotData?) throws -> UUID {
        lastSavedDraft = draft
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
