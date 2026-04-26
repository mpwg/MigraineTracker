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

    var draft: EpisodeDraft
    var path: [EntryFlowStep] = []
    var isSaving = false
    var saveResult: EntryFlowSaveResult?
    private(set) var isCancelled = false

    private let initialStartedAt: Date?
    private let saveEpisodeUseCase: SaveEpisodeUseCase

    init(
        initialStartedAt: Date? = nil,
        episodeRepository: EpisodeRepository,
        medicationRepository: MedicationCatalogRepository,
        autoloadMedications: Bool = true
    ) {
        self.initialStartedAt = initialStartedAt
        self.draft = EpisodeDraft.makeNew(initialStartedAt: initialStartedAt)
        self.medicationController = EpisodeMedicationSelectionController(
            medicationRepository: medicationRepository,
            autoload: autoloadMedications
        )
        self.saveEpisodeUseCase = SaveEpisodeUseCase(repository: episodeRepository)
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
        }
    }

    private func save(resetAfterSave: Bool) {
        guard !isSaving else {
            return
        }

        applyStepSideEffects()
        saveResult = nil
        isSaving = true

        Task {
            defer { isSaving = false }

            do {
                let savedID = try await saveEpisodeUseCase.execute(draft, weatherSnapshot: nil, healthContext: nil)
                saveResult = .saved(savedID)

                if resetAfterSave {
                    cancel()
                    isCancelled = false
                }
            } catch {
                saveResult = .failed(error.localizedDescription)
            }
        }
    }
}
