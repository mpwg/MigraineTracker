import Foundation
import Observation

struct WeatherRecord: Equatable, Sendable {
    let recordedAt: Date
    let condition: String
    let temperature: Double?
    let humidity: Double?
    let pressure: Double?
    let precipitation: Double?
    let weatherCode: Int?
    let source: String

    var isLegacySnapshot: Bool {
        source.localizedCaseInsensitiveContains("legacy") || source.localizedCaseInsensitiveContains("manuell")
    }
}

struct MedicationRecord: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let category: MedicationCategory
    let dosage: String
    let quantity: Int
    let takenAt: Date
    let effectiveness: MedicationEffectiveness
    let reliefStartedAt: Date?
    let isRepeatDose: Bool
}

struct EpisodeRecord: Identifiable, Equatable, Sendable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date?
    let updatedAt: Date
    let deletedAt: Date?
    let type: EpisodeType
    let intensity: Int
    let painLocation: String
    let painCharacter: String
    let notes: String
    let symptoms: [String]
    let triggers: [String]
    let functionalImpact: String
    let menstruationStatus: MenstruationStatus
    let medications: [MedicationRecord]
    let weather: WeatherRecord?

    var isDeleted: Bool {
        deletedAt != nil
    }
}

struct MedicationDefinitionRecord: Identifiable, Equatable, Sendable {
    let id: String
    let catalogKey: String
    let groupID: String
    let groupTitle: String
    let groupFooter: String?
    let name: String
    let category: MedicationCategory
    let suggestedDosage: String
    let sortOrder: Int
    let isCustom: Bool
    let isDeleted: Bool

    init(
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

    var selectionKey: String {
        [
            name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            category.rawValue,
            suggestedDosage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        ].joined(separator: "|")
    }
}

struct MedicationSelectionDraft: Identifiable, Equatable, Sendable {
    let id: UUID
    var selectionKey: String
    var name: String
    var category: MedicationCategory
    var dosage: String
    var quantity: Int
    var isSelected: Bool

    init(
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

    init(record: MedicationRecord) {
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

    init(definition: MedicationDefinitionRecord) {
        self.init(
            selectionKey: definition.selectionKey,
            name: definition.name,
            category: definition.category,
            dosage: definition.suggestedDosage
        )
    }

    static func makeSelectionKey(name: String, category: MedicationCategory, dosage: String) -> String {
        [
            name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            category.rawValue,
            dosage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        ].joined(separator: "|")
    }
}

struct EpisodeDraft: Equatable, Sendable {
    var id: UUID?
    var type: EpisodeType
    var intensity: Int
    var startedAt: Date
    var endedAtEnabled: Bool
    var endedAt: Date
    var painLocation: String
    var painCharacter: String
    var notes: String
    var functionalImpact: String
    var menstruationStatus: MenstruationStatus
    var selectedSymptoms: Set<String>
    var selectedTriggers: Set<String>
    var medications: [MedicationSelectionDraft]

    static func makeNew(initialStartedAt: Date? = nil) -> EpisodeDraft {
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

    static func from(record: EpisodeRecord) -> EpisodeDraft {
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
    let id: String
    let originalSelectionKey: String?
    let name: String
    let category: MedicationCategory
    let dosage: String
}

struct EpisodeEditorMedicationGroup: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let footer: String?
    let items: [MedicationDefinitionRecord]
}

protocol EpisodeRepository {
    func fetchRecent() throws -> [EpisodeRecord]
    func fetchByDay(_ day: Date) throws -> [EpisodeRecord]
    func fetchByMonth(_ month: Date) throws -> [EpisodeRecord]
    func load(id: UUID) throws -> EpisodeRecord?
    @discardableResult
    func save(draft: EpisodeDraft, weatherSnapshot: WeatherSnapshotData?) throws -> UUID
    func softDelete(id: UUID) throws
    func restore(id: UUID) throws
    func fetchDeleted() throws -> [EpisodeRecord]
}

protocol MedicationCatalogRepository {
    func fetchDefinitions(searchText: String?) throws -> [MedicationDefinitionRecord]
    func saveCustomDefinition(_ draft: CustomMedicationDefinitionDraft) throws -> MedicationDefinitionRecord
    func softDeleteCustomDefinition(catalogKey: String) throws
    func fetchDeletedDefinitions() throws -> [MedicationDefinitionRecord]
}

struct SaveEpisodeUseCase {
    let repository: EpisodeRepository

    @discardableResult
    func execute(_ draft: EpisodeDraft, weatherSnapshot: WeatherSnapshotData?) throws -> UUID {
        if draft.endedAtEnabled, draft.endedAt < draft.startedAt {
            throw EpisodeSaveError.invalidDateRange
        }

        if draft.startedAt > .now {
            throw EpisodeSaveError.futureDate
        }

        return try repository.save(draft: draft, weatherSnapshot: weatherSnapshot)
    }
}

struct HomeOverviewData: Equatable {
    let latestEpisode: EpisodeRecord?
    let episodeCount: Int
}

struct LoadHomeOverviewUseCase {
    let repository: EpisodeRepository

    func execute() throws -> HomeOverviewData {
        let episodes = try repository.fetchRecent()
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

    private let saveEpisodeUseCase: SaveEpisodeUseCase
    private let episodeRepository: EpisodeRepository
    private let medicationRepository: MedicationCatalogRepository
    private let weatherService: WeatherService
    private let locationService: LocationService
    private let originalStartedAt: Date?
    private let originalWeatherSnapshot: WeatherSnapshotData?

    init(
        episodeID: UUID?,
        initialStartedAt: Date?,
        episodeRepository: EpisodeRepository,
        medicationRepository: MedicationCatalogRepository,
        weatherService: WeatherService,
        locationService: LocationService
    ) {
        self.episodeRepository = episodeRepository
        self.medicationRepository = medicationRepository
        self.weatherService = weatherService
        self.locationService = locationService
        self.saveEpisodeUseCase = SaveEpisodeUseCase(repository: episodeRepository)

        if
            let episodeID,
            let record = try? episodeRepository.load(id: episodeID)
        {
            self.mode = .edit
            self.draft = EpisodeDraft.from(record: record)
            self.originalStartedAt = record.startedAt
            self.originalWeatherSnapshot = record.weather.map(WeatherSnapshotData.init)
            self.weatherLoadState = record.weather.map { .loaded(WeatherSnapshotData(record: $0)) } ?? .idle
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

        reloadMedicationDefinitions()
    }

    var filteredMedicationGroups: [EpisodeEditorMedicationGroup] {
        let query = medicationSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let groups = allMedicationGroups

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
        draft.medications
            .filter(\.isSelected)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func reloadMedicationDefinitions() {
        medicationDefinitions = (try? medicationRepository.fetchDefinitions(searchText: nil)) ?? []
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
                try saveEpisodeUseCase.execute(draft, weatherSnapshot: weatherSnapshot)
                reloadMedicationDefinitions()
                validationMessage = nil

                if mode == .create, onSaved == nil {
                    draft = EpisodeDraft.makeNew()
                    medicationSearchText = ""
                    customMedicationEditor = nil
                    pendingMedicationDeletion = nil
                    weatherLoadState = .idle
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
        draft.medications.contains { $0.selectionKey == definition.selectionKey && $0.isSelected }
    }

    func quantity(for definition: MedicationDefinitionRecord) -> Int {
        draft.medications.first(where: { $0.selectionKey == definition.selectionKey })?.quantity ?? 1
    }

    func toggleMedicationSelection(for definition: MedicationDefinitionRecord) {
        if let index = draft.medications.firstIndex(where: { $0.selectionKey == definition.selectionKey }) {
            draft.medications[index].isSelected.toggle()
            draft.medications[index].quantity = max(1, draft.medications[index].quantity)
        } else {
            draft.medications.append(MedicationSelectionDraft(definition: definition))
        }
    }

    func incrementMedicationQuantity(for definition: MedicationDefinitionRecord) {
        if let index = draft.medications.firstIndex(where: { $0.selectionKey == definition.selectionKey }) {
            draft.medications[index].quantity += 1
            draft.medications[index].isSelected = true
        } else {
            draft.medications.append(MedicationSelectionDraft(definition: definition))
        }
    }

    func decrementMedicationQuantity(for definition: MedicationDefinitionRecord) {
        guard let index = draft.medications.firstIndex(where: { $0.selectionKey == definition.selectionKey }) else {
            return
        }

        draft.medications[index].quantity = max(1, draft.medications[index].quantity - 1)
        draft.medications[index].isSelected = true
    }

    func removeMedicationSelection(id: UUID) {
        guard let index = draft.medications.firstIndex(where: { $0.id == id }) else {
            return
        }

        draft.medications[index].isSelected = false
        draft.medications[index].quantity = 1
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

        do {
            let definition = try medicationRepository.saveCustomDefinition(draft)
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

    func deleteCustomMedication(_ definition: MedicationDefinitionRecord) {
        do {
            draft.medications.removeAll { $0.selectionKey == definition.selectionKey }
            try medicationRepository.softDeleteCustomDefinition(catalogKey: definition.catalogKey)
            reloadMedicationDefinitions()
            pendingMedicationDeletion = nil
            validationMessage = nil
        } catch {
            validationMessage = "Eigenes Medikament konnte nicht gelöscht werden."
        }
    }

    private var allMedicationGroups: [EpisodeEditorMedicationGroup] {
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

        return groups
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
