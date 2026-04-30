import CryptoKit
import Foundation

enum EpisodeType: String, CaseIterable, Codable, Identifiable {
    case migraine
    case headache
    case unclear

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .migraine:
            "Migräne"
        case .headache:
            "Kopfschmerz"
        case .unclear:
            "Unklar"
        }
    }

    nonisolated init(storageValue: String) {
        switch storageValue {
        case Self.migraine.rawValue, "Migräne":
            self = .migraine
        case Self.headache.rawValue, "Kopfschmerz":
            self = .headache
        case Self.unclear.rawValue, "Unklar":
            self = .unclear
        default:
            self = .unclear
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(storageValue: try container.decode(String.self))
    }
}

enum MenstruationStatus: String, CaseIterable, Codable, Identifiable {
    case unknown
    case none
    case active
    case expected

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .unknown:
            "Nicht angegeben"
        case .none:
            "Nein"
        case .active:
            "Aktuell"
        case .expected:
            "Erwartet"
        }
    }

    nonisolated var accuracyDescription: String {
        switch self {
        case .unknown:
            "Keine Zyklusangabe aus der App."
        case .none:
            "App-Angabe ohne Health-Flow-Sample."
        case .active:
            "Aktuelle App-Angabe ohne Stärke oder Health-Flow-Sample."
        case .expected:
            "Erwartete App-Angabe, keine echte Blutungsprobe."
        }
    }

    nonisolated var canWriteMenstrualFlowSample: Bool {
        false
    }

    nonisolated init(storageValue: String) {
        switch storageValue {
        case Self.unknown.rawValue, "Nicht angegeben":
            self = .unknown
        case Self.none.rawValue, "Nein":
            self = .none
        case Self.active.rawValue, "Aktuell":
            self = .active
        case Self.expected.rawValue, "Erwartet":
            self = .expected
        default:
            self = .unknown
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(storageValue: try container.decode(String.self))
    }
}

enum MedicationCategory: String, CaseIterable, Codable, Identifiable {
    case triptan = "triptan"
    case nsar = "nsaid"
    case paracetamol = "paracetamol"
    case antiemetic = "antiemetic"
    case other = "other"

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .triptan:
            "Triptan"
        case .nsar:
            "NSAR"
        case .paracetamol:
            "Paracetamol"
        case .antiemetic:
            "Antiemetikum"
        case .other:
            "Sonstiges"
        }
    }

    nonisolated init(storageValue: String) {
        switch storageValue {
        case Self.triptan.rawValue, "Triptan":
            self = .triptan
        case Self.nsar.rawValue, "nsar", "NSAR":
            self = .nsar
        case Self.paracetamol.rawValue, "Paracetamol":
            self = .paracetamol
        case Self.antiemetic.rawValue, "Antiemetikum":
            self = .antiemetic
        case Self.other.rawValue, "Sonstiges":
            self = .other
        default:
            self = .other
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(storageValue: try container.decode(String.self))
    }
}

enum MedicationEffectiveness: String, CaseIterable, Codable, Identifiable {
    case none
    case partial
    case good

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .none:
            "Keine"
        case .partial:
            "Teilweise"
        case .good:
            "Gut"
        }
    }

    nonisolated init(storageValue: String) {
        switch storageValue {
        case Self.none.rawValue, "Keine":
            self = .none
        case Self.partial.rawValue, "Teilweise":
            self = .partial
        case Self.good.rawValue, "Gut":
            self = .good
        default:
            self = .partial
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(storageValue: try container.decode(String.self))
    }
}

struct MedicationTextFormatter {
    nonisolated static func detailText(dosage: String, frequency: String) -> String {
        [dosage, frequency]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

enum StringListStorage {
    nonisolated static func encode(_ values: [String]) -> String {
        guard !values.isEmpty, let data = try? JSONEncoder().encode(values) else {
            return ""
        }

        return String(bytes: data, encoding: .utf8) ?? ""
    }

    nonisolated static func decode(_ storage: String) -> [String] {
        let trimmedStorage = storage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedStorage.isEmpty else {
            return []
        }

        if trimmedStorage.first == "[",
           let data = trimmedStorage.data(using: .utf8),
           let values = try? JSONDecoder().decode([String].self, from: data) {
            return values.filter { !$0.isEmpty }
        }

        return decodeLegacyDelimiterStorage(trimmedStorage)
    }

    nonisolated static func migrateLegacyStorage(_ storage: String) -> String {
        let trimmedStorage = storage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedStorage.isEmpty, trimmedStorage.first != "[" else {
            return storage
        }

        return encode(decodeLegacyDelimiterStorage(trimmedStorage))
    }

    private nonisolated static func decodeLegacyDelimiterStorage(_ storage: String) -> [String] {
        storage
            .split(separator: "|")
            .map { String($0) }
            .filter { !$0.isEmpty }
    }
}

struct MedicationSelectionKey {
    nonisolated static func make(name: String, category: MedicationCategory, dosage: String) -> String {
        let payload = [
            "name": name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            "category": category.rawValue,
            "dosage": dosage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        ]
        let data = (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])) ?? Data()
        let digest = SHA256.hash(data: data)
            .map { byte -> String in
                let hex = String(byte, radix: 16)
                return hex.count == 1 ? "0\(hex)" : hex
            }
            .joined()

        return "medication-sha256:\(digest)"
    }
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
        medications: [MedicationEntry] = [],
        continuousMedicationChecks: [ContinuousMedicationCheck] = []
    ) {
        self.init(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            typeRaw: type.rawValue,
            intensityLevelRaw: PainIntensityLevel(intensity: intensity).rawValue,
            painLocation: painLocation,
            painCharacter: painCharacter,
            notes: notes,
            symptomsStorage: StringListStorage.encode(symptoms),
            triggersStorage: StringListStorage.encode(triggers),
            functionalImpact: functionalImpact,
            menstruationStatusRaw: menstruationStatus.rawValue,
            medications: medications,
            continuousMedicationChecks: continuousMedicationChecks
        )
    }

    var type: EpisodeType {
        get { EpisodeType(storageValue: typeRaw) }
        set { typeRaw = newValue.rawValue }
    }

    var menstruationStatus: MenstruationStatus {
        get { MenstruationStatus(storageValue: menstruationStatusRaw) }
        set { menstruationStatusRaw = newValue.rawValue }
    }

    var symptoms: [String] {
        get { StringListStorage.decode(symptomsStorage) }
        set { symptomsStorage = StringListStorage.encode(newValue) }
    }

    var triggers: [String] {
        get { StringListStorage.decode(triggersStorage) }
        set { triggersStorage = StringListStorage.encode(newValue) }
    }

    var intensityLevel: PainIntensityLevel {
        get { PainIntensityLevel(storageValue: intensityLevelRaw) }
        set { intensityLevelRaw = newValue.rawValue }
    }

    var intensity: Int {
        get { intensityLevel.storedIntensity }
        set { intensityLevel = PainIntensityLevel(intensity: newValue) }
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

}

extension ContinuousMedication {
    var isActive: Bool {
        deletedAt == nil && (endDate == nil || (endDate ?? .distantPast) >= Calendar.current.startOfDay(for: .now))
    }

    var detailText: String {
        MedicationTextFormatter.detailText(dosage: dosage, frequency: frequency)
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

    func end(on date: Date = .now) {
        endDate = date
        updatedAt = date
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
        get { MedicationCategory(storageValue: categoryRaw) }
        set { categoryRaw = newValue.rawValue }
    }

    var effectiveness: MedicationEffectiveness {
        get { MedicationEffectiveness(storageValue: effectivenessRaw) }
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
        get { MedicationCategory(storageValue: categoryRaw) }
        set { categoryRaw = newValue.rawValue }
    }

    var selectionKey: String {
        MedicationSelectionKey.make(
            name: name,
            category: category,
            dosage: suggestedDosage
        )
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
        return String(bytes: data, encoding: .utf8) ?? ""
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
