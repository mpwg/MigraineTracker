import Foundation
import Observation

struct WeatherRecord: Equatable, Sendable {
    nonisolated let recordedAt: Date
    nonisolated let condition: String
    nonisolated let temperature: Double?
    nonisolated let humidity: Double?
    nonisolated let pressure: Double?
    nonisolated let precipitation: Double?
    nonisolated let weatherCode: Int?
    nonisolated let source: String

    nonisolated var isLegacySnapshot: Bool {
        source.localizedCaseInsensitiveContains("legacy") || source.localizedCaseInsensitiveContains("manuell")
    }
}

struct MedicationRecord: Identifiable, Equatable, Sendable {
    nonisolated let id: UUID
    nonisolated let name: String
    nonisolated let category: MedicationCategory
    nonisolated let dosage: String
    nonisolated let quantity: Int
    nonisolated let takenAt: Date
    nonisolated let effectiveness: MedicationEffectiveness
    nonisolated let reliefStartedAt: Date?
    nonisolated let isRepeatDose: Bool
}

struct EpisodeRecord: Identifiable, Equatable, Sendable {
    nonisolated let id: UUID
    nonisolated let startedAt: Date
    nonisolated let endedAt: Date?
    nonisolated let updatedAt: Date
    nonisolated let deletedAt: Date?
    nonisolated let type: EpisodeType
    nonisolated let intensity: Int
    nonisolated let painLocation: String
    nonisolated let painCharacter: String
    nonisolated let notes: String
    nonisolated let symptoms: [String]
    nonisolated let triggers: [String]
    nonisolated let functionalImpact: String
    nonisolated let menstruationStatus: MenstruationStatus
    nonisolated let medications: [MedicationRecord]
    nonisolated let weather: WeatherRecord?
    nonisolated let healthContext: HealthContextRecord?

    nonisolated var isDeleted: Bool {
        deletedAt != nil
    }
}

struct MedicationDefinitionRecord: Identifiable, Equatable, Sendable {
    nonisolated let id: String
    nonisolated let catalogKey: String
    nonisolated let groupID: String
    nonisolated let groupTitle: String
    nonisolated let groupFooter: String?
    nonisolated let name: String
    nonisolated let category: MedicationCategory
    nonisolated let suggestedDosage: String
    nonisolated let sortOrder: Int
    nonisolated let isCustom: Bool
    nonisolated let isDeleted: Bool

    nonisolated init(
        catalogKey: String,
        groupID: String,
        groupTitle: String,
        groupFooter: String?,
        name: String,
        category: MedicationCategory,
        suggestedDosage: String,
        sortOrder: Int,
        isCustom: Bool,
        isDeleted: Bool
    ) {
        self.id = catalogKey
        self.catalogKey = catalogKey
        self.groupID = groupID
        self.groupTitle = groupTitle
        self.groupFooter = groupFooter
        self.name = name
        self.category = category
        self.suggestedDosage = suggestedDosage
        self.sortOrder = sortOrder
        self.isCustom = isCustom
        self.isDeleted = isDeleted
    }

    nonisolated var selectionKey: String {
        [
            name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            category.rawValue,
            suggestedDosage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        ].joined(separator: "|")
    }
}

struct MedicationSelectionDraft: Identifiable, Equatable, Sendable {
    nonisolated let id: UUID
    nonisolated var selectionKey: String
    nonisolated var name: String
    nonisolated var category: MedicationCategory
    nonisolated var dosage: String
    nonisolated var quantity: Int
    nonisolated var isSelected: Bool

    nonisolated init(
        id: UUID = UUID(),
        selectionKey: String,
        name: String,
        category: MedicationCategory,
        dosage: String,
        quantity: Int = 1,
        isSelected: Bool = true
    ) {
        self.id = id
        self.selectionKey = selectionKey
        self.name = name
        self.category = category
        self.dosage = dosage
        self.quantity = max(1, quantity)
        self.isSelected = isSelected
    }

    nonisolated init(record: MedicationRecord) {
        self.init(
            id: record.id,
            selectionKey: Self.makeSelectionKey(
                name: record.name,
                category: record.category,
                dosage: record.dosage
            ),
            name: record.name,
            category: record.category,
            dosage: record.dosage,
            quantity: record.quantity
        )
    }

    nonisolated init(definition: MedicationDefinitionRecord) {
        self.init(
            selectionKey: definition.selectionKey,
            name: definition.name,
            category: definition.category,
            dosage: definition.suggestedDosage
        )
    }

    nonisolated static func makeSelectionKey(name: String, category: MedicationCategory, dosage: String) -> String {
        [
            name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            category.rawValue,
            dosage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        ].joined(separator: "|")
    }
}

struct EpisodeDraft: Equatable, Sendable {
    nonisolated var id: UUID?
    nonisolated var type: EpisodeType
    nonisolated var intensity: Int
    nonisolated var startedAt: Date
    nonisolated var endedAtEnabled: Bool
    nonisolated var endedAt: Date
    nonisolated var painLocation: String
    nonisolated var painCharacter: String
    nonisolated var notes: String
    nonisolated var functionalImpact: String
    nonisolated var menstruationStatus: MenstruationStatus
    nonisolated var selectedSymptoms: Set<String>
    nonisolated var selectedTriggers: Set<String>
    nonisolated var medications: [MedicationSelectionDraft]

    nonisolated static func makeNew(initialStartedAt: Date? = nil) -> EpisodeDraft {
        let startedAt = initialStartedAt ?? .now
        return EpisodeDraft(
            id: nil,
            type: .unclear,
            intensity: 5,
            startedAt: startedAt,
            endedAtEnabled: false,
            endedAt: startedAt,
            painLocation: "",
            painCharacter: "",
            notes: "",
            functionalImpact: "",
            menstruationStatus: .unknown,
            selectedSymptoms: [],
            selectedTriggers: [],
            medications: []
        )
    }

    nonisolated static func from(record: EpisodeRecord) -> EpisodeDraft {
        EpisodeDraft(
            id: record.id,
            type: record.type,
            intensity: record.intensity,
            startedAt: record.startedAt,
            endedAtEnabled: record.endedAt != nil,
            endedAt: record.endedAt ?? record.startedAt,
            painLocation: record.painLocation,
            painCharacter: record.painCharacter,
            notes: record.notes,
            functionalImpact: record.functionalImpact,
            menstruationStatus: record.menstruationStatus,
            selectedSymptoms: Set(record.symptoms),
            selectedTriggers: Set(record.triggers),
            medications: record.medications.map(MedicationSelectionDraft.init(record:))
        )
    }
}

struct CustomMedicationDefinitionDraft: Equatable, Sendable {
    nonisolated let id: String
    nonisolated let originalSelectionKey: String?
    nonisolated let name: String
    nonisolated let category: MedicationCategory
    nonisolated let dosage: String
}

struct EpisodeEditorMedicationGroup: Identifiable, Equatable, Sendable {
    nonisolated let id: String
    nonisolated let title: String
    nonisolated let footer: String?
    nonisolated let items: [MedicationDefinitionRecord]
}

protocol EpisodeRepository: Sendable {
    nonisolated func fetchRecent() throws -> [EpisodeRecord]
    nonisolated func fetchByDay(_ day: Date) throws -> [EpisodeRecord]
    nonisolated func fetchByMonth(_ month: Date) throws -> [EpisodeRecord]
    nonisolated func load(id: UUID) throws -> EpisodeRecord?
    @discardableResult
    nonisolated func save(draft: EpisodeDraft, weatherSnapshot: WeatherSnapshotData?, healthContext: HealthContextSnapshotData?) throws -> UUID
    nonisolated func softDelete(id: UUID) throws
    nonisolated func restore(id: UUID) throws
    nonisolated func fetchDeleted() throws -> [EpisodeRecord]
}

protocol MedicationCatalogRepository: Sendable {
    nonisolated func fetchDefinitions(searchText: String?) throws -> [MedicationDefinitionRecord]
    nonisolated func saveCustomDefinition(_ draft: CustomMedicationDefinitionDraft) throws -> MedicationDefinitionRecord
    nonisolated func softDeleteCustomDefinition(catalogKey: String) throws
    nonisolated func fetchDeletedDefinitions() throws -> [MedicationDefinitionRecord]
}

struct SaveEpisodeUseCase {
    let repository: EpisodeRepository

    @discardableResult
    func execute(_ draft: EpisodeDraft, weatherSnapshot: WeatherSnapshotData?, healthContext: HealthContextSnapshotData? = nil) async throws -> UUID {
        if draft.endedAtEnabled, draft.endedAt < draft.startedAt {
            throw EpisodeSaveError.invalidDateRange
        }

        if draft.startedAt > .now {
            throw EpisodeSaveError.futureDate
        }

        let repository = repository
        return try await Task.detached(priority: .userInitiated) {
            try repository.save(draft: draft, weatherSnapshot: weatherSnapshot, healthContext: healthContext)
        }.value
    }
}

struct HomeOverviewData: Equatable {
    let latestEpisode: EpisodeRecord?
    let episodeCount: Int
}

struct LoadHomeOverviewUseCase {
    let repository: EpisodeRepository

    func execute() async throws -> HomeOverviewData {
        let repository = repository
        let episodes = try await Task.detached(priority: .userInitiated) {
            try repository.fetchRecent()
        }.value
        return HomeOverviewData(
            latestEpisode: episodes.first,
            episodeCount: episodes.count
        )
    }
}

enum EpisodeSaveError: LocalizedError {
    case invalidDateRange
    case futureDate

    var errorDescription: String? {
        switch self {
        case .invalidDateRange:
            "Das Ende darf nicht vor dem Beginn liegen."
        case .futureDate:
            "Eine Episode kann nicht in der Zukunft erfasst werden."
        }
    }
}

enum WeatherLoadState: Equatable {
    case idle
    case loading
    case loaded(WeatherSnapshotData)
    case unavailable(String)
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
    let triggerOptions = ["Stress", "Schlafmangel", "Alkohol", "Menstruation", "Bildschirmzeit"]

    var draft: EpisodeDraft
    var medicationSearchText = ""
    var saveMessageVisible = false
    var isSaving = false
    var validationMessage: String?
    var weatherLoadState: WeatherLoadState = .idle
    var customMedicationEditor: CustomMedicationEditorSheetState?
    var pendingMedicationDeletion: MedicationDefinitionRecord?
    private(set) var medicationDefinitions: [MedicationDefinitionRecord] = []
    private var selectedMedicationKeys: Set<String> = []
    private var medicationSelectionIndicesByKey: [String: Int] = [:]
    private var selectedMedicationsCache: [MedicationSelectionDraft] = []
    private var allMedicationGroupsCache: [EpisodeEditorMedicationGroup] = []

    private let saveEpisodeUseCase: SaveEpisodeUseCase
    private let episodeRepository: EpisodeRepository
    private let medicationRepository: MedicationCatalogRepository
    private let weatherService: WeatherService
    private let locationService: LocationService
    private let healthService: HealthService
    private var originalStartedAt: Date?
    private var originalWeatherSnapshot: WeatherSnapshotData?

    init(
        episodeID: UUID?,
        initialStartedAt: Date?,
        episodeRepository: EpisodeRepository,
        medicationRepository: MedicationCatalogRepository,
        weatherService: WeatherService,
        locationService: LocationService,
        healthService: HealthService
    ) {
        self.episodeRepository = episodeRepository
        self.medicationRepository = medicationRepository
        self.weatherService = weatherService
        self.locationService = locationService
        self.healthService = healthService
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

        rebuildMedicationCaches()
        reloadMedicationDefinitions()
    }

    var filteredMedicationGroups: [EpisodeEditorMedicationGroup] {
        let query = medicationSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
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

    func reloadMedicationDefinitions() {
        let repository = medicationRepository
        Task {
            let definitions = await Task.detached(priority: .userInitiated) {
                (try? repository.fetchDefinitions(searchText: nil)) ?? []
            }.value
            medicationDefinitions = definitions
            rebuildMedicationCaches()
        }
    }

    private func loadEpisode(id: UUID) async {
        let repository = episodeRepository
        let record = await Task.detached(priority: .userInitiated) {
            try? repository.load(id: id)
        }.value

        guard let record else {
            return
        }

        draft = EpisodeDraft.from(record: record)
        originalStartedAt = record.startedAt
        originalWeatherSnapshot = record.weather.map(WeatherSnapshotData.init)
        weatherLoadState = record.weather.map { .loaded(WeatherSnapshotData(record: $0)) } ?? .idle
        rebuildMedicationCaches()
    }

    func save(onSaved: (() -> Void)?, onDismiss: @escaping () -> Void) {
        guard !isSaving else {
            return
        }

        validationMessage = nil
        isSaving = true

        Task {
            defer { isSaving = false }

            do {
                let weatherSnapshot = try await weatherSnapshotForSave()
                let healthContext = await healthContextForSave()
                let savedID = try await saveEpisodeUseCase.execute(draft, weatherSnapshot: weatherSnapshot, healthContext: healthContext)
                await writeHealthSampleIfNeeded(episodeID: savedID)
                reloadMedicationDefinitions()
                validationMessage = nil

                if mode == .create, onSaved == nil {
                    draft = EpisodeDraft.makeNew()
                    medicationSearchText = ""
                    customMedicationEditor = nil
                    pendingMedicationDeletion = nil
                    weatherLoadState = .idle
                    rebuildMedicationCaches()
                    saveMessageVisible = true
                } else {
                    onSaved?()
                    onDismiss()
                }
            } catch {
                validationMessage = error.localizedDescription
            }
        }
    }

    func refreshWeather() async {
        if AppStoreScreenshotMode.isEnabled {
            weatherLoadState = .loaded(AppStoreScreenshotMode.sampleWeatherSnapshot(for: draft.startedAt))
            return
        }

        if draft.startedAt > .now {
            weatherLoadState = .unavailable("Für zukünftige Zeitpunkte wird kein Wetter geladen.")
            return
        }

        if isStartedAtUnchanged, let originalWeatherSnapshot {
            weatherLoadState = .loaded(originalWeatherSnapshot)
            return
        }

        weatherLoadState = .loading

        do {
            let location = try await locationService.requestApproximateLocation()
            guard let snapshot = try await weatherService.fetchWeather(for: draft.startedAt, location: location) else {
                weatherLoadState = .unavailable("Für diesen Zeitpunkt konnten keine Wetterdaten geladen werden.")
                return
            }
            weatherLoadState = .loaded(snapshot)
        } catch let error as EpisodeSaveError {
            weatherLoadState = .unavailable(error.localizedDescription)
        } catch let error as any LocalizedError {
            weatherLoadState = .unavailable(error.errorDescription ?? "Wetterdaten konnten nicht geladen werden.")
        } catch {
            weatherLoadState = .unavailable("Wetterdaten konnten nicht geladen werden.")
        }
    }

    func isMedicationSelected(_ definition: MedicationDefinitionRecord) -> Bool {
        selectedMedicationKeys.contains(definition.selectionKey)
    }

    func quantity(for definition: MedicationDefinitionRecord) -> Int {
        guard let index = medicationSelectionIndicesByKey[definition.selectionKey] else {
            return 1
        }

        return draft.medications[index].quantity
    }

    func toggleMedicationSelection(for definition: MedicationDefinitionRecord) {
        if let index = medicationSelectionIndicesByKey[definition.selectionKey] {
            draft.medications[index].isSelected.toggle()
            draft.medications[index].quantity = max(1, draft.medications[index].quantity)
        } else {
            draft.medications.append(MedicationSelectionDraft(definition: definition))
        }
        rebuildMedicationCaches()
    }

    func incrementMedicationQuantity(for definition: MedicationDefinitionRecord) {
        if let index = medicationSelectionIndicesByKey[definition.selectionKey] {
            draft.medications[index].quantity += 1
            draft.medications[index].isSelected = true
        } else {
            draft.medications.append(MedicationSelectionDraft(definition: definition))
        }
        rebuildMedicationCaches()
    }

    func decrementMedicationQuantity(for definition: MedicationDefinitionRecord) {
        guard let index = medicationSelectionIndicesByKey[definition.selectionKey] else {
            return
        }

        draft.medications[index].quantity = max(1, draft.medications[index].quantity - 1)
        draft.medications[index].isSelected = true
        rebuildMedicationCaches()
    }

    func removeMedicationSelection(id: UUID) {
        guard let index = draft.medications.firstIndex(where: { $0.id == id }) else {
            return
        }

        draft.medications[index].isSelected = false
        draft.medications[index].quantity = 1
        rebuildMedicationCaches()
    }

    func presentEditor(for definition: MedicationDefinitionRecord?) {
        customMedicationEditor = CustomMedicationEditorSheetState(definition: definition)
    }

    func saveCustomMedication(from draft: CustomMedicationDefinitionDraft) {
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
        Task {
            do {
                let definition = try await Task.detached(priority: .userInitiated) {
                    try repository.saveCustomDefinition(draft)
                }.value
                reloadMedicationDefinitions()
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
    }

    func deleteCustomMedication(_ definition: MedicationDefinitionRecord) {
        draft.medications.removeAll { $0.selectionKey == definition.selectionKey }
        rebuildMedicationCaches()
        let repository = medicationRepository
        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try repository.softDeleteCustomDefinition(catalogKey: definition.catalogKey)
                }.value
                reloadMedicationDefinitions()
                pendingMedicationDeletion = nil
                validationMessage = nil
            } catch {
                validationMessage = "Eigenes Medikament konnte nicht gelöscht werden."
            }
        }
    }

    private func rebuildMedicationCaches() {
        rebuildMedicationSelectionCache()
        rebuildMedicationGroupCache()
    }

    private func rebuildMedicationSelectionCache() {
        medicationSelectionIndicesByKey = draft.medications.enumerated().reduce(into: [:]) { result, item in
            let (index, medication) = item
            result[medication.selectionKey] = index
        }
        selectedMedicationKeys = Set(draft.medications.filter(\.isSelected).map(\.selectionKey))
        selectedMedicationsCache = draft.medications
            .filter(\.isSelected)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func rebuildMedicationGroupCache() {
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

        let orphanSelections = draft.medications.compactMap { selection -> MedicationDefinitionRecord? in
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
        guard let index = draft.medications.firstIndex(where: { $0.selectionKey == oldSelectionKey }) else {
            return
        }

        draft.medications[index].selectionKey = definition.selectionKey
        draft.medications[index].name = definition.name
        draft.medications[index].category = definition.category
        draft.medications[index].dosage = definition.suggestedDosage
        draft.medications[index].isSelected = true
        rebuildMedicationCaches()
    }

    private var isStartedAtUnchanged: Bool {
        guard let originalStartedAt else {
            return false
        }

        return originalStartedAt == draft.startedAt
    }

    private func weatherSnapshotForSave() async throws -> WeatherSnapshotData? {
        if draft.startedAt > .now {
            throw EpisodeSaveError.futureDate
        }

        if isStartedAtUnchanged {
            return originalWeatherSnapshot
        }

        switch weatherLoadState {
        case .loaded(let snapshot):
            return snapshot
        case .idle, .loading, .unavailable:
            await refreshWeather()
            if case .loaded(let snapshot) = weatherLoadState {
                return snapshot
            }
            return nil
        }
    }

    private func healthContextForSave() async -> HealthContextSnapshotData? {
        do {
            return try await healthService.contextSnapshot(for: draft)
        } catch {
            return nil
        }
    }

    private func writeHealthSampleIfNeeded(episodeID: UUID) async {
        do {
            try await healthService.writeEpisode(id: episodeID, draft: draft)
        } catch {}
    }
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
