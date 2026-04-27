import Foundation
import Observation

enum WeatherLoadState: Equatable {
    case idle
    case loading
    case loaded(WeatherSnapshotData)
    case unavailable(String)
}

enum EpisodeEditorMode {
    case create
    case edit
}

struct CustomMedicationEditorSheetState: Identifiable, Equatable {
    let id: String
    let originalSelectionKey: String?
    let initialName: String
    let initialCategory: MedicationCategory
    let initialDosage: String

    init(definition: MedicationDefinitionRecord?) {
        id = definition?.catalogKey ?? UUID().uuidString
        originalSelectionKey = definition?.selectionKey
        initialName = definition?.name ?? ""
        initialCategory = definition?.category ?? .other
        initialDosage = definition?.suggestedDosage ?? ""
    }

    var isEditing: Bool {
        originalSelectionKey != nil
    }
}

struct EpisodeEditorMedicationGroup: Identifiable, Equatable, Sendable {
    nonisolated let id: String
    nonisolated let title: String
    nonisolated let footer: String?
    nonisolated let items: [MedicationDefinitionRecord]
}

@MainActor
@Observable
final class EpisodeMedicationSelectionController {
    var searchText = ""
    var validationMessage: String?
    var customMedicationEditor: CustomMedicationEditorSheetState?
    var pendingMedicationDeletion: MedicationDefinitionRecord?

    private(set) var medicationDefinitions: [MedicationDefinitionRecord] = []
    private(set) var medications: [MedicationSelectionDraft]
    private var selectedMedicationKeys: Set<String> = []
    private var medicationSelectionIndicesByKey: [String: Int] = [:]
    private var selectedMedicationsCache: [MedicationSelectionDraft] = []
    private var allMedicationGroupsCache: [EpisodeEditorMedicationGroup] = []

    private let medicationRepository: MedicationCatalogRepository

    init(
        medicationRepository: MedicationCatalogRepository,
        initialMedications: [MedicationSelectionDraft] = [],
        autoload: Bool = true
    ) {
        self.medicationRepository = medicationRepository
        self.medications = initialMedications
        rebuildCaches()

        guard autoload else {
            return
        }

        Task {
            await reloadDefinitions()
        }
    }

    var filteredMedicationGroups: [EpisodeEditorMedicationGroup] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let groups = allMedicationGroupsCache

        guard !query.isEmpty else {
            return groups
        }

        return groups.compactMap { group in
            let items = group.items.filter { $0.name.localizedCaseInsensitiveContains(query) }
            guard !items.isEmpty else {
                return nil
            }

            return EpisodeEditorMedicationGroup(
                id: group.id,
                title: group.title,
                footer: group.footer,
                items: items
            )
        }
    }

    var selectedMedications: [MedicationSelectionDraft] {
        selectedMedicationsCache
    }

    func replaceSelections(_ selections: [MedicationSelectionDraft]) {
        medications = selections
        rebuildCaches()
    }

    func resetSelections() {
        searchText = ""
        customMedicationEditor = nil
        pendingMedicationDeletion = nil
        replaceSelections([])
    }

    func reloadDefinitions() async {
        let repository = medicationRepository
        let definitions = await PerformanceInstrumentation.measure("MedicationDefinitionsReload") {
            await Task.detached(priority: .userInitiated) {
                PerformanceInstrumentation.measure("MedicationRepositoryFetchDefinitions") {
                    (try? repository.fetchDefinitions(searchText: nil)) ?? []
                }
            }.value
        }
        medicationDefinitions = definitions
        rebuildCaches()
    }

    func isMedicationSelected(_ definition: MedicationDefinitionRecord) -> Bool {
        selectedMedicationKeys.contains(definition.selectionKey)
    }

    func isMedicationNameSelected(_ name: String) -> Bool {
        medications.contains {
            $0.isSelected && $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    func quantity(for definition: MedicationDefinitionRecord) -> Int {
        guard let index = medicationSelectionIndicesByKey[definition.selectionKey] else {
            return 1
        }

        return medications[index].quantity
    }

    func toggleMedicationSelection(for definition: MedicationDefinitionRecord) {
        if let index = medicationSelectionIndicesByKey[definition.selectionKey] {
            medications[index].isSelected.toggle()
            medications[index].quantity = max(1, medications[index].quantity)
        } else {
            medications.append(MedicationSelectionDraft(definition: definition))
        }
        rebuildCaches()
    }

    func toggleMedicationSelection(named name: String, fallbackCategory: MedicationCategory = .other, fallbackDosage: String = "") {
        if let definition = medicationDefinitions.first(where: {
            $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) {
            toggleMedicationSelection(for: definition)
            return
        }

        let selectionKey = MedicationSelectionDraft.makeSelectionKey(
            name: name,
            category: fallbackCategory,
            dosage: fallbackDosage
        )
        if let index = medicationSelectionIndicesByKey[selectionKey] {
            medications[index].isSelected.toggle()
        } else {
            medications.append(
                MedicationSelectionDraft(
                    selectionKey: selectionKey,
                    name: name,
                    category: fallbackCategory,
                    dosage: fallbackDosage
                )
            )
        }
        rebuildCaches()
    }

    func incrementMedicationQuantity(for definition: MedicationDefinitionRecord) {
        if let index = medicationSelectionIndicesByKey[definition.selectionKey] {
            medications[index].quantity += 1
            medications[index].isSelected = true
        } else {
            medications.append(MedicationSelectionDraft(definition: definition))
        }
        rebuildCaches()
    }

    func decrementMedicationQuantity(for definition: MedicationDefinitionRecord) {
        guard let index = medicationSelectionIndicesByKey[definition.selectionKey] else {
            return
        }

        medications[index].quantity = max(1, medications[index].quantity - 1)
        medications[index].isSelected = true
        rebuildCaches()
    }

    func removeMedicationSelection(id: UUID) {
        guard let index = medications.firstIndex(where: { $0.id == id }) else {
            return
        }

        medications[index].isSelected = false
        medications[index].quantity = 1
        rebuildCaches()
    }

    func updateDosageForSelectedMedications(_ dosage: String) {
        let trimmedDosage = dosage.trimmingCharacters(in: .whitespacesAndNewlines)
        for index in medications.indices where medications[index].isSelected {
            medications[index].dosage = trimmedDosage
        }
        rebuildCaches()
    }

    func updateDosage(forMedicationNamed name: String, dosage: String) {
        let trimmedDosage = dosage.trimmingCharacters(in: .whitespacesAndNewlines)
        for index in medications.indices
            where medications[index].isSelected
                && medications[index].name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame {
            medications[index].dosage = trimmedDosage
        }
        rebuildCaches()
    }

    func presentEditor(for definition: MedicationDefinitionRecord?) {
        customMedicationEditor = CustomMedicationEditorSheetState(definition: definition)
    }

    func saveCustomMedication(from draft: CustomMedicationDefinitionDraft) async {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            validationMessage = "Bitte gib einen Namen für das eigene Medikament ein."
            return
        }

        if let existing = medicationDefinitions.first(where: {
            $0.catalogKey != draft.id &&
                $0.name.compare(trimmedName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) {
            toggleMedicationSelection(for: existing)
            customMedicationEditor = nil
            validationMessage = nil
            return
        }

        let repository = medicationRepository
        do {
            let definition = try await Task.detached(priority: .userInitiated) {
                try repository.saveCustomDefinition(draft)
            }.value
            await reloadDefinitions()
            customMedicationEditor = nil
            validationMessage = nil

            if let existingSelectionKey = draft.originalSelectionKey {
                updateMedicationSelection(from: existingSelectionKey, to: definition)
            } else {
                toggleMedicationSelection(for: definition)
            }
        } catch {
            validationMessage = "Eigenes Medikament konnte nicht gespeichert werden."
        }
    }

    func deleteCustomMedication(_ definition: MedicationDefinitionRecord) async {
        medications.removeAll { $0.selectionKey == definition.selectionKey }
        rebuildCaches()

        let repository = medicationRepository
        let catalogKey = definition.catalogKey
        do {
            try await Task.detached(priority: .userInitiated) {
                try repository.softDeleteCustomDefinition(catalogKey: catalogKey)
            }.value
            await reloadDefinitions()
            pendingMedicationDeletion = nil
            validationMessage = nil
        } catch {
            validationMessage = "Eigenes Medikament konnte nicht gelöscht werden."
        }
    }

    private func rebuildCaches() {
        rebuildSelectionCache()
        rebuildGroupCache()
    }

    private func rebuildSelectionCache() {
        medicationSelectionIndicesByKey = medications.enumerated().reduce(into: [:]) { result, item in
            let (index, medication) = item
            result[medication.selectionKey] = index
        }
        selectedMedicationKeys = Set(medications.filter(\.isSelected).map(\.selectionKey))
        selectedMedicationsCache = medications
            .filter(\.isSelected)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func rebuildGroupCache() {
        let knownKeys = Set(medicationDefinitions.map(\.selectionKey))
        let persistedGroups = Dictionary(grouping: medicationDefinitions) { $0.groupID }
        let sortedGroupIDs = persistedGroups.keys.sorted { lhs, rhs in
            let leftOrder = persistedGroups[lhs]?.map(\.sortOrder).min() ?? .max
            let rightOrder = persistedGroups[rhs]?.map(\.sortOrder).min() ?? .max
            return leftOrder < rightOrder
        }

        var groups = sortedGroupIDs.compactMap { groupID -> EpisodeEditorMedicationGroup? in
            guard let items = persistedGroups[groupID], let first = items.first else {
                return nil
            }

            return EpisodeEditorMedicationGroup(
                id: groupID,
                title: first.groupTitle,
                footer: first.groupFooter,
                items: items.sorted { $0.sortOrder < $1.sortOrder }
            )
        }

        let orphanSelections = medications.compactMap { selection -> MedicationDefinitionRecord? in
            guard !knownKeys.contains(selection.selectionKey) else {
                return nil
            }

            return MedicationDefinitionRecord(
                catalogKey: "selection:\(selection.selectionKey)",
                groupID: "custom-medications",
                groupTitle: "Eigene Medikamente",
                groupFooter: "Eigene Medikamente werden lokal in SwiftData gespeichert und bleiben in deiner persönlichen Auswahlliste verfügbar.",
                name: selection.name,
                category: selection.category,
                suggestedDosage: selection.dosage,
                sortOrder: Int.max - 1,
                isCustom: true,
                isDeleted: false
            )
        }

        if !orphanSelections.isEmpty {
            groups.removeAll { $0.id == "custom-medications" }
            let customItems = (persistedGroups["custom-medications"] ?? []) + orphanSelections
            let deduped = Dictionary(uniqueKeysWithValues: customItems.map { ($0.selectionKey, $0) }).values
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            groups.append(
                EpisodeEditorMedicationGroup(
                    id: "custom-medications",
                    title: "Eigene Medikamente",
                    footer: "Eigene Medikamente werden lokal in SwiftData gespeichert und bleiben in deiner persönlichen Auswahlliste verfügbar.",
                    items: deduped
                )
            )
        }

        allMedicationGroupsCache = groups
    }

    private func updateMedicationSelection(from oldSelectionKey: String, to definition: MedicationDefinitionRecord) {
        guard let index = medications.firstIndex(where: { $0.selectionKey == oldSelectionKey }) else {
            return
        }

        medications[index].selectionKey = definition.selectionKey
        medications[index].name = definition.name
        medications[index].category = definition.category
        medications[index].dosage = definition.suggestedDosage
        medications[index].isSelected = true
        rebuildCaches()
    }
}

@MainActor
@Observable
final class EpisodeEditorController {
    let mode: EpisodeEditorMode
    let symptomOptions = [
        "Übelkeit",
        "Lichtempfindlichkeit",
        "Geräuschempfindlichkeit",
        "Aura",
        "Kiefer-/Aufbissschmerz",
        "Pochen, Pulsieren"
    ]
    let triggerOptions = ["Wetter", "Stress", "Erhöhte Arbeitsbelastung", "Regel", "Schlafdauer", "Sport", "Ernährung", "Bildschirmzeit", "Bewegung", "Flüssigkeit"]
    let medicationController: EpisodeMedicationSelectionController

    var draft: EpisodeDraft
    var saveMessageVisible = false
    var isSaving = false
    var weatherLoadState: WeatherLoadState = .idle

    private var saveValidationMessage: String?
    private let saveEpisodeUseCase: SaveEpisodeUseCase
    private let episodeRepository: EpisodeRepository
    private let weatherContextService: any EpisodeWeatherContextProviding
    private let healthService: any HealthService
    private var originalStartedAt: Date?
    private var originalWeatherSnapshot: WeatherSnapshotData?

    init(
        episodeID: UUID?,
        initialStartedAt: Date?,
        episodeRepository: EpisodeRepository,
        medicationRepository: MedicationCatalogRepository,
        weatherContextService: any EpisodeWeatherContextProviding,
        healthService: any HealthService
    ) {
        self.episodeRepository = episodeRepository
        self.weatherContextService = weatherContextService
        self.healthService = healthService
        self.medicationController = EpisodeMedicationSelectionController(medicationRepository: medicationRepository)
        self.saveEpisodeUseCase = SaveEpisodeUseCase(repository: episodeRepository)

        if let episodeID {
            self.mode = .edit
            self.draft = EpisodeDraft.makeNew(initialStartedAt: initialStartedAt)
            self.originalStartedAt = nil
            self.originalWeatherSnapshot = nil
            Task { await loadEpisode(id: episodeID) }
        } else {
            self.mode = .create
            if AppStoreScreenshotMode.isEnabled {
                let screenshotDraft = AppStoreScreenshotMode.sampleDraft(initialStartedAt: initialStartedAt)
                self.draft = screenshotDraft
                self.weatherLoadState = .loaded(AppStoreScreenshotMode.sampleWeatherSnapshot(for: screenshotDraft.startedAt))
            } else {
                self.draft = EpisodeDraft.makeNew(initialStartedAt: initialStartedAt)
            }
            self.originalStartedAt = nil
            self.originalWeatherSnapshot = nil
        }
    }

    var validationMessage: String? {
        saveValidationMessage ?? medicationController.validationMessage
    }

    func save(onSaved: (() -> Void)?, onDismiss: @escaping () -> Void) {
        guard !isSaving else {
            return
        }

        saveValidationMessage = nil
        medicationController.validationMessage = nil
        isSaving = true

        Task {
            await PerformanceInstrumentation.measure("EpisodeEditorSave") {
                defer { isSaving = false }

                do {
                    let draftForSave = makeDraftForSave()
                    let weatherSnapshot = try await weatherSnapshotForSave(startedAt: draftForSave.startedAt)
                    let healthContext = await healthContextForSave(draft: draftForSave)
                    let savedID = try await saveEpisodeUseCase.execute(draftForSave, weatherSnapshot: weatherSnapshot, healthContext: healthContext)
                    await writeHealthSampleIfNeeded(episodeID: savedID, draft: draftForSave)
                    await medicationController.reloadDefinitions()
                    saveValidationMessage = nil

                    if mode == .create, onSaved == nil {
                        draft = EpisodeDraft.makeNew()
                        medicationController.resetSelections()
                        weatherLoadState = .idle
                        saveMessageVisible = true
                    } else {
                        onSaved?()
                        onDismiss()
                    }
                } catch {
                    saveValidationMessage = error.localizedDescription
                }
            }
        }
    }

    func refreshWeather() async {
        weatherLoadState = .loading
        weatherLoadState = await weatherContextService.loadWeather(
            for: draft.startedAt,
            originalStartedAt: originalStartedAt,
            originalSnapshot: originalWeatherSnapshot
        )
    }

    private func loadEpisode(id: UUID) async {
        let record = await PerformanceInstrumentation.measure("EpisodeEditorLoad") {
            let repository = episodeRepository
            return await Task.detached(priority: .userInitiated) {
                PerformanceInstrumentation.measure("EpisodeRepositoryLoad") {
                    try? repository.load(id: id)
                }
            }.value
        }

        guard let record else {
            return
        }

        let loadedDraft = EpisodeDraft.from(record: record)
        draft = loadedDraft
        medicationController.replaceSelections(loadedDraft.medications)
        originalStartedAt = record.startedAt
        originalWeatherSnapshot = record.weather.map(WeatherSnapshotData.init)
        weatherLoadState = record.weather.map { .loaded(WeatherSnapshotData(record: $0)) } ?? .idle
    }

    private func makeDraftForSave() -> EpisodeDraft {
        var draftForSave = draft
        draftForSave.medications = medicationController.medications
        return draftForSave
    }

    private func weatherSnapshotForSave(startedAt: Date) async throws -> WeatherSnapshotData? {
        let resolution = try await weatherContextService.snapshotForSave(
            startedAt: startedAt,
            currentState: weatherLoadState,
            originalStartedAt: originalStartedAt,
            originalSnapshot: originalWeatherSnapshot
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
}
