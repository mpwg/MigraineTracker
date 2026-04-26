import Foundation
import SwiftData
import UniformTypeIdentifiers

extension UTType {
    static let symiJSON5 = UTType(filenameExtension: "json5") ?? .json
}

enum DataTransferError: LocalizedError {
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Die Datei enthält kein unterstütztes Datenformat für \(ProductBranding.displayName)."
        }
    }
}

struct DataTransferSnapshot: @preconcurrency Codable, Sendable {
    let formatVersion: Int
    let exportedAt: Date
    let episodes: [EpisodePayload]
    let customMedicationDefinitions: [MedicationDefinitionPayload]

    nonisolated init(
        formatVersion: Int = 1,
        exportedAt: Date = .now,
        episodes: [EpisodePayload],
        customMedicationDefinitions: [MedicationDefinitionPayload]
    ) {
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.episodes = episodes
        self.customMedicationDefinitions = customMedicationDefinitions
    }

    nonisolated init(episodes: [Episode], customMedicationDefinitions: [MedicationDefinition], healthContextStore: HealthContextStore? = nil) {
        self.init(
            episodes: episodes.map { EpisodePayload(episode: $0, healthContext: healthContextStore?.load(for: $0.id)) },
            customMedicationDefinitions: customMedicationDefinitions.map(MedicationDefinitionPayload.init)
        )
    }

    nonisolated func writeToTemporaryFile() throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let fileName = "schmerztagebuch-export-\(Self.fileDateString(from: exportedAt)).json5"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let data = try encoder.encode(self)

        try data.write(to: url, options: .atomic)
        return url
    }

    nonisolated static func load(from url: URL) throws -> DataTransferSnapshot {
        let shouldStopAccess = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.allowsJSON5 = true
        decoder.dateDecodingStrategy = .iso8601

        let snapshot = try decoder.decode(DataTransferSnapshot.self, from: data)
        guard snapshot.formatVersion == 1 else {
            throw DataTransferError.invalidFormat
        }

        return snapshot
    }

    nonisolated func merge(into context: ModelContext, healthContextStore: HealthContextStore) throws {
        let existingEpisodes = try context.fetch(FetchDescriptor<Episode>())
        let episodesByID = Dictionary(uniqueKeysWithValues: existingEpisodes.map { ($0.id, $0) })

        let existingDefinitions = try context.fetch(FetchDescriptor<MedicationDefinition>())
        let customDefinitionsByKey = Dictionary(
            uniqueKeysWithValues: existingDefinitions
                .filter(\.isCustom)
                .map { ($0.catalogKey, $0) }
        )

        for payload in customMedicationDefinitions {
            if let definition = customDefinitionsByKey[payload.catalogKey] {
                payload.apply(to: definition)
            } else {
                context.insert(payload.makeModel())
            }
        }

        for payload in episodes {
            if let episode = episodesByID[payload.id] {
                payload.apply(to: episode, in: context)
            } else {
                context.insert(payload.makeModel())
            }
        }

        try context.save()
        try mergeEpisodeSidecars(into: healthContextStore)
    }

    private nonisolated func mergeEpisodeSidecars(into healthContextStore: HealthContextStore) throws {
        for payload in episodes {
            try payload.applySidecars(to: healthContextStore)
        }
    }

    private nonisolated static func fileDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: date)
    }
}

struct EpisodePayload: Codable, Sendable {
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
    let medications: [MedicationEntryPayload]
    let weatherSnapshot: WeatherSnapshotPayload?
    let healthContext: HealthContextSnapshotData?
    private let shouldImportHealthContext: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case startedAt
        case endedAt
        case updatedAt
        case deletedAt
        case type
        case intensity
        case painLocation
        case painCharacter
        case notes
        case symptoms
        case triggers
        case functionalImpact
        case menstruationStatus
        case medications
        case weatherSnapshot
        case healthContext
    }

    nonisolated init(episode: Episode, healthContext: HealthContextRecord? = nil) {
        self.id = episode.id
        self.startedAt = episode.startedAt
        self.endedAt = episode.endedAt
        self.updatedAt = episode.updatedAt
        self.deletedAt = episode.deletedAt
        self.type = episode.type
        self.intensity = episode.intensity
        self.painLocation = episode.painLocation
        self.painCharacter = episode.painCharacter
        self.notes = episode.notes
        self.symptoms = episode.symptoms
        self.triggers = episode.triggers
        self.functionalImpact = episode.functionalImpact
        self.menstruationStatus = episode.menstruationStatus
        self.medications = episode.medications.map(MedicationEntryPayload.init)
        self.weatherSnapshot = episode.weatherSnapshot.map(WeatherSnapshotPayload.init)
        self.healthContext = healthContext.map(HealthContextSnapshotData.init)
        self.shouldImportHealthContext = healthContext != nil
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.startedAt = try container.decode(Date.self, forKey: .startedAt)
        self.endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        self.deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        self.type = try container.decode(EpisodeType.self, forKey: .type)
        self.intensity = try container.decode(Int.self, forKey: .intensity)
        self.painLocation = try container.decode(String.self, forKey: .painLocation)
        self.painCharacter = try container.decode(String.self, forKey: .painCharacter)
        self.notes = try container.decode(String.self, forKey: .notes)
        self.symptoms = try container.decode([String].self, forKey: .symptoms)
        self.triggers = try container.decode([String].self, forKey: .triggers)
        self.functionalImpact = try container.decode(String.self, forKey: .functionalImpact)
        self.menstruationStatus = try container.decode(MenstruationStatus.self, forKey: .menstruationStatus)
        self.medications = try container.decode([MedicationEntryPayload].self, forKey: .medications)
        self.weatherSnapshot = try container.decodeIfPresent(WeatherSnapshotPayload.self, forKey: .weatherSnapshot)
        self.shouldImportHealthContext = container.contains(.healthContext)
        self.healthContext = try container.decodeIfPresent(HealthContextSnapshotData.self, forKey: .healthContext)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(endedAt, forKey: .endedAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
        try container.encode(type, forKey: .type)
        try container.encode(intensity, forKey: .intensity)
        try container.encode(painLocation, forKey: .painLocation)
        try container.encode(painCharacter, forKey: .painCharacter)
        try container.encode(notes, forKey: .notes)
        try container.encode(symptoms, forKey: .symptoms)
        try container.encode(triggers, forKey: .triggers)
        try container.encode(functionalImpact, forKey: .functionalImpact)
        try container.encode(menstruationStatus, forKey: .menstruationStatus)
        try container.encode(medications, forKey: .medications)
        try container.encodeIfPresent(weatherSnapshot, forKey: .weatherSnapshot)

        if let healthContext {
            try container.encode(healthContext, forKey: .healthContext)
        } else if shouldImportHealthContext {
            try container.encodeNil(forKey: .healthContext)
        }
    }

    nonisolated func makeModel() -> Episode {
        let episode = Episode(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            type: type,
            intensity: intensity,
            painLocation: painLocation,
            painCharacter: painCharacter,
            notes: notes,
            symptoms: symptoms,
            triggers: triggers,
            functionalImpact: functionalImpact,
            menstruationStatus: menstruationStatus
        )

        episode.medications = medications.map { $0.makeModel(for: episode) }
        episode.weatherSnapshot = weatherSnapshot?.makeModel(for: episode)
        return episode
    }

    nonisolated func apply(to episode: Episode, in context: ModelContext) {
        episode.startedAt = startedAt
        episode.endedAt = endedAt
        episode.updatedAt = updatedAt
        episode.deletedAt = deletedAt
        episode.type = type
        episode.intensity = intensity
        episode.painLocation = painLocation
        episode.painCharacter = painCharacter
        episode.notes = notes
        episode.symptoms = symptoms
        episode.triggers = triggers
        episode.functionalImpact = functionalImpact
        episode.menstruationStatus = menstruationStatus

        let existingMedicationsByID = Dictionary(uniqueKeysWithValues: episode.medications.map { ($0.id, $0) })
        let importedMedicationIDs = Set(medications.map(\.id))

        for medication in episode.medications where !importedMedicationIDs.contains(medication.id) {
            context.delete(medication)
        }

        episode.medications = medications.map { payload in
            if let medication = existingMedicationsByID[payload.id] {
                payload.apply(to: medication, for: episode)
                return medication
            }

            return payload.makeModel(for: episode)
        }

        if let weatherSnapshot {
            if let existingWeatherSnapshot = episode.weatherSnapshot {
                weatherSnapshot.apply(to: existingWeatherSnapshot, for: episode)
            } else {
                episode.weatherSnapshot = weatherSnapshot.makeModel(for: episode)
            }
        } else if let existingWeatherSnapshot = episode.weatherSnapshot {
            context.delete(existingWeatherSnapshot)
            episode.weatherSnapshot = nil
        }
    }

    nonisolated func applySidecars(to healthContextStore: HealthContextStore) throws {
        guard shouldImportHealthContext else {
            return
        }

        try healthContextStore.save(healthContext, for: id)
    }
}

struct MedicationEntryPayload: @preconcurrency Codable, Sendable {
    let id: UUID
    let name: String
    let category: MedicationCategory
    let dosage: String
    let quantity: Int
    let takenAt: Date
    let effectiveness: MedicationEffectiveness
    let reliefStartedAt: Date?
    let isRepeatDose: Bool

    nonisolated init(entry: MedicationEntry) {
        self.id = entry.id
        self.name = entry.name
        self.category = entry.category
        self.dosage = entry.dosage
        self.quantity = entry.quantity
        self.takenAt = entry.takenAt
        self.effectiveness = entry.effectiveness
        self.reliefStartedAt = entry.reliefStartedAt
        self.isRepeatDose = entry.isRepeatDose
    }

    nonisolated func makeModel(for episode: Episode) -> MedicationEntry {
        MedicationEntry(
            id: id,
            name: name,
            category: category,
            dosage: dosage,
            quantity: quantity,
            takenAt: takenAt,
            effectiveness: effectiveness,
            reliefStartedAt: reliefStartedAt,
            isRepeatDose: isRepeatDose,
            episode: episode
        )
    }

    nonisolated func apply(to entry: MedicationEntry, for episode: Episode) {
        entry.name = name
        entry.category = category
        entry.dosage = dosage
        entry.quantity = quantity
        entry.takenAt = takenAt
        entry.effectiveness = effectiveness
        entry.reliefStartedAt = reliefStartedAt
        entry.isRepeatDose = isRepeatDose
        entry.episode = episode
    }
}

struct WeatherSnapshotPayload: Codable, Sendable {
    let id: UUID
    let recordedAt: Date
    let temperature: Double?
    let condition: String
    let humidity: Double?
    let pressure: Double?
    let precipitation: Double?
    let weatherCode: Int?
    let source: String
    let dayRangeStart: Date?
    let dayRangeEnd: Date?
    let contextRangeStart: Date?
    let contextRangeEnd: Date?
    let contextPoints: [WeatherContextPointData]

    private enum CodingKeys: String, CodingKey {
        case id
        case recordedAt
        case temperature
        case condition
        case humidity
        case pressure
        case precipitation
        case weatherCode
        case source
        case dayRangeStart
        case dayRangeEnd
        case contextRangeStart
        case contextRangeEnd
        case contextPoints
    }

    nonisolated init(snapshot: WeatherSnapshot) {
        self.id = snapshot.id
        self.recordedAt = snapshot.recordedAt
        self.temperature = snapshot.temperature
        self.condition = snapshot.condition
        self.humidity = snapshot.humidity
        self.pressure = snapshot.pressure
        self.precipitation = snapshot.precipitation
        self.weatherCode = snapshot.weatherCode
        self.source = snapshot.source
        self.dayRangeStart = snapshot.dayRangeStart
        self.dayRangeEnd = snapshot.dayRangeEnd
        self.contextRangeStart = snapshot.contextRangeStart
        self.contextRangeEnd = snapshot.contextRangeEnd
        self.contextPoints = snapshot.contextPoints
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.recordedAt = try container.decode(Date.self, forKey: .recordedAt)
        self.temperature = try container.decodeIfPresent(Double.self, forKey: .temperature)
        self.condition = try container.decode(String.self, forKey: .condition)
        self.humidity = try container.decodeIfPresent(Double.self, forKey: .humidity)
        self.pressure = try container.decodeIfPresent(Double.self, forKey: .pressure)
        self.precipitation = try container.decodeIfPresent(Double.self, forKey: .precipitation)
        self.weatherCode = try container.decodeIfPresent(Int.self, forKey: .weatherCode)
        self.source = try container.decode(String.self, forKey: .source)
        self.dayRangeStart = try container.decodeIfPresent(Date.self, forKey: .dayRangeStart)
        self.dayRangeEnd = try container.decodeIfPresent(Date.self, forKey: .dayRangeEnd)
        self.contextRangeStart = try container.decodeIfPresent(Date.self, forKey: .contextRangeStart)
        self.contextRangeEnd = try container.decodeIfPresent(Date.self, forKey: .contextRangeEnd)
        self.contextPoints = try container.decodeIfPresent([WeatherContextPointData].self, forKey: .contextPoints) ?? []
    }

    nonisolated func makeModel(for episode: Episode) -> WeatherSnapshot {
        WeatherSnapshot(
            id: id,
            recordedAt: recordedAt,
            temperature: temperature,
            condition: condition,
            humidity: humidity,
            pressure: pressure,
            precipitation: precipitation,
            weatherCode: weatherCode,
            source: source,
            dayRangeStart: dayRangeStart,
            dayRangeEnd: dayRangeEnd,
            contextRangeStart: contextRangeStart,
            contextRangeEnd: contextRangeEnd,
            contextPointsStorage: WeatherSnapshot.encodeContextPoints(contextPoints),
            episode: episode
        )
    }

    nonisolated func apply(to snapshot: WeatherSnapshot, for episode: Episode) {
        snapshot.recordedAt = recordedAt
        snapshot.temperature = temperature
        snapshot.condition = condition
        snapshot.humidity = humidity
        snapshot.pressure = pressure
        snapshot.precipitation = precipitation
        snapshot.weatherCode = weatherCode
        snapshot.source = source
        snapshot.dayRangeStart = dayRangeStart
        snapshot.dayRangeEnd = dayRangeEnd
        snapshot.contextRangeStart = contextRangeStart
        snapshot.contextRangeEnd = contextRangeEnd
        snapshot.contextPoints = contextPoints
        snapshot.episode = episode
    }
}

struct MedicationDefinitionPayload: @preconcurrency Codable, Sendable {
    let catalogKey: String
    let groupID: String
    let groupTitle: String
    let groupFooter: String?
    let name: String
    let category: MedicationCategory
    let suggestedDosage: String
    let sortOrder: Int
    let isCustom: Bool
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?

    nonisolated init(definition: MedicationDefinition) {
        self.catalogKey = definition.catalogKey
        self.groupID = definition.groupID
        self.groupTitle = definition.groupTitle
        self.groupFooter = definition.groupFooter
        self.name = definition.name
        self.category = definition.category
        self.suggestedDosage = definition.suggestedDosage
        self.sortOrder = definition.sortOrder
        self.isCustom = definition.isCustom
        self.createdAt = definition.createdAt
        self.updatedAt = definition.updatedAt
        self.deletedAt = definition.deletedAt
    }

    nonisolated func makeModel() -> MedicationDefinition {
        MedicationDefinition(
            catalogKey: catalogKey,
            groupID: groupID,
            groupTitle: groupTitle,
            groupFooter: groupFooter,
            name: name,
            category: category,
            suggestedDosage: suggestedDosage,
            sortOrder: sortOrder,
            isCustom: isCustom,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt
        )
    }

    nonisolated func apply(to definition: MedicationDefinition) {
        definition.groupID = groupID
        definition.groupTitle = groupTitle
        definition.groupFooter = groupFooter
        definition.name = name
        definition.category = category
        definition.suggestedDosage = suggestedDosage
        definition.sortOrder = sortOrder
        definition.isCustom = isCustom
        definition.createdAt = createdAt
        definition.updatedAt = updatedAt
        definition.deletedAt = deletedAt
    }
}
