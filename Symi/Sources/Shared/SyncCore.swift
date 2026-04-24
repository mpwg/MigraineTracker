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
            "Kein iCloud-Account"
        case .offline:
            "Offline"
        }
    }
}

public enum SyncEntityType: String, Codable, CaseIterable, Sendable {
    case episode
    case medicationDefinition
}

public struct SyncStatusSnapshot: Codable, Equatable, Sendable {
    public nonisolated var state: SyncServiceState
    public nonisolated var service: String
    public nonisolated var queuedUpdates: Int
    public nonisolated var unsyncedRecords: Int
    public nonisolated var lastDownloadedAt: Date?
    public nonisolated var lastUploadedAt: Date?
    public nonisolated var lastError: String?

    public nonisolated init(
        state: SyncServiceState = .disabled,
        service: String = "iCloud",
        queuedUpdates: Int = 0,
        unsyncedRecords: Int = 0,
        lastDownloadedAt: Date? = nil,
        lastUploadedAt: Date? = nil,
        lastError: String? = nil
    ) {
        self.state = state
        self.service = service
        self.queuedUpdates = queuedUpdates
        self.unsyncedRecords = unsyncedRecords
        self.lastDownloadedAt = lastDownloadedAt
        self.lastUploadedAt = lastUploadedAt
        self.lastError = lastError
    }
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
        schemaVersion: Int = 1,
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

        private enum CodingKeys: String, CodingKey {
            case episode
            case medicationDefinition
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
    public nonisolated var painLocation: String
    public nonisolated var painCharacter: String
    public nonisolated var notes: String
    public nonisolated var symptoms: [String]
    public nonisolated var triggers: [String]
    public nonisolated var functionalImpact: String
    public nonisolated var menstruationStatus: String
    public nonisolated var medications: [SyncMedicationEntryPayload]
    public nonisolated var weatherSnapshot: SyncWeatherSnapshotPayload?

    public nonisolated init(
        id: String,
        startedAt: Date,
        endedAt: Date?,
        type: String,
        intensity: Int,
        painLocation: String,
        painCharacter: String,
        notes: String,
        symptoms: [String],
        triggers: [String],
        functionalImpact: String,
        menstruationStatus: String,
        medications: [SyncMedicationEntryPayload],
        weatherSnapshot: SyncWeatherSnapshotPayload?
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.type = type
        self.intensity = intensity
        self.painLocation = painLocation
        self.painCharacter = painCharacter
        self.notes = notes
        self.symptoms = symptoms
        self.triggers = triggers
        self.functionalImpact = functionalImpact
        self.menstruationStatus = menstruationStatus
        self.medications = medications
        self.weatherSnapshot = weatherSnapshot
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

    public nonisolated init(
        id: String,
        recordedAt: Date,
        temperature: Double?,
        condition: String,
        humidity: Double?,
        pressure: Double?,
        precipitation: Double?,
        weatherCode: Int?,
        source: String
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
            lhs.source == rhs.source
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

        let weather = mergeWeather(
            base: base?.weatherSnapshot,
            local: local.weatherSnapshot,
            remote: remote.weatherSnapshot,
            conflicts: &conflicts
        )

        return (
            SyncEpisodePayload(
                id: local.id,
                startedAt: startedAt,
                endedAt: endedAt,
                type: type,
                intensity: intensity,
                painLocation: painLocation,
                painCharacter: painCharacter,
                notes: notes,
                symptoms: symptoms,
                triggers: triggers,
                functionalImpact: functionalImpact,
                menstruationStatus: menstruationStatus,
                medications: medications.sorted { $0.takenAt < $1.takenAt },
                weatherSnapshot: weather
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
                source: mergedValue(field: "weather.source", base: base.source, local: local.source, remote: remote.source, conflicts: &conflicts).value
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

    private nonisolated static func index(_ entries: [SyncMedicationEntryPayload]) -> [String: SyncMedicationEntryPayload] {
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
}
