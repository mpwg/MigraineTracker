import Foundation
import SwiftData
import UniformTypeIdentifiers

extension UTType {
    static let migraineTrackerJSON5 = UTType(filenameExtension: "json5") ?? .json
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

struct DataTransferSnapshot: Codable {
    let formatVersion: Int
    let exportedAt: Date
    let episodes: [EpisodePayload]
    let customMedicationDefinitions: [MedicationDefinitionPayload]

    init(
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

    init(episodes: [Episode], customMedicationDefinitions: [MedicationDefinition]) {
        self.init(
            episodes: episodes.map(EpisodePayload.init),
            customMedicationDefinitions: customMedicationDefinitions.map(MedicationDefinitionPayload.init)
        )
    }

    func writeToTemporaryFile() throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let fileName = "schmerztagebuch-export-\(Self.fileDateFormatter.string(from: exportedAt)).json5"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let data = try encoder.encode(self)

        try data.write(to: url, options: .atomic)
        return url
    }

    static func load(from url: URL) throws -> DataTransferSnapshot {
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

    func merge(into context: ModelContext) throws {
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
    }

    private static let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()
}

struct EpisodePayload: Codable {
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

    init(episode: Episode) {
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
    }

    func makeModel() -> Episode {
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

    func apply(to episode: Episode, in context: ModelContext) {
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
}

struct MedicationEntryPayload: Codable {
    let id: UUID
    let name: String
    let category: MedicationCategory
    let dosage: String
    let quantity: Int
    let takenAt: Date
    let effectiveness: MedicationEffectiveness
    let reliefStartedAt: Date?
    let isRepeatDose: Bool

    init(entry: MedicationEntry) {
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

    func makeModel(for episode: Episode) -> MedicationEntry {
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

    func apply(to entry: MedicationEntry, for episode: Episode) {
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

struct WeatherSnapshotPayload: Codable {
    let id: UUID
    let recordedAt: Date
    let temperature: Double?
    let condition: String
    let humidity: Double?
    let pressure: Double?
    let precipitation: Double?
    let weatherCode: Int?
    let source: String

    init(snapshot: WeatherSnapshot) {
        self.id = snapshot.id
        self.recordedAt = snapshot.recordedAt
        self.temperature = snapshot.temperature
        self.condition = snapshot.condition
        self.humidity = snapshot.humidity
        self.pressure = snapshot.pressure
        self.precipitation = snapshot.precipitation
        self.weatherCode = snapshot.weatherCode
        self.source = snapshot.source
    }

    func makeModel(for episode: Episode) -> WeatherSnapshot {
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
            episode: episode
        )
    }

    func apply(to snapshot: WeatherSnapshot, for episode: Episode) {
        snapshot.recordedAt = recordedAt
        snapshot.temperature = temperature
        snapshot.condition = condition
        snapshot.humidity = humidity
        snapshot.pressure = pressure
        snapshot.precipitation = precipitation
        snapshot.weatherCode = weatherCode
        snapshot.source = source
        snapshot.episode = episode
    }
}

struct MedicationDefinitionPayload: Codable {
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

    init(definition: MedicationDefinition) {
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

    func makeModel() -> MedicationDefinition {
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

    func apply(to definition: MedicationDefinition) {
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
