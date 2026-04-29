import Foundation
import SwiftData

enum SymiSchemaV5: VersionedSchema {
    static let versionIdentifier = Schema.Version(5, 0, 0)
    static var models: [any PersistentModel.Type] {
        [
            Episode.self,
            MedicationEntry.self,
            MedicationDefinition.self,
            WeatherSnapshot.self
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
        var dayRangeStart: Date?
        var dayRangeEnd: Date?
        var contextRangeStart: Date?
        var contextRangeEnd: Date?
        var contextPointsStorage: String = ""
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
            dayRangeStart: Date? = nil,
            dayRangeEnd: Date? = nil,
            contextRangeStart: Date? = nil,
            contextRangeEnd: Date? = nil,
            contextPointsStorage: String = "",
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
            self.dayRangeStart = dayRangeStart
            self.dayRangeEnd = dayRangeEnd
            self.contextRangeStart = contextRangeStart
            self.contextRangeEnd = contextRangeEnd
            self.contextPointsStorage = contextPointsStorage
            self.episode = episode
        }
    }

}
