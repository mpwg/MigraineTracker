import Foundation
import SwiftData

enum MigraineTrackerSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Episode.self,
            MedicationEntry.self,
            MedicationDefinition.self,
            WeatherSnapshot.self,
        ]
    }

    @Model
    final class Episode {
        @Attribute(.unique) var id: UUID
        var startedAt: Date
        var endedAt: Date?
        var typeRaw: String
        var intensity: Int
        var painLocation: String
        var painCharacter: String
        var notes: String
        var symptomsStorage: String
        var triggersStorage: String
        var functionalImpact: String
        var menstruationStatusRaw: String

        @Relationship(deleteRule: .cascade, inverse: \MedicationEntry.episode)
        var medications: [MedicationEntry]

        @Relationship(deleteRule: .cascade, inverse: \WeatherSnapshot.episode)
        var weatherSnapshot: WeatherSnapshot?

        init(
            id: UUID = UUID(),
            startedAt: Date,
            endedAt: Date? = nil,
            typeRaw: String,
            intensity: Int,
            painLocation: String = "",
            painCharacter: String = "",
            notes: String = "",
            symptomsStorage: String = "",
            triggersStorage: String = "",
            functionalImpact: String = "",
            menstruationStatusRaw: String = MenstruationStatus.unknown.rawValue,
            medications: [MedicationEntry] = []
        ) {
            self.id = id
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.typeRaw = typeRaw
            self.intensity = intensity
            self.painLocation = painLocation
            self.painCharacter = painCharacter
            self.notes = notes
            self.symptomsStorage = symptomsStorage
            self.triggersStorage = triggersStorage
            self.functionalImpact = functionalImpact
            self.menstruationStatusRaw = menstruationStatusRaw
            self.medications = medications
        }
    }

    @Model
    final class MedicationEntry {
        @Attribute(.unique) var id: UUID
        var name: String
        var categoryRaw: String
        var dosage: String
        var quantity: Int
        var takenAt: Date
        var effectivenessRaw: String
        var reliefStartedAt: Date?
        var isRepeatDose: Bool
        var episode: Episode?

        init(
            id: UUID = UUID(),
            name: String,
            categoryRaw: String,
            dosage: String,
            quantity: Int = 1,
            takenAt: Date,
            effectivenessRaw: String,
            reliefStartedAt: Date? = nil,
            isRepeatDose: Bool = false,
            episode: Episode? = nil
        ) {
            self.id = id
            self.name = name
            self.categoryRaw = categoryRaw
            self.dosage = dosage
            self.quantity = quantity
            self.takenAt = takenAt
            self.effectivenessRaw = effectivenessRaw
            self.reliefStartedAt = reliefStartedAt
            self.isRepeatDose = isRepeatDose
            self.episode = episode
        }
    }

    @Model
    final class MedicationDefinition {
        @Attribute(.unique) var catalogKey: String
        var groupID: String
        var groupTitle: String
        var groupFooter: String?
        var name: String
        var categoryRaw: String
        var suggestedDosage: String
        var sortOrder: Int
        var isCustom: Bool
        var createdAt: Date

        init(
            catalogKey: String,
            groupID: String,
            groupTitle: String,
            groupFooter: String? = nil,
            name: String,
            categoryRaw: String,
            suggestedDosage: String,
            sortOrder: Int,
            isCustom: Bool,
            createdAt: Date = .now
        ) {
            self.catalogKey = catalogKey
            self.groupID = groupID
            self.groupTitle = groupTitle
            self.groupFooter = groupFooter
            self.name = name
            self.categoryRaw = categoryRaw
            self.suggestedDosage = suggestedDosage
            self.sortOrder = sortOrder
            self.isCustom = isCustom
            self.createdAt = createdAt
        }
    }

    @Model
    final class WeatherSnapshot {
        @Attribute(.unique) var id: UUID
        var recordedAt: Date
        var temperature: Double?
        var condition: String
        var humidity: Double?
        var pressure: Double?
        var source: String
        var episode: Episode?

        init(
            id: UUID = UUID(),
            recordedAt: Date,
            temperature: Double? = nil,
            condition: String = "",
            humidity: Double? = nil,
            pressure: Double? = nil,
            source: String = "",
            episode: Episode? = nil
        ) {
            self.id = id
            self.recordedAt = recordedAt
            self.temperature = temperature
            self.condition = condition
            self.humidity = humidity
            self.pressure = pressure
            self.source = source
            self.episode = episode
        }
    }
}

enum MigraineTrackerSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Episode.self,
            MedicationEntry.self,
            MedicationDefinition.self,
            WeatherSnapshot.self,
        ]
    }

    @Model
    final class Episode {
        @Attribute(.unique) var id: UUID
        var startedAt: Date
        var endedAt: Date?
        var updatedAt: Date = Date.now
        var deletedAt: Date?
        var typeRaw: String
        var intensity: Int
        var painLocation: String
        var painCharacter: String
        var notes: String
        var symptomsStorage: String
        var triggersStorage: String
        var functionalImpact: String
        var menstruationStatusRaw: String

        @Relationship(deleteRule: .cascade, inverse: \MedicationEntry.episode)
        var medications: [MedicationEntry]

        @Relationship(deleteRule: .cascade, inverse: \WeatherSnapshot.episode)
        var weatherSnapshot: WeatherSnapshot?

        init(
            id: UUID = UUID(),
            startedAt: Date,
            endedAt: Date? = nil,
            updatedAt: Date = .now,
            deletedAt: Date? = nil,
            typeRaw: String,
            intensity: Int,
            painLocation: String = "",
            painCharacter: String = "",
            notes: String = "",
            symptomsStorage: String = "",
            triggersStorage: String = "",
            functionalImpact: String = "",
            menstruationStatusRaw: String = MenstruationStatus.unknown.rawValue,
            medications: [MedicationEntry] = []
        ) {
            self.id = id
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
            self.typeRaw = typeRaw
            self.intensity = intensity
            self.painLocation = painLocation
            self.painCharacter = painCharacter
            self.notes = notes
            self.symptomsStorage = symptomsStorage
            self.triggersStorage = triggersStorage
            self.functionalImpact = functionalImpact
            self.menstruationStatusRaw = menstruationStatusRaw
            self.medications = medications
        }
    }

    @Model
    final class MedicationEntry {
        @Attribute(.unique) var id: UUID
        var name: String
        var categoryRaw: String
        var dosage: String
        var quantity: Int
        var takenAt: Date
        var effectivenessRaw: String
        var reliefStartedAt: Date?
        var isRepeatDose: Bool
        var episode: Episode?

        init(
            id: UUID = UUID(),
            name: String,
            categoryRaw: String,
            dosage: String,
            quantity: Int = 1,
            takenAt: Date,
            effectivenessRaw: String,
            reliefStartedAt: Date? = nil,
            isRepeatDose: Bool = false,
            episode: Episode? = nil
        ) {
            self.id = id
            self.name = name
            self.categoryRaw = categoryRaw
            self.dosage = dosage
            self.quantity = quantity
            self.takenAt = takenAt
            self.effectivenessRaw = effectivenessRaw
            self.reliefStartedAt = reliefStartedAt
            self.isRepeatDose = isRepeatDose
            self.episode = episode
        }
    }

    @Model
    final class MedicationDefinition {
        @Attribute(.unique) var catalogKey: String
        var groupID: String
        var groupTitle: String
        var groupFooter: String?
        var name: String
        var categoryRaw: String
        var suggestedDosage: String
        var sortOrder: Int
        var isCustom: Bool
        var createdAt: Date
        var updatedAt: Date = Date.now
        var deletedAt: Date?

        init(
            catalogKey: String,
            groupID: String,
            groupTitle: String,
            groupFooter: String? = nil,
            name: String,
            categoryRaw: String,
            suggestedDosage: String,
            sortOrder: Int,
            isCustom: Bool,
            createdAt: Date = .now,
            updatedAt: Date = .now,
            deletedAt: Date? = nil
        ) {
            self.catalogKey = catalogKey
            self.groupID = groupID
            self.groupTitle = groupTitle
            self.groupFooter = groupFooter
            self.name = name
            self.categoryRaw = categoryRaw
            self.suggestedDosage = suggestedDosage
            self.sortOrder = sortOrder
            self.isCustom = isCustom
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
        }
    }

    @Model
    final class WeatherSnapshot {
        @Attribute(.unique) var id: UUID
        var recordedAt: Date
        var temperature: Double?
        var condition: String
        var humidity: Double?
        var pressure: Double?
        var source: String
        var episode: Episode?

        init(
            id: UUID = UUID(),
            recordedAt: Date,
            temperature: Double? = nil,
            condition: String = "",
            humidity: Double? = nil,
            pressure: Double? = nil,
            source: String = "",
            episode: Episode? = nil
        ) {
            self.id = id
            self.recordedAt = recordedAt
            self.temperature = temperature
            self.condition = condition
            self.humidity = humidity
            self.pressure = pressure
            self.source = source
            self.episode = episode
        }
    }
}

enum MigraineTrackerSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Episode.self,
            MedicationEntry.self,
            MedicationDefinition.self,
            WeatherSnapshot.self,
        ]
    }

    @Model
    final class Episode {
        @Attribute(.unique) var id: UUID
        var startedAt: Date
        var endedAt: Date?
        var updatedAt: Date = Date.now
        var deletedAt: Date?
        var typeRaw: String
        var intensity: Int
        var painLocation: String
        var painCharacter: String
        var notes: String
        var symptomsStorage: String
        var triggersStorage: String
        var functionalImpact: String
        var menstruationStatusRaw: String

        @Relationship(deleteRule: .cascade, inverse: \MedicationEntry.episode)
        var medications: [MedicationEntry]

        @Relationship(deleteRule: .cascade, inverse: \WeatherSnapshot.episode)
        var weatherSnapshot: WeatherSnapshot?

        init(
            id: UUID = UUID(),
            startedAt: Date,
            endedAt: Date? = nil,
            updatedAt: Date = .now,
            deletedAt: Date? = nil,
            typeRaw: String,
            intensity: Int,
            painLocation: String = "",
            painCharacter: String = "",
            notes: String = "",
            symptomsStorage: String = "",
            triggersStorage: String = "",
            functionalImpact: String = "",
            menstruationStatusRaw: String = MenstruationStatus.unknown.rawValue,
            medications: [MedicationEntry] = []
        ) {
            self.id = id
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
            self.typeRaw = typeRaw
            self.intensity = intensity
            self.painLocation = painLocation
            self.painCharacter = painCharacter
            self.notes = notes
            self.symptomsStorage = symptomsStorage
            self.triggersStorage = triggersStorage
            self.functionalImpact = functionalImpact
            self.menstruationStatusRaw = menstruationStatusRaw
            self.medications = medications
        }
    }

    @Model
    final class MedicationEntry {
        @Attribute(.unique) var id: UUID
        var name: String
        var categoryRaw: String
        var dosage: String
        var quantity: Int
        var takenAt: Date
        var effectivenessRaw: String
        var reliefStartedAt: Date?
        var isRepeatDose: Bool
        var episode: Episode?

        init(
            id: UUID = UUID(),
            name: String,
            categoryRaw: String,
            dosage: String,
            quantity: Int = 1,
            takenAt: Date,
            effectivenessRaw: String,
            reliefStartedAt: Date? = nil,
            isRepeatDose: Bool = false,
            episode: Episode? = nil
        ) {
            self.id = id
            self.name = name
            self.categoryRaw = categoryRaw
            self.dosage = dosage
            self.quantity = quantity
            self.takenAt = takenAt
            self.effectivenessRaw = effectivenessRaw
            self.reliefStartedAt = reliefStartedAt
            self.isRepeatDose = isRepeatDose
            self.episode = episode
        }
    }

    @Model
    final class MedicationDefinition {
        @Attribute(.unique) var catalogKey: String
        var groupID: String
        var groupTitle: String
        var groupFooter: String?
        var name: String
        var categoryRaw: String
        var suggestedDosage: String
        var sortOrder: Int
        var isCustom: Bool
        var createdAt: Date
        var updatedAt: Date = Date.now
        var deletedAt: Date?

        init(
            catalogKey: String,
            groupID: String,
            groupTitle: String,
            groupFooter: String? = nil,
            name: String,
            categoryRaw: String,
            suggestedDosage: String,
            sortOrder: Int,
            isCustom: Bool,
            createdAt: Date = .now,
            updatedAt: Date = .now,
            deletedAt: Date? = nil
        ) {
            self.catalogKey = catalogKey
            self.groupID = groupID
            self.groupTitle = groupTitle
            self.groupFooter = groupFooter
            self.name = name
            self.categoryRaw = categoryRaw
            self.suggestedDosage = suggestedDosage
            self.sortOrder = sortOrder
            self.isCustom = isCustom
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
        }
    }

    @Model
    final class WeatherSnapshot {
        @Attribute(.unique) var id: UUID
        var recordedAt: Date
        var temperature: Double?
        var condition: String
        var humidity: Double?
        var pressure: Double?
        var precipitation: Double?
        var weatherCode: Int?
        var source: String
        var episode: Episode?

        init(
            id: UUID = UUID(),
            recordedAt: Date,
            temperature: Double? = nil,
            condition: String = "",
            humidity: Double? = nil,
            pressure: Double? = nil,
            precipitation: Double? = nil,
            weatherCode: Int? = nil,
            source: String = "",
            episode: Episode? = nil
        ) {
            self.id = id
            self.recordedAt = recordedAt
            self.temperature = temperature
            self.condition = condition
            self.humidity = humidity
            self.pressure = pressure
            self.precipitation = precipitation
            self.weatherCode = weatherCode
            self.source = source
            self.episode = episode
        }
    }
}

enum MigraineTrackerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            MigraineTrackerSchemaV1.self,
            MigraineTrackerSchemaV2.self,
            MigraineTrackerSchemaV3.self,
        ]
    }

    static var stages: [MigrationStage] {
        [
            .custom(
                fromVersion: MigraineTrackerSchemaV1.self,
                toVersion: MigraineTrackerSchemaV2.self,
                willMigrate: nil,
                didMigrate: { context in
                    let episodes = try context.fetch(FetchDescriptor<MigraineTrackerSchemaV2.Episode>())
                    for episode in episodes {
                        episode.updatedAt = episode.startedAt
                        episode.deletedAt = nil
                    }

                    let definitions = try context.fetch(FetchDescriptor<MigraineTrackerSchemaV2.MedicationDefinition>())
                    for definition in definitions {
                        definition.updatedAt = definition.createdAt
                        definition.deletedAt = nil
                    }

                    try context.save()
                }
            ),
            .custom(
                fromVersion: MigraineTrackerSchemaV2.self,
                toVersion: MigraineTrackerSchemaV3.self,
                willMigrate: nil,
                didMigrate: { context in
                    let episodes = try context.fetch(FetchDescriptor<MigraineTrackerSchemaV3.Episode>())
                    for episode in episodes {
                        episode.updatedAt = max(episode.updatedAt, episode.startedAt)
                    }

                    let weatherSnapshots = try context.fetch(FetchDescriptor<MigraineTrackerSchemaV3.WeatherSnapshot>())
                    for snapshot in weatherSnapshots {
                        snapshot.precipitation = nil
                        snapshot.weatherCode = nil

                        let trimmedSource = snapshot.source.trimmingCharacters(in: .whitespacesAndNewlines)
                        snapshot.source = trimmedSource.isEmpty ? "Legacy manuell" : "Legacy: \(trimmedSource)"
                    }

                    try context.save()
                }
            )
        ]
    }
}

typealias Episode = MigraineTrackerSchemaV3.Episode
typealias MedicationEntry = MigraineTrackerSchemaV3.MedicationEntry
typealias MedicationDefinition = MigraineTrackerSchemaV3.MedicationDefinition
typealias WeatherSnapshot = MigraineTrackerSchemaV3.WeatherSnapshot
