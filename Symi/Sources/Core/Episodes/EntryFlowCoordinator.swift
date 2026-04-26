import Foundation
import Observation

enum EntryFlowStep: String, CaseIterable, Identifiable, Hashable, Sendable {
    case headache
    case medication
    case triggers
    case note
    case review

    var id: String { rawValue }
}

enum EntryFlowSaveResult: Equatable, Sendable {
    case saved(UUID)
    case failed(String)
}

enum EntryStartedAtPreset: String, CaseIterable, Identifiable, Sendable {
    case now
    case oneHourAgo
    case todayMorning
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .now:
            "Jetzt"
        case .oneHourAgo:
            "Vor 1 Std."
        case .todayMorning:
            "Heute Morgen"
        case .custom:
            "Anderer Zeitpunkt"
        }
    }

    var dayPart: EpisodeDayPart? {
        switch self {
        case .todayMorning:
            .morgens
        case .now, .oneHourAgo, .custom:
            nil
        }
    }

    func date(relativeTo referenceDate: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .now:
            referenceDate
        case .oneHourAgo:
            referenceDate.addingTimeInterval(-3_600)
        case .todayMorning:
            calendar.date(bySettingHour: 8, minute: 0, second: 0, of: referenceDate) ?? referenceDate
        case .custom:
            referenceDate
        }
    }
}

@MainActor
@Observable
final class EntryContinuousMedicationController {
    private(set) var activeMedications: [ContinuousMedicationRecord] = []
    private let repository: ContinuousMedicationRepository

    init(repository: ContinuousMedicationRepository, autoload: Bool = true) {
        self.repository = repository

        guard autoload else {
            return
        }

        Task {
            await reload(for: .now)
        }
    }

    func reload(for date: Date) async {
        let repository = repository
        activeMedications = await Task.detached(priority: .userInitiated) {
            (try? repository.fetchActive(on: date)) ?? []
        }.value
    }

    func makeDefaultChecks() -> [ContinuousMedicationCheckDraft] {
        activeMedications.map { ContinuousMedicationCheckDraft(record: $0, wasTaken: true) }
    }
}

@MainActor
@Observable
final class EntryFlowCoordinator {
    static let steps: [EntryFlowStep] = [.headache, .medication, .triggers, .note, .review]

    let symptomOptions = [
        "Übelkeit",
        "Lichtempfindlichkeit",
        "Geräuschempfindlichkeit",
        "Aura",
        "Kiefer-/Aufbissschmerz",
        "Pochen, Pulsieren"
    ]
    let triggerOptions = ["Wetter", "Stress", "Erhöhte Arbeitsbelastung", "Regel", "Schlafdauer", "Sport", "Ernährung", "Bildschirmzeit", "Bewegung", "Flüssigkeit"]
    let painLocationOptions = ["Stirn", "Schläfen", "Nacken", "Einseitig", "Überall"]
    let medicationController: EpisodeMedicationSelectionController
    let continuousMedicationController: EntryContinuousMedicationController

    var draft: EpisodeDraft
    var path: [EntryFlowStep] = []
    var isSaving = false
    var saveResult: EntryFlowSaveResult?
    var weatherLoadState: WeatherLoadState = .idle
    private(set) var isCancelled = false

    private let initialStartedAt: Date?
    private let saveEpisodeUseCase: SaveEpisodeUseCase
    private let weatherContextService: any EpisodeWeatherContextProviding
    private let healthService: any HealthService

    init(
        initialStartedAt: Date? = nil,
        episodeRepository: EpisodeRepository,
        medicationRepository: MedicationCatalogRepository,
        continuousMedicationRepository: ContinuousMedicationRepository,
        weatherContextService: any EpisodeWeatherContextProviding,
        healthService: any HealthService,
        autoloadMedications: Bool = true
    ) {
        self.initialStartedAt = initialStartedAt
        self.draft = EpisodeDraft.makeNew(initialStartedAt: initialStartedAt)
        self.medicationController = EpisodeMedicationSelectionController(
            medicationRepository: medicationRepository,
            autoload: autoloadMedications
        )
        self.continuousMedicationController = EntryContinuousMedicationController(
            repository: continuousMedicationRepository,
            autoload: autoloadMedications
        )
        self.saveEpisodeUseCase = SaveEpisodeUseCase(repository: episodeRepository)
        self.weatherContextService = weatherContextService
        self.healthService = healthService
    }

    var currentStep: EntryFlowStep {
        path.last ?? .headache
    }

    var currentStepIndex: Int {
        Self.steps.firstIndex(of: currentStep).map { $0 + 1 } ?? 1
    }

    var canSkipCurrentStep: Bool {
        switch currentStep {
        case .headache, .review:
            false
        case .medication, .triggers, .note:
            true
        }
    }

    func continueToNextStep() {
        applyStepSideEffects()

        guard let nextStep else {
            return
        }

        path.append(nextStep)
    }

    func skipCurrentStep() {
        guard canSkipCurrentStep else {
            return
        }

        switch currentStep {
        case .medication:
            medicationController.resetSelections()
            draft.medications = []
            draft.continuousMedicationChecks = []
        case .triggers:
            draft.selectedTriggers = []
        case .note:
            draft.notes = ""
        case .headache, .review:
            break
        }

        continueToNextStep()
    }

    func edit(_ step: EntryFlowStep) {
        guard step != .review, Self.steps.contains(step) else {
            return
        }

        path = Array(Self.steps.prefix { $0 != step }.dropFirst()) + [step]
    }

    func cancel() {
        isCancelled = true
        path = []
        draft = EpisodeDraft.makeNew(initialStartedAt: initialStartedAt)
        medicationController.resetSelections()
        weatherLoadState = .idle
        saveResult = nil
        isSaving = false
    }

    func saveHeadacheOnly() {
        save(resetAfterSave: false)
    }

    func saveFromReview() {
        save(resetAfterSave: false)
    }

    func selectStartedAtPreset(_ preset: EntryStartedAtPreset, calendar: Calendar = .current) {
        draft.startedAt = preset.date(relativeTo: .now, calendar: calendar)
        weatherLoadState = .idle
    }

    func refreshWeatherIfNeeded() async {
        guard weatherLoadState == .idle else {
            return
        }

        weatherLoadState = .loading
        weatherLoadState = await weatherContextService.loadWeather(
            for: draft.startedAt,
            originalStartedAt: nil,
            originalSnapshot: nil
        )
    }

    private var nextStep: EntryFlowStep? {
        guard let currentIndex = Self.steps.firstIndex(of: currentStep) else {
            return nil
        }

        let nextIndex = currentIndex + 1
        guard nextIndex < Self.steps.count else {
            return nil
        }

        return Self.steps[nextIndex]
    }

    private func applyStepSideEffects() {
        if currentStep == .headache {
            draft.type = .headache
            draft.intensity = draft.normalizedIntensity
            draft.painLocation = draft.resolvedPainLocation
        }

        if currentStep == .medication {
            draft.medications = medicationController.medications
            if draft.continuousMedicationChecks.isEmpty {
                draft.continuousMedicationChecks = continuousMedicationController.makeDefaultChecks()
            }
        }
    }

    private func makeDraftForSave() -> EpisodeDraft {
        var draftForSave = draft
        draftForSave.type = .headache
        draftForSave.intensity = draftForSave.normalizedIntensity
        draftForSave.painLocation = draftForSave.resolvedPainLocation
        draftForSave.medications = medicationController.medications

        if currentStep == .medication, draftForSave.continuousMedicationChecks.isEmpty {
            draftForSave.continuousMedicationChecks = continuousMedicationController.makeDefaultChecks()
        }

        return draftForSave
    }

    private func save(resetAfterSave: Bool) {
        guard !isSaving else {
            return
        }

        let draftForSave = makeDraftForSave()
        draft = draftForSave
        saveResult = nil
        isSaving = true

        Task {
            defer { isSaving = false }

            do {
                let weatherSnapshot = try await weatherSnapshotForSave(startedAt: draftForSave.startedAt)
                let healthContext = await healthContextForSave(draft: draftForSave)
                let savedID = try await saveEpisodeUseCase.execute(
                    draftForSave,
                    weatherSnapshot: weatherSnapshot,
                    healthContext: healthContext
                )
                await writeHealthSampleIfNeeded(episodeID: savedID, draft: draftForSave)
                saveResult = .saved(savedID)

                if resetAfterSave {
                    cancel()
                    isCancelled = false
                }
            } catch {
                saveResult = .failed(saveFailureMessage(for: error))
            }
        }
    }

    private func weatherSnapshotForSave(startedAt: Date) async throws -> WeatherSnapshotData? {
        let resolution = try await weatherContextService.snapshotForSave(
            startedAt: startedAt,
            currentState: weatherLoadState,
            originalStartedAt: nil,
            originalSnapshot: nil
        )
        weatherLoadState = resolution.state
        return resolution.snapshot
    }

    private func healthContextForSave(draft: EpisodeDraft) async -> HealthContextSnapshotData? {
        do {
            return try await healthService.contextSnapshot(for: draft)
        } catch {
            return nil
        }
    }

    private func writeHealthSampleIfNeeded(episodeID: UUID, draft: EpisodeDraft) async {
        do {
            try await healthService.writeEpisode(id: episodeID, draft: draft)
        } catch {}
    }

    private func saveFailureMessage(for error: Error) -> String {
        if let episodeError = error as? EpisodeSaveError {
            switch episodeError {
            case .invalidDateRange:
                return "Bitte prüfe Beginn und Ende deines Eintrags."
            case .futureDate:
                return "Bitte wähle einen Zeitpunkt, der nicht in der Zukunft liegt."
            }
        }

        if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription {
            return description
        }

        return "Der Eintrag konnte gerade nicht gespeichert werden. Bitte versuche es noch einmal."
    }
}
