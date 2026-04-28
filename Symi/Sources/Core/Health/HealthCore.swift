import Foundation

enum HealthDataDirection: String, Codable, CaseIterable, Identifiable, Sendable {
    case read = "Lesen"
    case write = "Schreiben"

    public var id: String { rawValue }
}

public enum HealthDataTypeID: String, Codable, CaseIterable, Identifiable, Sendable {
    case sleep
    case steps
    case heartRate
    case restingHeartRate
    case heartRateVariability
    case menstrualFlow
    case headache
    case nausea
    case dizziness
    case fatigue

    public var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .sleep: "Schlaf"
        case .steps: "Schritte"
        case .heartRate: "Herzfrequenz"
        case .restingHeartRate: "Ruhepuls"
        case .heartRateVariability: "Herzfrequenzvariabilität"
        case .menstrualFlow: "Menstruation"
        case .headache: "Kopfschmerz"
        case .nausea: "Übelkeit"
        case .dizziness: "Schwindel"
        case .fatigue: "Müdigkeit"
        }
    }
}

struct HealthDataTypeDefinition: Identifiable, Equatable, Sendable {
    let id: HealthDataTypeID
    let direction: HealthDataDirection
    let defaultEnabled: Bool
    let rationale: String

    var displayName: String { id.displayName }
}

enum HealthDataCatalog {
    static let readDefinitions: [HealthDataTypeDefinition] = [
        .init(id: .sleep, direction: .read, defaultEnabled: true, rationale: "Schlafmangel und Schlafqualität sind häufige Kontextfaktoren bei Kopfschmerzen und Migräne."),
        .init(id: .steps, direction: .read, defaultEnabled: true, rationale: "Aktivität am Episodentag kann helfen, Belastung und Schonung im Verlauf einzuordnen."),
        .init(id: .heartRate, direction: .read, defaultEnabled: true, rationale: "Herzfrequenz im Umfeld einer Episode kann körperlichen Stress als Kontext sichtbar machen."),
        .init(id: .restingHeartRate, direction: .read, defaultEnabled: true, rationale: "Der Ruhepuls ergänzt den Tageskontext, ohne eine medizinische Bewertung vorzunehmen."),
        .init(id: .heartRateVariability, direction: .read, defaultEnabled: true, rationale: "HRV kann als neutraler Kontextwert für Stress und Erholung angezeigt werden."),
        .init(id: .menstrualFlow, direction: .read, defaultEnabled: true, rationale: "Zyklusdaten können bei migränebezogenen Mustern relevant sein, bleiben aber reine Kontextdaten."),
        .init(id: .headache, direction: .read, defaultEnabled: true, rationale: "Vorhandene Health-Kopfschmerzsymptome werden als externe Quelle kenntlich gemacht."),
        .init(id: .nausea, direction: .read, defaultEnabled: true, rationale: "Übelkeit ist ein häufiges Begleitsymptom von Migräne."),
        .init(id: .dizziness, direction: .read, defaultEnabled: true, rationale: "Schwindel kann als Begleitsymptom den Episodenkontext ergänzen."),
        .init(id: .fatigue, direction: .read, defaultEnabled: true, rationale: "Müdigkeit kann als neutraler Kontext vor oder während Schmerzepisoden relevant sein.")
    ]

    static let writeDefinitions: [HealthDataTypeDefinition] = [
        .init(id: .headache, direction: .write, defaultEnabled: true, rationale: "Die App kann die dokumentierte Schmerzepisode als Kopfschmerz-Symptom nach Apple Health schreiben."),
        .init(id: .nausea, direction: .write, defaultEnabled: true, rationale: "Übelkeit wird nur geschrieben, wenn sie in der Episode ausdrücklich ausgewählt wurde.")
    ]

    static var allDefinitions: [HealthDataTypeDefinition] {
        readDefinitions + writeDefinitions
    }
}

public struct HealthSymptomSampleData: @preconcurrency Codable, Equatable, Sendable {
    public let type: HealthDataTypeID
    public let severity: String
    public let startDate: Date
    public let endDate: Date
    public let source: String

    public nonisolated init(
        type: HealthDataTypeID,
        severity: String,
        startDate: Date,
        endDate: Date,
        source: String
    ) {
        self.type = type
        self.severity = severity
        self.startDate = startDate
        self.endDate = endDate
        self.source = source
    }

    public nonisolated static func == (lhs: HealthSymptomSampleData, rhs: HealthSymptomSampleData) -> Bool {
        lhs.type == rhs.type &&
            lhs.severity == rhs.severity &&
            lhs.startDate == rhs.startDate &&
            lhs.endDate == rhs.endDate &&
            lhs.source == rhs.source
    }
}

public struct HealthContextSnapshotData: @preconcurrency Codable, Equatable, Sendable {
    public let recordedAt: Date
    public let source: String
    public let sleepMinutes: Double?
    public let stepCount: Int?
    public let averageHeartRate: Double?
    public let restingHeartRate: Double?
    public let heartRateVariability: Double?
    public let menstrualFlow: String?
    public let symptoms: [HealthSymptomSampleData]

    public nonisolated init(
        recordedAt: Date,
        source: String,
        sleepMinutes: Double?,
        stepCount: Int?,
        averageHeartRate: Double?,
        restingHeartRate: Double?,
        heartRateVariability: Double?,
        menstrualFlow: String?,
        symptoms: [HealthSymptomSampleData]
    ) {
        self.recordedAt = recordedAt
        self.source = source
        self.sleepMinutes = sleepMinutes
        self.stepCount = stepCount
        self.averageHeartRate = averageHeartRate
        self.restingHeartRate = restingHeartRate
        self.heartRateVariability = heartRateVariability
        self.menstrualFlow = menstrualFlow
        self.symptoms = symptoms
    }

    var hasVisibleData: Bool {
        sleepMinutes != nil ||
        stepCount != nil ||
        averageHeartRate != nil ||
        restingHeartRate != nil ||
        heartRateVariability != nil ||
        menstrualFlow != nil ||
            !symptoms.isEmpty
    }

    public nonisolated static func == (lhs: HealthContextSnapshotData, rhs: HealthContextSnapshotData) -> Bool {
        lhs.recordedAt == rhs.recordedAt &&
            lhs.source == rhs.source &&
            lhs.sleepMinutes == rhs.sleepMinutes &&
            lhs.stepCount == rhs.stepCount &&
            lhs.averageHeartRate == rhs.averageHeartRate &&
            lhs.restingHeartRate == rhs.restingHeartRate &&
            lhs.heartRateVariability == rhs.heartRateVariability &&
            lhs.menstrualFlow == rhs.menstrualFlow &&
            lhs.symptoms == rhs.symptoms
    }
}

struct HealthContextRecord: Equatable, Sendable {
    let recordedAt: Date
    let source: String
    let sleepMinutes: Double?
    let stepCount: Int?
    let averageHeartRate: Double?
    let restingHeartRate: Double?
    let heartRateVariability: Double?
    let menstrualFlow: String?
    let symptoms: [HealthSymptomSampleData]

    nonisolated init(snapshot: HealthContextSnapshotData) {
        self.recordedAt = snapshot.recordedAt
        self.source = snapshot.source
        self.sleepMinutes = snapshot.sleepMinutes
        self.stepCount = snapshot.stepCount
        self.averageHeartRate = snapshot.averageHeartRate
        self.restingHeartRate = snapshot.restingHeartRate
        self.heartRateVariability = snapshot.heartRateVariability
        self.menstrualFlow = snapshot.menstrualFlow
        self.symptoms = snapshot.symptoms
    }
}

struct HealthAuthorizationSnapshot: Equatable, Sendable {
    var isAvailable: Bool
    var isReadEnabled: Bool
    var isWriteEnabled: Bool
    var enabledReadTypes: Set<HealthDataTypeID>
    var enabledWriteTypes: Set<HealthDataTypeID>
    var lastErrorMessage: String?

    static let unavailable = HealthAuthorizationSnapshot(
        isAvailable: false,
        isReadEnabled: false,
        isWriteEnabled: false,
        enabledReadTypes: [],
        enabledWriteTypes: [],
        lastErrorMessage: "Apple Health ist auf diesem Gerät nicht verfügbar."
    )
}

enum HealthIntegrationError: LocalizedError {
    case unavailable
    case missingPermission

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "Apple Health ist auf diesem Gerät nicht verfügbar."
        case .missingPermission:
            "Die benötigte Apple-Health-Berechtigung fehlt."
        }
    }
}

protocol HealthService: AnyObject {
    var readDefinitions: [HealthDataTypeDefinition] { get }
    var writeDefinitions: [HealthDataTypeDefinition] { get }

    func authorizationSnapshot() -> HealthAuthorizationSnapshot
    func setEnabled(_ enabled: Bool, for type: HealthDataTypeID, direction: HealthDataDirection)
    func requestReadAuthorization() async throws
    func requestWriteAuthorization() async throws
    func contextSnapshot(for draft: EpisodeDraft) async throws -> HealthContextSnapshotData?
    func writeEpisode(id: UUID, draft: EpisodeDraft) async throws
}

extension HealthContextSnapshotData {
    nonisolated init(record: HealthContextRecord) {
        self.init(
            recordedAt: record.recordedAt,
            source: record.source,
            sleepMinutes: record.sleepMinutes,
            stepCount: record.stepCount,
            averageHeartRate: record.averageHeartRate,
            restingHeartRate: record.restingHeartRate,
            heartRateVariability: record.heartRateVariability,
            menstrualFlow: record.menstrualFlow,
            symptoms: record.symptoms
        )
    }
}

enum HealthSeverityMapper {
    static func symptomSeverityLabel(forIntensity intensity: Int) -> String {
        PainIntensityLevel(intensity: intensity).healthSeverityLabel
    }
}
