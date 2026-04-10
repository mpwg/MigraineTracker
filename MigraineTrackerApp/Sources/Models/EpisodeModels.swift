import Foundation
import SwiftData

enum EpisodeType: String, CaseIterable, Codable, Identifiable {
    case migraine = "Migräne"
    case headache = "Kopfschmerz"
    case unclear = "Unklar"

    var id: String { rawValue }
}

enum MenstruationStatus: String, CaseIterable, Codable, Identifiable {
    case unknown = "Nicht angegeben"
    case none = "Nein"
    case active = "Aktuell"
    case expected = "Erwartet"

    var id: String { rawValue }
}

enum MedicationCategory: String, CaseIterable, Codable, Identifiable {
    case triptan = "Triptan"
    case nsar = "NSAR"
    case paracetamol = "Paracetamol"
    case antiemetic = "Antiemetikum"
    case other = "Sonstiges"

    var id: String { rawValue }
}

enum MedicationEffectiveness: String, CaseIterable, Codable, Identifiable {
    case none = "Keine"
    case partial = "Teilweise"
    case good = "Gut"

    var id: String { rawValue }
}

@Model
final class Episode {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var updatedAt: Date
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
        type: EpisodeType = .unclear,
        intensity: Int,
        painLocation: String = "",
        painCharacter: String = "",
        notes: String = "",
        symptoms: [String] = [],
        triggers: [String] = [],
        functionalImpact: String = "",
        menstruationStatus: MenstruationStatus = .unknown,
        medications: [MedicationEntry] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.typeRaw = type.rawValue
        self.intensity = intensity
        self.painLocation = painLocation
        self.painCharacter = painCharacter
        self.notes = notes
        self.symptomsStorage = symptoms.joined(separator: "|")
        self.triggersStorage = triggers.joined(separator: "|")
        self.functionalImpact = functionalImpact
        self.menstruationStatusRaw = menstruationStatus.rawValue
        self.medications = medications
    }

    var type: EpisodeType {
        get { EpisodeType(rawValue: typeRaw) ?? .unclear }
        set { typeRaw = newValue.rawValue }
    }

    var menstruationStatus: MenstruationStatus {
        get { MenstruationStatus(rawValue: menstruationStatusRaw) ?? .unknown }
        set { menstruationStatusRaw = newValue.rawValue }
    }

    var symptoms: [String] {
        get { Episode.decodeList(symptomsStorage) }
        set { symptomsStorage = newValue.joined(separator: "|") }
    }

    var triggers: [String] {
        get { Episode.decodeList(triggersStorage) }
        set { triggersStorage = newValue.joined(separator: "|") }
    }

    var hasWeatherSnapshot: Bool {
        weatherSnapshot != nil
    }

    var isDeleted: Bool {
        deletedAt != nil
    }

    func markUpdated(at date: Date = .now) {
        updatedAt = date
        deletedAt = nil
    }

    func markDeleted(at date: Date = .now) {
        updatedAt = date
        deletedAt = date
    }

    func restore(at date: Date = .now) {
        updatedAt = date
        deletedAt = nil
    }

    private static func decodeList(_ storage: String) -> [String] {
        storage
            .split(separator: "|")
            .map { String($0) }
            .filter { !$0.isEmpty }
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
        category: MedicationCategory,
        dosage: String,
        quantity: Int = 1,
        takenAt: Date,
        effectiveness: MedicationEffectiveness,
        reliefStartedAt: Date? = nil,
        isRepeatDose: Bool = false,
        episode: Episode? = nil
    ) {
        self.id = id
        self.name = name
        self.categoryRaw = category.rawValue
        self.dosage = dosage
        self.quantity = quantity
        self.takenAt = takenAt
        self.effectivenessRaw = effectiveness.rawValue
        self.reliefStartedAt = reliefStartedAt
        self.isRepeatDose = isRepeatDose
        self.episode = episode
    }

    var category: MedicationCategory {
        get { MedicationCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var effectiveness: MedicationEffectiveness {
        get { MedicationEffectiveness(rawValue: effectivenessRaw) ?? .partial }
        set { effectivenessRaw = newValue.rawValue }
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
    var updatedAt: Date
    var deletedAt: Date?

    init(
        catalogKey: String,
        groupID: String,
        groupTitle: String,
        groupFooter: String? = nil,
        name: String,
        category: MedicationCategory,
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
        self.categoryRaw = category.rawValue
        self.suggestedDosage = suggestedDosage
        self.sortOrder = sortOrder
        self.isCustom = isCustom
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    var category: MedicationCategory {
        get { MedicationCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var selectionKey: String {
        [
            name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            category.rawValue,
            suggestedDosage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        ].joined(separator: "|")
    }

    var isDeleted: Bool {
        deletedAt != nil
    }

    func markUpdated(at date: Date = .now) {
        updatedAt = date
        deletedAt = nil
    }

    func markDeleted(at date: Date = .now) {
        updatedAt = date
        deletedAt = date
    }

    func restore(at date: Date = .now) {
        updatedAt = date
        deletedAt = nil
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
