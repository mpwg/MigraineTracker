import Foundation

enum EpisodeType: String, CaseIterable, Codable, Identifiable {
    case migraine = "migraine"
    case headache = "headache"
    case unclear = "unclear"

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .migraine:
            String(localized: "Migräne")
        case .headache:
            String(localized: "Kopfschmerz")
        case .unclear:
            String(localized: "Unklar")
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
    case unknown = "unknown"
    case none = "none"
    case active = "active"
    case expected = "expected"

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .unknown:
            String(localized: "Nicht angegeben")
        case .none:
            String(localized: "Nein")
        case .active:
            String(localized: "Aktuell")
        case .expected:
            String(localized: "Erwartet")
        }
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
            String(localized: "Triptan")
        case .nsar:
            String(localized: "NSAR")
        case .paracetamol:
            String(localized: "Paracetamol")
        case .antiemetic:
            String(localized: "Antiemetikum")
        case .other:
            String(localized: "Sonstiges")
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
    case none = "none"
    case partial = "partial"
    case good = "good"

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .none:
            String(localized: "Keine")
        case .partial:
            String(localized: "Teilweise")
        case .good:
            String(localized: "Gut")
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

struct MedicationSelectionKey {
    nonisolated static func make(name: String, category: MedicationCategory, dosage: String) -> String {
        [
            name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            category.rawValue,
            dosage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        ].joined(separator: "|")
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
            intensity: intensity,
            painLocation: painLocation,
            painCharacter: painCharacter,
            notes: notes,
            symptomsStorage: symptoms.joined(separator: "|"),
            triggersStorage: triggers.joined(separator: "|"),
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

extension ContinuousMedication {
    var isActive: Bool {
        endDate == nil || (endDate ?? .distantPast) >= Calendar.current.startOfDay(for: .now)
    }

    var detailText: String {
        MedicationTextFormatter.detailText(dosage: dosage, frequency: frequency)
    }

    func markUpdated(at date: Date = .now) {
        updatedAt = date
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
