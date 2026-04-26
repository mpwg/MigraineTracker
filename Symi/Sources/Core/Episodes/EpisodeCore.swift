import Foundation

struct WeatherRecord: Equatable, Sendable {
    nonisolated let recordedAt: Date
    nonisolated let condition: String
    nonisolated let temperature: Double?
    nonisolated let humidity: Double?
    nonisolated let pressure: Double?
    nonisolated let precipitation: Double?
    nonisolated let weatherCode: Int?
    nonisolated let source: String
    nonisolated let dayRangeStart: Date?
    nonisolated let dayRangeEnd: Date?
    nonisolated let contextRangeStart: Date?
    nonisolated let contextRangeEnd: Date?
    nonisolated let contextPoints: [WeatherContextPointData]

    nonisolated init(
        recordedAt: Date,
        condition: String,
        temperature: Double?,
        humidity: Double?,
        pressure: Double?,
        precipitation: Double?,
        weatherCode: Int?,
        source: String,
        dayRangeStart: Date? = nil,
        dayRangeEnd: Date? = nil,
        contextRangeStart: Date? = nil,
        contextRangeEnd: Date? = nil,
        contextPoints: [WeatherContextPointData] = []
    ) {
        self.recordedAt = recordedAt
        self.condition = condition
        self.temperature = temperature
        self.humidity = humidity
        self.pressure = pressure
        self.precipitation = precipitation
        self.weatherCode = weatherCode
        self.source = source
        self.dayRangeStart = dayRangeStart
        self.dayRangeEnd = dayRangeEnd
        self.contextRangeStart = contextRangeStart
        self.contextRangeEnd = contextRangeEnd
        self.contextPoints = contextPoints
    }

    nonisolated var isLegacySnapshot: Bool {
        source.localizedCaseInsensitiveContains("legacy") || source.localizedCaseInsensitiveContains("manuell")
    }

    nonisolated var hasExtendedContext: Bool {
        contextRangeStart != nil || contextRangeEnd != nil || !contextPoints.isEmpty
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

struct ContinuousMedicationRecord: Identifiable, Equatable, Sendable {
    nonisolated let id: UUID
    nonisolated let name: String
    nonisolated let dosage: String
    nonisolated let frequency: String
    nonisolated let startDate: Date
    nonisolated let endDate: Date?
    nonisolated let createdAt: Date
    nonisolated let updatedAt: Date

    nonisolated var isActive: Bool {
        guard let endDate else {
            return true
        }

        return endDate >= Calendar.current.startOfDay(for: .now)
    }

    nonisolated var detailText: String {
        [dosage, frequency]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

struct ContinuousMedicationCheckRecord: Identifiable, Equatable, Sendable {
    nonisolated let id: UUID
    nonisolated let continuousMedicationID: UUID
    nonisolated let name: String
    nonisolated let dosage: String
    nonisolated let frequency: String
    nonisolated let wasTaken: Bool

    nonisolated var detailText: String {
        [dosage, frequency]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
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
    nonisolated let continuousMedicationChecks: [ContinuousMedicationCheckRecord]
    nonisolated let weather: WeatherRecord?
    nonisolated let healthContext: HealthContextRecord?

    nonisolated var isDeleted: Bool {
        deletedAt != nil
    }

    nonisolated var dayPart: EpisodeDayPart {
        EpisodeDayPart(date: startedAt)
    }
}

struct ContinuousMedicationDraft: Identifiable, Equatable, Sendable {
    nonisolated var id: UUID?
    nonisolated var name: String
    nonisolated var dosage: String
    nonisolated var frequency: String
    nonisolated var startDate: Date
    nonisolated var endDate: Date?

    nonisolated var stableID: UUID {
        id ?? UUID()
    }

    nonisolated init(
        id: UUID? = nil,
        name: String = "",
        dosage: String = "",
        frequency: String = "",
        startDate: Date = .now,
        endDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.dosage = dosage
        self.frequency = frequency
        self.startDate = startDate
        self.endDate = endDate
    }

    nonisolated init(record: ContinuousMedicationRecord) {
        self.init(
            id: record.id,
            name: record.name,
            dosage: record.dosage,
            frequency: record.frequency,
            startDate: record.startDate,
            endDate: record.endDate
        )
    }
}

struct ContinuousMedicationCheckDraft: Identifiable, Equatable, Sendable {
    nonisolated let id: UUID
    nonisolated let continuousMedicationID: UUID
    nonisolated var name: String
    nonisolated var dosage: String
    nonisolated var frequency: String
    nonisolated var wasTaken: Bool

    nonisolated init(
        id: UUID = UUID(),
        continuousMedicationID: UUID,
        name: String,
        dosage: String = "",
        frequency: String = "",
        wasTaken: Bool = true
    ) {
        self.id = id
        self.continuousMedicationID = continuousMedicationID
        self.name = name
        self.dosage = dosage
        self.frequency = frequency
        self.wasTaken = wasTaken
    }

    nonisolated init(record: ContinuousMedicationRecord, wasTaken: Bool = true) {
        self.init(
            continuousMedicationID: record.id,
            name: record.name,
            dosage: record.dosage,
            frequency: record.frequency,
            wasTaken: wasTaken
        )
    }

    nonisolated var detailText: String {
        [dosage, frequency]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

enum EpisodeDayPart: String, CaseIterable, Codable, Identifiable, Sendable {
    case morgens
    case mittags
    case abends
    case nacht

    nonisolated var id: String { rawValue }

    nonisolated init(date: Date, calendar: Calendar = .current) {
        let hour = calendar.component(.hour, from: date)

        switch hour {
        case 5 ..< 11:
            self = .morgens
        case 11 ..< 17:
            self = .mittags
        case 17 ..< 22:
            self = .abends
        default:
            self = .nacht
        }
    }

    nonisolated var label: String {
        switch self {
        case .morgens:
            "Morgens"
        case .mittags:
            "Mittags"
        case .abends:
            "Abends"
        case .nacht:
            "Nacht"
        }
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
    nonisolated var selectedPainLocations: Set<String> = []
    nonisolated var painCharacter: String
    nonisolated var notes: String
    nonisolated var functionalImpact: String
    nonisolated var menstruationStatus: MenstruationStatus
    nonisolated var selectedSymptoms: Set<String>
    nonisolated var selectedTriggers: Set<String>
    nonisolated var medications: [MedicationSelectionDraft]
    nonisolated var continuousMedicationChecks: [ContinuousMedicationCheckDraft] = []

    nonisolated static func makeNew(initialStartedAt: Date? = nil) -> EpisodeDraft {
        let startedAt = initialStartedAt ?? .now
        return EpisodeDraft(
            id: nil,
            type: .unclear,
            intensity: 4,
            startedAt: startedAt,
            endedAtEnabled: false,
            endedAt: startedAt,
            painLocation: "",
            selectedPainLocations: [],
            painCharacter: "",
            notes: "",
            functionalImpact: "",
            menstruationStatus: .unknown,
            selectedSymptoms: [],
            selectedTriggers: [],
            medications: [],
            continuousMedicationChecks: []
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
            selectedPainLocations: Self.decodePainLocations(record.painLocation),
            painCharacter: record.painCharacter,
            notes: record.notes,
            functionalImpact: record.functionalImpact,
            menstruationStatus: record.menstruationStatus,
            selectedSymptoms: Set(record.symptoms),
            selectedTriggers: Set(record.triggers),
            medications: record.medications.map(MedicationSelectionDraft.init(record:)),
            continuousMedicationChecks: record.continuousMedicationChecks.map {
                ContinuousMedicationCheckDraft(
                    id: $0.id,
                    continuousMedicationID: $0.continuousMedicationID,
                    name: $0.name,
                    dosage: $0.dosage,
                    frequency: $0.frequency,
                    wasTaken: $0.wasTaken
                )
            }
        )
    }

    nonisolated var resolvedPainLocation: String {
        let selectedSummary = selectedPainLocations.sorted().joined(separator: ", ")
        guard !selectedSummary.isEmpty else {
            return painLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return selectedSummary
    }

    nonisolated var normalizedIntensity: Int {
        min(max(intensity, 1), 10)
    }

    nonisolated private static func decodePainLocations(_ value: String) -> Set<String> {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }

        let parts = trimmed
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return Set(parts.isEmpty ? [trimmed] : parts)
    }
}

struct CustomMedicationDefinitionDraft: Equatable, Sendable {
    nonisolated let id: String
    nonisolated let originalSelectionKey: String?
    nonisolated let name: String
    nonisolated let category: MedicationCategory
    nonisolated let dosage: String
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

protocol ContinuousMedicationRepository: Sendable {
    nonisolated func fetchAll() throws -> [ContinuousMedicationRecord]
    nonisolated func fetchActive(on date: Date) throws -> [ContinuousMedicationRecord]
    @discardableResult
    nonisolated func save(_ draft: ContinuousMedicationDraft) throws -> ContinuousMedicationRecord
    nonisolated func delete(id: UUID) throws
}

struct SaveEpisodeUseCase {
    let repository: EpisodeRepository

    @discardableResult
    func execute(_ draft: EpisodeDraft, weatherSnapshot: WeatherSnapshotData?, healthContext: HealthContextSnapshotData? = nil) async throws -> UUID {
        try await PerformanceInstrumentation.measure("EpisodeSaveUseCase") {
            if draft.endedAtEnabled, draft.endedAt < draft.startedAt {
                throw EpisodeSaveError.invalidDateRange
            }

            if draft.startedAt > .now {
                throw EpisodeSaveError.futureDate
            }

            let repository = repository
            return try await Task.detached(priority: .userInitiated) {
                try PerformanceInstrumentation.measure("EpisodeRepositorySave") {
                    try repository.save(draft: draft, weatherSnapshot: weatherSnapshot, healthContext: healthContext)
                }
            }.value
        }
    }
}

struct HomeOverviewData: Equatable {
    let latestEpisode: EpisodeRecord?
    let episodeCount: Int
}

struct LoadHomeOverviewUseCase {
    let repository: EpisodeRepository

    func execute() async throws -> HomeOverviewData {
        try await PerformanceInstrumentation.measure("HomeOverviewReload") {
            let repository = repository
            let episodes = try await Task.detached(priority: .userInitiated) {
                try PerformanceInstrumentation.measure("EpisodeRepositoryFetchRecent") {
                    try repository.fetchRecent()
                }
            }.value
            return HomeOverviewData(
                latestEpisode: episodes.first,
                episodeCount: episodes.count
            )
        }
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
