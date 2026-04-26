import Foundation

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

extension Episode {
    convenience init(
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
        self.init(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            typeRaw: type.rawValue,
            intensity: intensity,
            painLocation: painLocation,
            painCharacter: painCharacter,
            notes: notes,
            symptomsStorage: symptoms.joined(separator: "|"),
            triggersStorage: triggers.joined(separator: "|"),
            functionalImpact: functionalImpact,
            menstruationStatusRaw: menstruationStatus.rawValue,
            medications: medications
        )
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

extension MedicationEntry {
    convenience init(
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
        self.init(
            id: id,
            name: name,
            categoryRaw: category.rawValue,
            dosage: dosage,
            quantity: quantity,
            takenAt: takenAt,
            effectivenessRaw: effectiveness.rawValue,
            reliefStartedAt: reliefStartedAt,
            isRepeatDose: isRepeatDose,
            episode: episode
        )
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

extension MedicationDefinition {
    convenience init(
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
        self.init(
            catalogKey: catalogKey,
            groupID: groupID,
            groupTitle: groupTitle,
            groupFooter: groupFooter,
            name: name,
            categoryRaw: category.rawValue,
            suggestedDosage: suggestedDosage,
            sortOrder: sortOrder,
            isCustom: isCustom,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt
        )
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

extension WeatherSnapshot {
    convenience init(
        id: UUID = UUID(),
        snapshot: WeatherSnapshotData,
        episode: Episode? = nil
    ) {
        self.init(
            id: id,
            recordedAt: snapshot.recordedAt,
            temperature: snapshot.temperature,
            condition: snapshot.condition,
            humidity: snapshot.humidity,
            pressure: snapshot.pressure,
            precipitation: snapshot.precipitation,
            weatherCode: snapshot.weatherCode,
            source: snapshot.source,
            dayRangeStart: snapshot.dayRangeStart,
            dayRangeEnd: snapshot.dayRangeEnd,
            contextRangeStart: snapshot.contextRangeStart,
            contextRangeEnd: snapshot.contextRangeEnd,
            contextPointsStorage: Self.encodeContextPoints(snapshot.contextPoints),
            episode: episode
        )
    }
}

extension WeatherSnapshot {
    var contextPoints: [WeatherContextPointData] {
        get { Self.decodeContextPoints(contextPointsStorage) }
        set { contextPointsStorage = Self.encodeContextPoints(newValue) }
    }

    static func encodeContextPoints(_ points: [WeatherContextPointData]) -> String {
        guard !points.isEmpty, let data = try? JSONEncoder.weatherContextEncoder.encode(points) else {
            return ""
        }
        return String(decoding: data, as: UTF8.self)
    }

    private static func decodeContextPoints(_ storage: String) -> [WeatherContextPointData] {
        guard !storage.isEmpty, let data = storage.data(using: .utf8) else {
            return []
        }
        return (try? JSONDecoder.weatherContextDecoder.decode([WeatherContextPointData].self, from: data)) ?? []
    }
}

private extension JSONEncoder {
    nonisolated static var weatherContextEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    nonisolated static var weatherContextDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
