import Foundation

public enum SyncServiceState: String, Codable, CaseIterable, Sendable {
    case disabled
    case ready
    case syncing
    case needsAttention
    case conflict
    case noICloudAccount
    case offline

    public nonisolated var displayTitle: String {
        switch self {
        case .disabled:
            "Deaktiviert"
        case .ready:
            "Bereit"
        case .syncing:
            "Synchronisiert gerade"
        case .needsAttention:
            "Aktion nötig"
        case .conflict:
            "Konflikt"
        case .noICloudAccount:
            "iCloud ist derzeit nicht verfügbar"
        case .offline:
            "Offline"
        }
    }
}

public enum SyncEntityType: String, Codable, CaseIterable, Sendable {
    case episode
    case medicationDefinition
    case continuousMedication
}

public enum SyncPayloadSchema {
    public nonisolated static let currentVersion = 1
    public nonisolated static let maximumCloudKitPayloadBytes = 900_000

    public nonisolated static func currentVersion(for entityType: SyncEntityType) -> Int {
        switch entityType {
        case .episode, .medicationDefinition, .continuousMedication:
            currentVersion
        }
    }

    public nonisolated static func supportedVersions(for entityType: SyncEntityType) -> ClosedRange<Int> {
        switch entityType {
        case .episode, .medicationDefinition, .continuousMedication:
            currentVersion...currentVersion
        }
    }

    public nonisolated static func supports(_ version: Int, for entityType: SyncEntityType) -> Bool {
        supportedVersions(for: entityType).contains(version)
    }
}

public struct SyncStatusSnapshot: Codable, Equatable, Sendable {
    public nonisolated static let staleDataWarningInterval: TimeInterval = 24 * 60 * 60

    public nonisolated var state: SyncServiceState
    public nonisolated var service: String
    public nonisolated var queuedUpdates: Int
    public nonisolated var unsyncedRecords: Int
    public nonisolated var lastDownloadedAt: Date?
    public nonisolated var lastUploadedAt: Date?
    public nonisolated var lastError: String?
    public nonisolated var lastErrorIsRetryable: Bool

    public nonisolated init(
        state: SyncServiceState = .disabled,
        service: String = "iCloud",
        queuedUpdates: Int = 0,
        unsyncedRecords: Int = 0,
        lastDownloadedAt: Date? = nil,
        lastUploadedAt: Date? = nil,
        lastError: String? = nil,
        lastErrorIsRetryable: Bool = false
    ) {
        self.state = state
        self.service = service
        self.queuedUpdates = queuedUpdates
        self.unsyncedRecords = unsyncedRecords
        self.lastDownloadedAt = lastDownloadedAt
        self.lastUploadedAt = lastUploadedAt
        self.lastError = lastError
        self.lastErrorIsRetryable = lastErrorIsRetryable
    }

    public nonisolated func staleDataWarning(
        now: Date = .now,
        isSyncEnabled: Bool,
        openConflictCount: Int
    ) -> String? {
        guard isSyncEnabled else {
            return nil
        }

        if openConflictCount > 0 {
            return "\(openConflictCount) Sync-Konflikt\(openConflictCount == 1 ? "" : "e") warten auf eine Entscheidung. Bearbeite erst weiter, wenn klar ist, welcher Stand gelten soll."
        }

        return nil
    }

}

extension Notification.Name {
    nonisolated static let symiLocalSyncDataDidChange = Notification.Name("SymiLocalSyncDataDidChange")
}

public struct SyncDocumentEnvelope: Codable, Equatable, Sendable {
    public nonisolated var documentID: String
    public nonisolated var entityType: SyncEntityType
    public nonisolated var schemaVersion: Int
    public nonisolated var modifiedAt: Date
    public nonisolated var authorDeviceID: String
    public nonisolated var deletedAt: Date?
    public nonisolated var payload: Payload

    public nonisolated init(
        documentID: String,
        entityType: SyncEntityType,
        schemaVersion: Int = SyncPayloadSchema.currentVersion,
        modifiedAt: Date,
        authorDeviceID: String,
        deletedAt: Date? = nil,
        payload: Payload
    ) {
        self.documentID = documentID
        self.entityType = entityType
        self.schemaVersion = schemaVersion
        self.modifiedAt = modifiedAt
        self.authorDeviceID = authorDeviceID
        self.deletedAt = deletedAt
        self.payload = payload
    }

    public enum Payload: Codable, Equatable, Sendable {
        case episode(SyncEpisodePayload)
        case medicationDefinition(SyncMedicationDefinitionPayload)
        case continuousMedication(SyncContinuousMedicationPayload)

        private enum CodingKeys: String, CodingKey {
            case episode
            case medicationDefinition
            case continuousMedication
        }

        public nonisolated init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let episode = try container.decodeIfPresent(SyncEpisodePayload.self, forKey: .episode) {
                self = .episode(episode)
                return
            }

            if let definition = try container.decodeIfPresent(SyncMedicationDefinitionPayload.self, forKey: .medicationDefinition) {
                self = .medicationDefinition(definition)
                return
            }

            if let medication = try container.decodeIfPresent(SyncContinuousMedicationPayload.self, forKey: .continuousMedication) {
                self = .continuousMedication(medication)
                return
            }

            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unbekannte Sync-Payload."
                )
            )
        }

        public nonisolated func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .episode(let payload):
                try container.encode(payload, forKey: .episode)
            case .medicationDefinition(let payload):
                try container.encode(payload, forKey: .medicationDefinition)
            case .continuousMedication(let payload):
                try container.encode(payload, forKey: .continuousMedication)
            }
        }

        public nonisolated var entityType: SyncEntityType {
            switch self {
            case .episode:
                .episode
            case .medicationDefinition:
                .medicationDefinition
            case .continuousMedication:
                .continuousMedication
            }
        }
    }
}

public struct SyncEpisodePayload: Codable, Equatable, Sendable {
    public nonisolated var id: String
    public nonisolated var startedAt: Date
    public nonisolated var endedAt: Date?
    public nonisolated var type: String
    public nonisolated var intensity: Int
    public nonisolated var intensityLevel: String
    public nonisolated var painLocation: String
    public nonisolated var painCharacter: String
    public nonisolated var notes: String
    public nonisolated var symptoms: [String]
    public nonisolated var triggers: [String]
    public nonisolated var functionalImpact: String
    public nonisolated var menstruationStatus: String
    public nonisolated var medications: [SyncMedicationEntryPayload]
    public nonisolated var continuousMedicationChecks: [SyncContinuousMedicationCheckPayload]
    public nonisolated var weatherSnapshot: SyncWeatherSnapshotPayload?
    public nonisolated var healthContext: HealthContextSnapshotData?
    public nonisolated var includesHealthContext: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case startedAt
        case endedAt
        case type
        case intensity
        case intensityLevel
        case painLocation
        case painCharacter
        case notes
        case symptoms
        case triggers
        case functionalImpact
        case menstruationStatus
        case medications
        case continuousMedicationChecks
        case weatherSnapshot
        case healthContext
    }

    public nonisolated init(
        id: String,
        startedAt: Date,
        endedAt: Date?,
        type: String,
        intensity: Int,
        intensityLevel: String? = nil,
        painLocation: String,
        painCharacter: String,
        notes: String,
        symptoms: [String],
        triggers: [String],
        functionalImpact: String,
        menstruationStatus: String,
        medications: [SyncMedicationEntryPayload],
        continuousMedicationChecks: [SyncContinuousMedicationCheckPayload] = [],
        weatherSnapshot: SyncWeatherSnapshotPayload?,
        healthContext: HealthContextSnapshotData? = nil,
        includesHealthContext: Bool = true
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.type = type
        self.intensity = intensity
        self.intensityLevel = intensityLevel ?? PainIntensityLevel(intensity: intensity).rawValue
        self.painLocation = painLocation
        self.painCharacter = painCharacter
        self.notes = notes
        self.symptoms = symptoms
        self.triggers = triggers
        self.functionalImpact = functionalImpact
        self.menstruationStatus = menstruationStatus
        self.medications = medications
        self.continuousMedicationChecks = continuousMedicationChecks
        self.weatherSnapshot = weatherSnapshot
        self.healthContext = healthContext
        self.includesHealthContext = includesHealthContext
    }

    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.startedAt = try container.decode(Date.self, forKey: .startedAt)
        self.endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        self.type = try container.decode(String.self, forKey: .type)
        self.intensity = try container.decode(Int.self, forKey: .intensity)
        self.intensityLevel = try container.decodeIfPresent(String.self, forKey: .intensityLevel) ?? PainIntensityLevel(intensity: intensity).rawValue
        self.painLocation = try container.decode(String.self, forKey: .painLocation)
        self.painCharacter = try container.decode(String.self, forKey: .painCharacter)
        self.notes = try container.decode(String.self, forKey: .notes)
        self.symptoms = try container.decode([String].self, forKey: .symptoms)
        self.triggers = try container.decode([String].self, forKey: .triggers)
        self.functionalImpact = try container.decode(String.self, forKey: .functionalImpact)
        self.menstruationStatus = try container.decode(String.self, forKey: .menstruationStatus)
        self.medications = try container.decode([SyncMedicationEntryPayload].self, forKey: .medications)
        self.continuousMedicationChecks = try container.decodeIfPresent(
            [SyncContinuousMedicationCheckPayload].self,
            forKey: .continuousMedicationChecks
        ) ?? []
        self.weatherSnapshot = try container.decodeIfPresent(SyncWeatherSnapshotPayload.self, forKey: .weatherSnapshot)
        self.includesHealthContext = container.contains(.healthContext)
        self.healthContext = try container.decodeIfPresent(HealthContextSnapshotData.self, forKey: .healthContext)
    }

    public nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(endedAt, forKey: .endedAt)
        try container.encode(type, forKey: .type)
        try container.encode(intensity, forKey: .intensity)
        try container.encode(intensityLevel, forKey: .intensityLevel)
        try container.encode(painLocation, forKey: .painLocation)
        try container.encode(painCharacter, forKey: .painCharacter)
        try container.encode(notes, forKey: .notes)
        try container.encode(symptoms, forKey: .symptoms)
        try container.encode(triggers, forKey: .triggers)
        try container.encode(functionalImpact, forKey: .functionalImpact)
        try container.encode(menstruationStatus, forKey: .menstruationStatus)
        try container.encode(medications, forKey: .medications)
        try container.encode(continuousMedicationChecks, forKey: .continuousMedicationChecks)
        try container.encodeIfPresent(weatherSnapshot, forKey: .weatherSnapshot)

        if includesHealthContext {
            if let healthContext {
                try container.encode(healthContext, forKey: .healthContext)
            } else {
                try container.encodeNil(forKey: .healthContext)
            }
        }
    }

    public nonisolated var resolvedIntensityLevel: String {
        let decodedLevel = PainIntensityLevel(storageValue: intensityLevel)
        return decodedLevel == .none ? PainIntensityLevel(intensity: intensity).rawValue : decodedLevel.rawValue
    }
}

public struct SyncMedicationEntryPayload: Codable, Equatable, Sendable {
    public nonisolated var id: String
    public nonisolated var name: String
    public nonisolated var category: String
    public nonisolated var dosage: String
    public nonisolated var quantity: Int
    public nonisolated var takenAt: Date
    public nonisolated var effectiveness: String
    public nonisolated var reliefStartedAt: Date?
    public nonisolated var isRepeatDose: Bool

    public nonisolated init(
        id: String,
        name: String,
        category: String,
        dosage: String,
        quantity: Int,
        takenAt: Date,
        effectiveness: String,
        reliefStartedAt: Date?,
        isRepeatDose: Bool
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.dosage = dosage
        self.quantity = quantity
        self.takenAt = takenAt
        self.effectiveness = effectiveness
        self.reliefStartedAt = reliefStartedAt
        self.isRepeatDose = isRepeatDose
    }

    public nonisolated static func == (lhs: SyncMedicationEntryPayload, rhs: SyncMedicationEntryPayload) -> Bool {
        lhs.id == rhs.id &&
            lhs.name == rhs.name &&
            lhs.category == rhs.category &&
            lhs.dosage == rhs.dosage &&
            lhs.quantity == rhs.quantity &&
            lhs.takenAt == rhs.takenAt &&
            lhs.effectiveness == rhs.effectiveness &&
            lhs.reliefStartedAt == rhs.reliefStartedAt &&
            lhs.isRepeatDose == rhs.isRepeatDose
    }
}

public struct SyncContinuousMedicationCheckPayload: Codable, Equatable, Sendable {
    public nonisolated var id: String
    public nonisolated var continuousMedicationID: String
    public nonisolated var name: String
    public nonisolated var dosage: String
    public nonisolated var frequency: String
    public nonisolated var wasTaken: Bool

    public nonisolated init(
        id: String,
        continuousMedicationID: String,
        name: String,
        dosage: String,
        frequency: String,
        wasTaken: Bool
    ) {
        self.id = id
        self.continuousMedicationID = continuousMedicationID
        self.name = name
        self.dosage = dosage
        self.frequency = frequency
        self.wasTaken = wasTaken
    }

    public nonisolated static func == (lhs: SyncContinuousMedicationCheckPayload, rhs: SyncContinuousMedicationCheckPayload) -> Bool {
        lhs.id == rhs.id &&
            lhs.continuousMedicationID == rhs.continuousMedicationID &&
            lhs.name == rhs.name &&
            lhs.dosage == rhs.dosage &&
            lhs.frequency == rhs.frequency &&
            lhs.wasTaken == rhs.wasTaken
    }
}

public struct SyncWeatherSnapshotPayload: Codable, Equatable, Sendable {
    public nonisolated var id: String
    public nonisolated var recordedAt: Date
    public nonisolated var temperature: Double?
    public nonisolated var condition: String
    public nonisolated var humidity: Double?
    public nonisolated var pressure: Double?
    public nonisolated var precipitation: Double?
    public nonisolated var weatherCode: Int?
    public nonisolated var source: String
    public nonisolated var dayRangeStart: Date?
    public nonisolated var dayRangeEnd: Date?
    public nonisolated var contextRangeStart: Date?
    public nonisolated var contextRangeEnd: Date?
    public nonisolated var contextPoints: [WeatherContextPointData]

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

    public nonisolated init(
        id: String,
        recordedAt: Date,
        temperature: Double?,
        condition: String,
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
        self.contextPoints = contextPoints
    }

    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
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

    public nonisolated static func == (lhs: SyncWeatherSnapshotPayload, rhs: SyncWeatherSnapshotPayload) -> Bool {
        lhs.id == rhs.id &&
            lhs.recordedAt == rhs.recordedAt &&
            lhs.temperature == rhs.temperature &&
            lhs.condition == rhs.condition &&
            lhs.humidity == rhs.humidity &&
            lhs.pressure == rhs.pressure &&
            lhs.precipitation == rhs.precipitation &&
            lhs.weatherCode == rhs.weatherCode &&
            lhs.source == rhs.source &&
            lhs.dayRangeStart == rhs.dayRangeStart &&
            lhs.dayRangeEnd == rhs.dayRangeEnd &&
            lhs.contextRangeStart == rhs.contextRangeStart &&
            lhs.contextRangeEnd == rhs.contextRangeEnd &&
            lhs.contextPoints == rhs.contextPoints
    }
}

public struct SyncMedicationDefinitionPayload: Codable, Equatable, Sendable {
    public nonisolated var catalogKey: String
    public nonisolated var groupID: String
    public nonisolated var groupTitle: String
    public nonisolated var groupFooter: String?
    public nonisolated var name: String
    public nonisolated var category: String
    public nonisolated var suggestedDosage: String
    public nonisolated var sortOrder: Int
    public nonisolated var isCustom: Bool
    public nonisolated var createdAt: Date

    public nonisolated init(
        catalogKey: String,
        groupID: String,
        groupTitle: String,
        groupFooter: String?,
        name: String,
        category: String,
        suggestedDosage: String,
        sortOrder: Int,
        isCustom: Bool,
        createdAt: Date
    ) {
        self.catalogKey = catalogKey
        self.groupID = groupID
        self.groupTitle = groupTitle
        self.groupFooter = groupFooter
        self.name = name
        self.category = category
        self.suggestedDosage = suggestedDosage
        self.sortOrder = sortOrder
        self.isCustom = isCustom
        self.createdAt = createdAt
    }
}

public struct SyncContinuousMedicationPayload: Codable, Equatable, Sendable {
    public nonisolated var id: String
    public nonisolated var name: String
    public nonisolated var dosage: String
    public nonisolated var frequency: String
    public nonisolated var kindRaw: String
    public nonisolated var category: String
    public nonisolated var statusRaw: String
    public nonisolated var notes: String
    public nonisolated var startDate: Date
    public nonisolated var endDate: Date?
    public nonisolated var createdAt: Date

    public nonisolated init(
        id: String,
        name: String,
        dosage: String,
        frequency: String,
        kindRaw: String = "therapy",
        category: String = "Medikamentös",
        statusRaw: String = "active",
        notes: String = "",
        startDate: Date,
        endDate: Date?,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.dosage = dosage
        self.frequency = frequency
        self.kindRaw = kindRaw
        self.category = category
        self.statusRaw = statusRaw
        self.notes = notes
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt
    }

    public nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.dosage = try container.decode(String.self, forKey: .dosage)
        self.frequency = try container.decode(String.self, forKey: .frequency)
        self.kindRaw = try container.decodeIfPresent(String.self, forKey: .kindRaw) ?? "therapy"
        self.category = try container.decodeIfPresent(String.self, forKey: .category) ?? "Medikamentös"
        self.statusRaw = try container.decodeIfPresent(String.self, forKey: .statusRaw) ?? "active"
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        self.startDate = try container.decode(Date.self, forKey: .startDate)
        self.endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

public struct SyncShadow: Codable, Equatable, Sendable {
    public nonisolated var envelope: SyncDocumentEnvelope
    public nonisolated var recordSystemFields: Data?

    public nonisolated init(envelope: SyncDocumentEnvelope, recordSystemFields: Data? = nil) {
        self.envelope = envelope
        self.recordSystemFields = recordSystemFields
    }
}

public struct SyncConflict: Codable, Equatable, Identifiable, Sendable {
    public nonisolated var id: String { documentID }
    public nonisolated var documentID: String
    public nonisolated var entityType: SyncEntityType
    public nonisolated var base: SyncDocumentEnvelope?
    public nonisolated var local: SyncDocumentEnvelope
    public nonisolated var remote: SyncDocumentEnvelope
    public nonisolated var conflictingFields: [String]
    public nonisolated var detectedAt: Date

    public nonisolated init(
        documentID: String,
        entityType: SyncEntityType,
        base: SyncDocumentEnvelope?,
        local: SyncDocumentEnvelope,
        remote: SyncDocumentEnvelope,
        conflictingFields: [String],
        detectedAt: Date = .now
    ) {
        self.documentID = documentID
        self.entityType = entityType
        self.base = base
        self.local = local
        self.remote = remote
        self.conflictingFields = conflictingFields
        self.detectedAt = detectedAt
    }
}

public enum SyncUploadPlanner {
    public nonisolated static func pendingRecordNames(
        envelopes: [SyncDocumentEnvelope],
        shadows: [String: SyncShadow],
        conflicts: [SyncConflict]
    ) -> [String] {
        let conflictedDocumentIDs = Set(conflicts.map(\.documentID))

        return envelopes
            .filter { !conflictedDocumentIDs.contains($0.documentID) }
            .filter { shadows[$0.documentID]?.envelope != $0 }
            .map(\.documentID)
    }
}

public struct SyncMergeResult: Equatable, Sendable {
    public nonisolated var merged: SyncDocumentEnvelope
    public nonisolated var conflicts: [String]

    public nonisolated init(merged: SyncDocumentEnvelope, conflicts: [String]) {
        self.merged = merged
        self.conflicts = conflicts
    }
}

public enum SyncMergeEngine {
    public nonisolated static func merge(
        base: SyncDocumentEnvelope?,
        local: SyncDocumentEnvelope,
        remote: SyncDocumentEnvelope
    ) -> SyncMergeResult {
        precondition(local.documentID == remote.documentID, "Dokument-IDs müssen übereinstimmen.")
        precondition(local.entityType == remote.entityType, "Entitätstypen müssen übereinstimmen.")

        let conflicts: [String]
        let payload: SyncDocumentEnvelope.Payload

        switch (local.payload, remote.payload) {
        case (.episode(let localPayload), .episode(let remotePayload)):
            let basePayload = base?.payload.episodePayload
            let result = mergeEpisode(base: basePayload, local: localPayload, remote: remotePayload)
            payload = .episode(result.payload)
            conflicts = result.conflicts
        case (.medicationDefinition(let localPayload), .medicationDefinition(let remotePayload)):
            let basePayload = base?.payload.medicationDefinitionPayload
            let result = mergeMedicationDefinition(base: basePayload, local: localPayload, remote: remotePayload)
            payload = .medicationDefinition(result.payload)
            conflicts = result.conflicts
        case (.continuousMedication(let localPayload), .continuousMedication(let remotePayload)):
            let basePayload = base?.payload.continuousMedicationPayload
            let result = mergeContinuousMedication(base: basePayload, local: localPayload, remote: remotePayload)
            payload = .continuousMedication(result.payload)
            conflicts = result.conflicts
        default:
            payload = local.payload
            conflicts = ["payload"]
        }

        let deletedAt = mergedValue(field: "deletedAt", base: base?.deletedAt, local: local.deletedAt, remote: remote.deletedAt).value
        let modifiedAt = max(local.modifiedAt, remote.modifiedAt)

        return SyncMergeResult(
            merged: SyncDocumentEnvelope(
                documentID: local.documentID,
                entityType: local.entityType,
                schemaVersion: max(local.schemaVersion, remote.schemaVersion),
                modifiedAt: modifiedAt,
                authorDeviceID: local.authorDeviceID,
                deletedAt: deletedAt,
                payload: payload
            ),
            conflicts: conflicts
        )
    }

    private nonisolated static func mergeEpisode(
        base: SyncEpisodePayload?,
        local: SyncEpisodePayload,
        remote: SyncEpisodePayload
    ) -> (payload: SyncEpisodePayload, conflicts: [String]) {
        var conflicts: [String] = []

        let startedAt = mergedValue(field: "startedAt", base: base?.startedAt, local: local.startedAt, remote: remote.startedAt, conflicts: &conflicts).value
        let endedAt = mergedValue(field: "endedAt", base: base?.endedAt, local: local.endedAt, remote: remote.endedAt, conflicts: &conflicts).value
        let type = mergedValue(field: "type", base: base?.type, local: local.type, remote: remote.type, conflicts: &conflicts).value
        let intensity = mergedValue(field: "intensity", base: base?.intensity, local: local.intensity, remote: remote.intensity, conflicts: &conflicts).value
        let intensityLevel = mergedValue(field: "intensityLevel", base: base?.intensityLevel, local: local.intensityLevel, remote: remote.intensityLevel, conflicts: &conflicts).value
        let painLocation = mergedValue(field: "painLocation", base: base?.painLocation, local: local.painLocation, remote: remote.painLocation, conflicts: &conflicts).value
        let painCharacter = mergedValue(field: "painCharacter", base: base?.painCharacter, local: local.painCharacter, remote: remote.painCharacter, conflicts: &conflicts).value
        let notes = mergedValue(field: "notes", base: base?.notes, local: local.notes, remote: remote.notes, conflicts: &conflicts).value
        let symptoms = mergedValue(field: "symptoms", base: base?.symptoms, local: local.symptoms, remote: remote.symptoms, conflicts: &conflicts).value
        let triggers = mergedValue(field: "triggers", base: base?.triggers, local: local.triggers, remote: remote.triggers, conflicts: &conflicts).value
        let functionalImpact = mergedValue(field: "functionalImpact", base: base?.functionalImpact, local: local.functionalImpact, remote: remote.functionalImpact, conflicts: &conflicts).value
        let menstruationStatus = mergedValue(field: "menstruationStatus", base: base?.menstruationStatus, local: local.menstruationStatus, remote: remote.menstruationStatus, conflicts: &conflicts).value

        let medications = mergeMedicationEntries(
            base: index(base?.medications ?? []),
            local: index(local.medications),
            remote: index(remote.medications),
            conflicts: &conflicts
        )
        let continuousMedicationChecks = mergeContinuousMedicationChecks(
            base: index(base?.continuousMedicationChecks ?? []),
            local: index(local.continuousMedicationChecks),
            remote: index(remote.continuousMedicationChecks),
            conflicts: &conflicts
        )

        let weather = mergeWeather(
            base: base?.weatherSnapshot,
            local: local.weatherSnapshot,
            remote: remote.weatherSnapshot,
            conflicts: &conflicts
        )
        let healthContext = mergeHealthContext(
            base: base,
            local: local,
            remote: remote,
            conflicts: &conflicts
        )

        return (
            SyncEpisodePayload(
                id: local.id,
                startedAt: startedAt,
                endedAt: endedAt,
                type: type,
                intensity: intensity,
                intensityLevel: intensityLevel,
                painLocation: painLocation,
                painCharacter: painCharacter,
                notes: notes,
                symptoms: symptoms,
                triggers: triggers,
                functionalImpact: functionalImpact,
                menstruationStatus: menstruationStatus,
                medications: medications.sorted { $0.takenAt < $1.takenAt },
                continuousMedicationChecks: continuousMedicationChecks.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending },
                weatherSnapshot: weather,
                healthContext: healthContext,
                includesHealthContext: local.includesHealthContext || remote.includesHealthContext
            ),
            conflicts
        )
    }

    private nonisolated static func mergeContinuousMedication(
        base: SyncContinuousMedicationPayload?,
        local: SyncContinuousMedicationPayload,
        remote: SyncContinuousMedicationPayload
    ) -> (payload: SyncContinuousMedicationPayload, conflicts: [String]) {
        var conflicts: [String] = []

        return (
            SyncContinuousMedicationPayload(
                id: local.id,
                name: mergedValue(field: "name", base: base?.name, local: local.name, remote: remote.name, conflicts: &conflicts).value,
                dosage: mergedValue(field: "dosage", base: base?.dosage, local: local.dosage, remote: remote.dosage, conflicts: &conflicts).value,
                frequency: mergedValue(field: "frequency", base: base?.frequency, local: local.frequency, remote: remote.frequency, conflicts: &conflicts).value,
                kindRaw: mergedValue(field: "kindRaw", base: base?.kindRaw, local: local.kindRaw, remote: remote.kindRaw, conflicts: &conflicts).value,
                category: mergedValue(field: "category", base: base?.category, local: local.category, remote: remote.category, conflicts: &conflicts).value,
                statusRaw: mergedValue(field: "statusRaw", base: base?.statusRaw, local: local.statusRaw, remote: remote.statusRaw, conflicts: &conflicts).value,
                notes: mergedValue(field: "notes", base: base?.notes, local: local.notes, remote: remote.notes, conflicts: &conflicts).value,
                startDate: mergedValue(field: "startDate", base: base?.startDate, local: local.startDate, remote: remote.startDate, conflicts: &conflicts).value,
                endDate: mergedValue(field: "endDate", base: base?.endDate, local: local.endDate, remote: remote.endDate, conflicts: &conflicts).value,
                createdAt: mergedValue(field: "createdAt", base: base?.createdAt, local: local.createdAt, remote: remote.createdAt, conflicts: &conflicts).value
            ),
            conflicts
        )
    }

    private nonisolated static func mergeMedicationDefinition(
        base: SyncMedicationDefinitionPayload?,
        local: SyncMedicationDefinitionPayload,
        remote: SyncMedicationDefinitionPayload
    ) -> (payload: SyncMedicationDefinitionPayload, conflicts: [String]) {
        var conflicts: [String] = []

        return (
            SyncMedicationDefinitionPayload(
                catalogKey: local.catalogKey,
                groupID: mergedValue(field: "groupID", base: base?.groupID, local: local.groupID, remote: remote.groupID, conflicts: &conflicts).value,
                groupTitle: mergedValue(field: "groupTitle", base: base?.groupTitle, local: local.groupTitle, remote: remote.groupTitle, conflicts: &conflicts).value,
                groupFooter: mergedValue(field: "groupFooter", base: base?.groupFooter, local: local.groupFooter, remote: remote.groupFooter, conflicts: &conflicts).value,
                name: mergedValue(field: "name", base: base?.name, local: local.name, remote: remote.name, conflicts: &conflicts).value,
                category: mergedValue(field: "category", base: base?.category, local: local.category, remote: remote.category, conflicts: &conflicts).value,
                suggestedDosage: mergedValue(field: "suggestedDosage", base: base?.suggestedDosage, local: local.suggestedDosage, remote: remote.suggestedDosage, conflicts: &conflicts).value,
                sortOrder: mergedValue(field: "sortOrder", base: base?.sortOrder, local: local.sortOrder, remote: remote.sortOrder, conflicts: &conflicts).value,
                isCustom: mergedValue(field: "isCustom", base: base?.isCustom, local: local.isCustom, remote: remote.isCustom, conflicts: &conflicts).value,
                createdAt: mergedValue(field: "createdAt", base: base?.createdAt, local: local.createdAt, remote: remote.createdAt, conflicts: &conflicts).value
            ),
            conflicts
        )
    }

    private nonisolated static func mergeContinuousMedicationChecks(
        base: [String: SyncContinuousMedicationCheckPayload],
        local: [String: SyncContinuousMedicationCheckPayload],
        remote: [String: SyncContinuousMedicationCheckPayload],
        conflicts: inout [String]
    ) -> [SyncContinuousMedicationCheckPayload] {
        let ids = Set(base.keys).union(local.keys).union(remote.keys)

        return ids.compactMap { id in
            switch (base[id], local[id], remote[id]) {
            case let (base?, local?, remote?):
                return SyncContinuousMedicationCheckPayload(
                    id: id,
                    continuousMedicationID: mergedValue(field: "continuousMedicationChecks.\(id).continuousMedicationID", base: base.continuousMedicationID, local: local.continuousMedicationID, remote: remote.continuousMedicationID, conflicts: &conflicts).value,
                    name: mergedValue(field: "continuousMedicationChecks.\(id).name", base: base.name, local: local.name, remote: remote.name, conflicts: &conflicts).value,
                    dosage: mergedValue(field: "continuousMedicationChecks.\(id).dosage", base: base.dosage, local: local.dosage, remote: remote.dosage, conflicts: &conflicts).value,
                    frequency: mergedValue(field: "continuousMedicationChecks.\(id).frequency", base: base.frequency, local: local.frequency, remote: remote.frequency, conflicts: &conflicts).value,
                    wasTaken: mergedValue(field: "continuousMedicationChecks.\(id).wasTaken", base: base.wasTaken, local: local.wasTaken, remote: remote.wasTaken, conflicts: &conflicts).value
                )
            case let (nil, local?, nil):
                return local
            case let (nil, nil, remote?):
                return remote
            case let (nil, local?, remote?):
                if local == remote {
                    return local
                }
                conflicts.append("continuousMedicationChecks.\(id)")
                return local
            case let (base?, local?, nil):
                return local == base ? nil : local
            case let (base?, nil, remote?):
                return remote == base ? nil : remote
            default:
                return nil
            }
        }
    }

    private nonisolated static func mergeMedicationEntries(
        base: [String: SyncMedicationEntryPayload],
        local: [String: SyncMedicationEntryPayload],
        remote: [String: SyncMedicationEntryPayload],
        conflicts: inout [String]
    ) -> [SyncMedicationEntryPayload] {
        let ids = Set(base.keys).union(local.keys).union(remote.keys)

        return ids.compactMap { id in
            switch (base[id], local[id], remote[id]) {
            case let (base?, local?, remote?):
                let merged = SyncMedicationEntryPayload(
                    id: id,
                    name: mergedValue(field: "medications.\(id).name", base: base.name, local: local.name, remote: remote.name, conflicts: &conflicts).value,
                    category: mergedValue(field: "medications.\(id).category", base: base.category, local: local.category, remote: remote.category, conflicts: &conflicts).value,
                    dosage: mergedValue(field: "medications.\(id).dosage", base: base.dosage, local: local.dosage, remote: remote.dosage, conflicts: &conflicts).value,
                    quantity: mergedValue(field: "medications.\(id).quantity", base: base.quantity, local: local.quantity, remote: remote.quantity, conflicts: &conflicts).value,
                    takenAt: mergedValue(field: "medications.\(id).takenAt", base: base.takenAt, local: local.takenAt, remote: remote.takenAt, conflicts: &conflicts).value,
                    effectiveness: mergedValue(field: "medications.\(id).effectiveness", base: base.effectiveness, local: local.effectiveness, remote: remote.effectiveness, conflicts: &conflicts).value,
                    reliefStartedAt: mergedValue(field: "medications.\(id).reliefStartedAt", base: base.reliefStartedAt, local: local.reliefStartedAt, remote: remote.reliefStartedAt, conflicts: &conflicts).value,
                    isRepeatDose: mergedValue(field: "medications.\(id).isRepeatDose", base: base.isRepeatDose, local: local.isRepeatDose, remote: remote.isRepeatDose, conflicts: &conflicts).value
                )
                return merged
            case let (nil, local?, nil):
                return local
            case let (nil, nil, remote?):
                return remote
            case let (nil, local?, remote?):
                if local == remote {
                    return local
                }
                conflicts.append("medications.\(id)")
                return local
            case let (base?, local?, nil):
                if local == base {
                    return nil
                }
                return local
            case let (base?, nil, remote?):
                if remote == base {
                    return nil
                }
                return remote
            default:
                return nil
            }
        }
    }

    private nonisolated static func mergeWeather(
        base: SyncWeatherSnapshotPayload?,
        local: SyncWeatherSnapshotPayload?,
        remote: SyncWeatherSnapshotPayload?,
        conflicts: inout [String]
    ) -> SyncWeatherSnapshotPayload? {
        switch (base, local, remote) {
        case let (base?, local?, remote?):
            return SyncWeatherSnapshotPayload(
                id: local.id,
                recordedAt: mergedValue(field: "weather.recordedAt", base: base.recordedAt, local: local.recordedAt, remote: remote.recordedAt, conflicts: &conflicts).value,
                temperature: mergedValue(field: "weather.temperature", base: base.temperature, local: local.temperature, remote: remote.temperature, conflicts: &conflicts).value,
                condition: mergedValue(field: "weather.condition", base: base.condition, local: local.condition, remote: remote.condition, conflicts: &conflicts).value,
                humidity: mergedValue(field: "weather.humidity", base: base.humidity, local: local.humidity, remote: remote.humidity, conflicts: &conflicts).value,
                pressure: mergedValue(field: "weather.pressure", base: base.pressure, local: local.pressure, remote: remote.pressure, conflicts: &conflicts).value,
                precipitation: mergedValue(field: "weather.precipitation", base: base.precipitation, local: local.precipitation, remote: remote.precipitation, conflicts: &conflicts).value,
                weatherCode: mergedValue(field: "weather.weatherCode", base: base.weatherCode, local: local.weatherCode, remote: remote.weatherCode, conflicts: &conflicts).value,
                source: mergedValue(field: "weather.source", base: base.source, local: local.source, remote: remote.source, conflicts: &conflicts).value,
                dayRangeStart: mergedValue(field: "weather.dayRangeStart", base: base.dayRangeStart, local: local.dayRangeStart, remote: remote.dayRangeStart, conflicts: &conflicts).value,
                dayRangeEnd: mergedValue(field: "weather.dayRangeEnd", base: base.dayRangeEnd, local: local.dayRangeEnd, remote: remote.dayRangeEnd, conflicts: &conflicts).value,
                contextRangeStart: mergedValue(field: "weather.contextRangeStart", base: base.contextRangeStart, local: local.contextRangeStart, remote: remote.contextRangeStart, conflicts: &conflicts).value,
                contextRangeEnd: mergedValue(field: "weather.contextRangeEnd", base: base.contextRangeEnd, local: local.contextRangeEnd, remote: remote.contextRangeEnd, conflicts: &conflicts).value,
                contextPoints: mergedValue(field: "weather.contextPoints", base: base.contextPoints, local: local.contextPoints, remote: remote.contextPoints, conflicts: &conflicts).value
            )
        case let (nil, local?, nil):
            return local
        case let (nil, nil, remote?):
            return remote
        case let (nil, local?, remote?):
            if local == remote {
                return local
            }
            conflicts.append("weather")
            return local
        case let (base?, local?, nil):
            return local == base ? nil : local
        case let (base?, nil, remote?):
            return remote == base ? nil : remote
        default:
            return nil
        }
    }

    private nonisolated static func mergeHealthContext(
        base: SyncEpisodePayload?,
        local: SyncEpisodePayload,
        remote: SyncEpisodePayload,
        conflicts: inout [String]
    ) -> HealthContextSnapshotData? {
        switch (base?.includesHealthContext == true ? base?.healthContext : nil, local.includesHealthContext, remote.includesHealthContext) {
        case let (baseHealthContext, true, true):
            return mergedValue(field: "healthContext", base: baseHealthContext, local: local.healthContext, remote: remote.healthContext, conflicts: &conflicts).value
        case (_, true, false):
            return local.healthContext
        case (_, false, true):
            return remote.healthContext
        default:
            return nil
        }
    }

    private nonisolated static func index(_ entries: [SyncMedicationEntryPayload]) -> [String: SyncMedicationEntryPayload] {
        Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
    }

    private nonisolated static func index(_ entries: [SyncContinuousMedicationCheckPayload]) -> [String: SyncContinuousMedicationCheckPayload] {
        Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
    }

    private nonisolated static func mergedValue<T: Equatable>(
        field: String,
        base: T?,
        local: T,
        remote: T,
        conflicts: inout [String]
    ) -> (value: T, conflict: Bool) {
        let result = mergedValue(field: field, base: base, local: local, remote: remote)
        if result.conflict {
            conflicts.append(field)
        }
        return result
    }

    private nonisolated static func mergedValue<T: Equatable>(
        field _: String,
        base: T?,
        local: T,
        remote: T
    ) -> (value: T, conflict: Bool) {
        if local == remote {
            return (local, false)
        }

        guard let base else {
            return (local, true)
        }

        let localChanged = local != base
        let remoteChanged = remote != base

        switch (localChanged, remoteChanged) {
        case (true, false):
            return (local, false)
        case (false, true):
            return (remote, false)
        case (false, false):
            return (local, false)
        case (true, true):
            return (local, true)
        }
    }
}

private extension SyncDocumentEnvelope.Payload {
    nonisolated var episodePayload: SyncEpisodePayload? {
        guard case .episode(let payload) = self else {
            return nil
        }

        return payload
    }

    nonisolated var medicationDefinitionPayload: SyncMedicationDefinitionPayload? {
        guard case .medicationDefinition(let payload) = self else {
            return nil
        }

        return payload
    }

    nonisolated var continuousMedicationPayload: SyncContinuousMedicationPayload? {
        guard case .continuousMedication(let payload) = self else {
            return nil
        }

        return payload
    }
}
