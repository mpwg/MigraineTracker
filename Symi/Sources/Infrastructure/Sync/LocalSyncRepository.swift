import Foundation
import SwiftData

@MainActor
struct LocalSyncRepository {
    let modelContainer: ModelContainer
    let healthContextStore: HealthContextStore

    init(modelContainer: ModelContainer, healthContextStore: HealthContextStore = HealthContextStore()) {
        self.modelContainer = modelContainer
        self.healthContextStore = healthContextStore
    }

    func allEnvelopes(deviceID: String) throws -> [SyncDocumentEnvelope] {
        let context = ModelContext(modelContainer)
        let episodes = try context.fetch(FetchDescriptor<Episode>())
        let customDefinitions = try context.fetch(FetchDescriptor<MedicationDefinition>())
            .filter(\.isCustom)
        let continuousMedications = try context.fetch(FetchDescriptor<ContinuousMedication>())

        try episodes.forEach(DomainValidator.validate)
        try continuousMedications.forEach(DomainValidator.validate)

        return episodes.map { $0.syncEnvelope(deviceID: deviceID, healthContextStore: healthContextStore) } +
            customDefinitions.map { $0.syncEnvelope(deviceID: deviceID) } +
            continuousMedications.map { $0.syncEnvelope(deviceID: deviceID) }
    }

    func envelope(documentID: String, deviceID: String) throws -> SyncDocumentEnvelope? {
        let envelopes = try allEnvelopes(deviceID: deviceID)
        return envelopes.first { $0.documentID == documentID }
    }

    func validate(remote envelope: SyncDocumentEnvelope) throws {
        try RemoteSyncPayloadValidator.validate(envelope)
    }

    func apply(remote envelope: SyncDocumentEnvelope) throws {
        try validate(remote: envelope)

        let context = ModelContext(modelContainer)

        switch envelope.payload {
        case .episode(let payload):
            try applyEpisodePayload(payload, from: envelope, in: context)
        case .medicationDefinition(let payload):
            try applyMedicationDefinitionPayload(payload, from: envelope, in: context)
        case .continuousMedication(let payload):
            try applyContinuousMedicationPayload(payload, from: envelope, in: context)
        }

        try context.save()
    }

    private func applyEpisodePayload(
        _ payload: SyncEpisodePayload,
        from envelope: SyncDocumentEnvelope,
        in context: ModelContext
    ) throws {
        let episodeID = try RemoteSyncPayloadValidator.uuid(payload.id, field: "episode.id")
        let existing = try context.fetch(FetchDescriptor<Episode>()).first { $0.id == episodeID }
        let target = existing ?? Episode(
            id: episodeID,
            startedAt: payload.startedAt,
            endedAt: payload.endedAt,
            updatedAt: envelope.modifiedAt,
            deletedAt: envelope.deletedAt,
            type: EpisodeType(storageValue: payload.type),
            intensity: payload.intensity
        )

        target.startedAt = payload.startedAt
        target.endedAt = payload.endedAt
        target.updatedAt = envelope.modifiedAt
        target.deletedAt = envelope.deletedAt
        target.type = EpisodeType(storageValue: payload.type)
        target.intensity = payload.intensity
        target.painLocation = payload.painLocation
        target.painCharacter = payload.painCharacter
        target.notes = payload.notes
        target.symptoms = payload.symptoms
        target.triggers = payload.triggers
        target.functionalImpact = payload.functionalImpact
        target.menstruationStatus = MenstruationStatus(storageValue: payload.menstruationStatus)

        for medication in target.medications {
            context.delete(medication)
        }

        for check in target.continuousMedicationChecks {
            context.delete(check)
        }

        if let weatherSnapshot = target.weatherSnapshot {
            context.delete(weatherSnapshot)
            target.weatherSnapshot = nil
        }

        target.medications = try payload.medications.map { medication in
            MedicationEntry(
                id: try RemoteSyncPayloadValidator.uuid(medication.id, field: "episode.medications.id"),
                name: medication.name,
                category: MedicationCategory(storageValue: medication.category),
                dosage: medication.dosage,
                quantity: medication.quantity,
                takenAt: medication.takenAt,
                effectiveness: MedicationEffectiveness(storageValue: medication.effectiveness),
                reliefStartedAt: medication.reliefStartedAt,
                isRepeatDose: medication.isRepeatDose,
                episode: target
            )
        }
        target.continuousMedicationChecks = try payload.continuousMedicationChecks.map { check in
            ContinuousMedicationCheck(
                id: try RemoteSyncPayloadValidator.uuid(check.id, field: "episode.continuousMedicationChecks.id"),
                continuousMedicationID: try RemoteSyncPayloadValidator.uuid(check.continuousMedicationID, field: "episode.continuousMedicationChecks.continuousMedicationID"),
                name: check.name,
                dosage: check.dosage,
                frequency: check.frequency,
                wasTaken: check.wasTaken,
                episode: target
            )
        }
        if let weather = payload.weatherSnapshot {
            target.weatherSnapshot = WeatherSnapshot(
                id: try RemoteSyncPayloadValidator.uuid(weather.id, field: "episode.weatherSnapshot.id"),
                recordedAt: weather.recordedAt,
                temperature: weather.temperature,
                condition: weather.condition,
                humidity: weather.humidity,
                pressure: weather.pressure,
                precipitation: weather.precipitation,
                weatherCode: weather.weatherCode,
                source: weather.source,
                dayRangeStart: weather.dayRangeStart,
                dayRangeEnd: weather.dayRangeEnd,
                contextRangeStart: weather.contextRangeStart,
                contextRangeEnd: weather.contextRangeEnd,
                contextPointsStorage: WeatherSnapshot.encodeContextPoints(weather.contextPoints),
                episode: target
            )
        } else {
            target.weatherSnapshot = nil
        }

        if existing == nil {
            context.insert(target)
        }

        try DomainValidator.validate(target)

        if payload.includesHealthContext {
            try healthContextStore.save(payload.healthContext, for: episodeID)
        }
    }

    private func applyMedicationDefinitionPayload(
        _ payload: SyncMedicationDefinitionPayload,
        from envelope: SyncDocumentEnvelope,
        in context: ModelContext
    ) throws {
        let existing = try context.fetch(FetchDescriptor<MedicationDefinition>()).first { $0.catalogKey == payload.catalogKey }
        let target = existing ?? MedicationDefinition(
            catalogKey: payload.catalogKey,
            groupID: payload.groupID,
            groupTitle: payload.groupTitle,
            groupFooter: payload.groupFooter,
            name: payload.name,
            category: MedicationCategory(storageValue: payload.category),
            suggestedDosage: payload.suggestedDosage,
            sortOrder: payload.sortOrder,
            isCustom: payload.isCustom,
            createdAt: payload.createdAt,
            updatedAt: envelope.modifiedAt,
            deletedAt: envelope.deletedAt
        )

        target.groupID = payload.groupID
        target.groupTitle = payload.groupTitle
        target.groupFooter = payload.groupFooter
        target.name = payload.name
        target.category = MedicationCategory(storageValue: payload.category)
        target.suggestedDosage = payload.suggestedDosage
        target.sortOrder = payload.sortOrder
        target.isCustom = payload.isCustom
        target.createdAt = payload.createdAt
        target.updatedAt = envelope.modifiedAt
        target.deletedAt = envelope.deletedAt

        if existing == nil {
            context.insert(target)
        }
    }

    private func applyContinuousMedicationPayload(
        _ payload: SyncContinuousMedicationPayload,
        from envelope: SyncDocumentEnvelope,
        in context: ModelContext
    ) throws {
        let medicationID = try RemoteSyncPayloadValidator.uuid(payload.id, field: "continuousMedication.id")
        let existing = try context.fetch(FetchDescriptor<ContinuousMedication>()).first { $0.id == medicationID }
        let target = existing ?? ContinuousMedication(
            id: medicationID,
            name: payload.name,
            dosage: payload.dosage,
            frequency: payload.frequency,
            startDate: payload.startDate,
            endDate: payload.endDate,
            createdAt: payload.createdAt,
            updatedAt: envelope.modifiedAt
        )

        target.name = payload.name
        target.dosage = payload.dosage
        target.frequency = payload.frequency
        target.startDate = payload.startDate
        target.endDate = payload.endDate
        target.createdAt = payload.createdAt
        target.updatedAt = envelope.modifiedAt

        if existing == nil {
            context.insert(target)
        }

        try DomainValidator.validate(target)
    }
}

enum RemoteSyncPayloadValidationError: LocalizedError, Equatable {
    case invalidPayload(documentID: String, issues: [String])

    var errorDescription: String? {
        switch self {
        case .invalidPayload(let documentID, let issues):
            "Remote-Payload \(documentID) ist ungültig: \(issues.joined(separator: ", "))"
        }
    }

    var issues: [String] {
        switch self {
        case .invalidPayload(_, let issues):
            issues
        }
    }
}

enum RemoteSyncPayloadValidator {
    static func validate(_ envelope: SyncDocumentEnvelope) throws {
        let issues = validationIssues(for: envelope)
        guard issues.isEmpty else {
            throw RemoteSyncPayloadValidationError.invalidPayload(
                documentID: envelope.documentID,
                issues: issues
            )
        }
    }

    static func uuid(_ value: String, field: String) throws -> UUID {
        guard let id = UUID(uuidString: value) else {
            throw RemoteSyncPayloadValidationError.invalidPayload(
                documentID: field,
                issues: ["\(field) ist keine gültige UUID"]
            )
        }

        return id
    }

    private static func validationIssues(for envelope: SyncDocumentEnvelope) -> [String] {
        var issues: [String] = []

        if envelope.entityType != envelope.payload.entityType {
            issues.append("entityType passt nicht zur Payload")
        }

        if !SyncPayloadSchema.supports(envelope.schemaVersion, for: envelope.entityType) {
            let supportedVersions = SyncPayloadSchema.supportedVersions(for: envelope.entityType)
            issues.append("schemaVersion \(envelope.schemaVersion) wird für \(envelope.entityType.rawValue) nicht unterstützt; unterstützt wird \(supportedVersions.lowerBound)...\(supportedVersions.upperBound)")
        }

        if let byteCount = CloudKitRecordCodec.payloadByteCount(for: envelope),
           byteCount > SyncPayloadSchema.maximumCloudKitPayloadBytes {
            issues.append("payloadJSON ist mit \(byteCount) Bytes größer als das Limit von \(SyncPayloadSchema.maximumCloudKitPayloadBytes) Bytes")
        }

        switch envelope.payload {
        case .episode(let payload):
            validateUUID(payload.id, field: "episode.id", into: &issues)
            validateDocumentID(envelope.documentID, expectedPrefix: "episode", payloadID: payload.id, into: &issues)
            validateKnownValue(payload.type, field: "episode.type", allowedValues: episodeTypeValues, into: &issues)
            validateKnownValue(payload.menstruationStatus, field: "episode.menstruationStatus", allowedValues: menstruationStatusValues, into: &issues)

            for (index, medication) in payload.medications.enumerated() {
                validateUUID(medication.id, field: "episode.medications[\(index)].id", into: &issues)
                validateKnownValue(medication.category, field: "episode.medications[\(index)].category", allowedValues: medicationCategoryValues, into: &issues)
                validateKnownValue(medication.effectiveness, field: "episode.medications[\(index)].effectiveness", allowedValues: medicationEffectivenessValues, into: &issues)
            }

            for (index, check) in payload.continuousMedicationChecks.enumerated() {
                validateUUID(check.id, field: "episode.continuousMedicationChecks[\(index)].id", into: &issues)
                validateUUID(check.continuousMedicationID, field: "episode.continuousMedicationChecks[\(index)].continuousMedicationID", into: &issues)
            }

            if let weatherSnapshot = payload.weatherSnapshot {
                validateUUID(weatherSnapshot.id, field: "episode.weatherSnapshot.id", into: &issues)
            }

            issues.append(contentsOf: domainIssues(for: payload, path: "episode"))
        case .medicationDefinition(let payload):
            validateDocumentID(envelope.documentID, expectedPrefix: "medicationDefinition", payloadID: payload.catalogKey, into: &issues)
            validateKnownValue(payload.category, field: "medicationDefinition.category", allowedValues: medicationCategoryValues, into: &issues)
        case .continuousMedication(let payload):
            validateUUID(payload.id, field: "continuousMedication.id", into: &issues)
            validateDocumentID(envelope.documentID, expectedPrefix: "continuousMedication", payloadID: payload.id, into: &issues)
            issues.append(contentsOf: domainIssues(for: payload, path: "continuousMedication"))
        }

        return issues
    }

    private static func domainIssues(for payload: SyncEpisodePayload, path: String) -> [String] {
        guard let episodeID = UUID(uuidString: payload.id) else {
            return []
        }

        let episode = Episode(
            id: episodeID,
            startedAt: payload.startedAt,
            endedAt: payload.endedAt,
            type: EpisodeType(storageValue: payload.type),
            intensity: payload.intensity,
            painLocation: payload.painLocation,
            painCharacter: payload.painCharacter,
            notes: payload.notes,
            symptoms: payload.symptoms,
            triggers: payload.triggers,
            functionalImpact: payload.functionalImpact,
            menstruationStatus: MenstruationStatus(storageValue: payload.menstruationStatus)
        )

        episode.medications = payload.medications.compactMap { medication in
            guard let medicationID = UUID(uuidString: medication.id) else {
                return nil
            }

            return MedicationEntry(
                id: medicationID,
                name: medication.name,
                category: MedicationCategory(storageValue: medication.category),
                dosage: medication.dosage,
                quantity: medication.quantity,
                takenAt: medication.takenAt,
                effectiveness: MedicationEffectiveness(storageValue: medication.effectiveness),
                reliefStartedAt: medication.reliefStartedAt,
                isRepeatDose: medication.isRepeatDose,
                episode: episode
            )
        }

        episode.continuousMedicationChecks = payload.continuousMedicationChecks.compactMap { check in
            guard
                let checkID = UUID(uuidString: check.id),
                let medicationID = UUID(uuidString: check.continuousMedicationID)
            else {
                return nil
            }

            return ContinuousMedicationCheck(
                id: checkID,
                continuousMedicationID: medicationID,
                name: check.name,
                dosage: check.dosage,
                frequency: check.frequency,
                wasTaken: check.wasTaken,
                episode: episode
            )
        }

        if
            let weather = payload.weatherSnapshot,
            let weatherID = UUID(uuidString: weather.id) {
            episode.weatherSnapshot = WeatherSnapshot(
                id: weatherID,
                recordedAt: weather.recordedAt,
                temperature: weather.temperature,
                condition: weather.condition,
                humidity: weather.humidity,
                pressure: weather.pressure,
                precipitation: weather.precipitation,
                weatherCode: weather.weatherCode,
                source: weather.source,
                dayRangeStart: weather.dayRangeStart,
                dayRangeEnd: weather.dayRangeEnd,
                contextRangeStart: weather.contextRangeStart,
                contextRangeEnd: weather.contextRangeEnd,
                contextPointsStorage: WeatherSnapshot.encodeContextPoints(weather.contextPoints),
                episode: episode
            )
        }

        return DomainValidator.episodeIssues(for: episode, path: path)
    }

    private static func domainIssues(for payload: SyncContinuousMedicationPayload, path: String) -> [String] {
        guard let medicationID = UUID(uuidString: payload.id) else {
            return []
        }

        let medication = ContinuousMedication(
            id: medicationID,
            name: payload.name,
            dosage: payload.dosage,
            frequency: payload.frequency,
            startDate: payload.startDate,
            endDate: payload.endDate,
            createdAt: payload.createdAt
        )

        return DomainValidator.continuousMedicationIssues(for: medication, path: path)
    }

    private static func validateUUID(_ value: String, field: String, into issues: inout [String]) {
        if UUID(uuidString: value) == nil {
            issues.append("\(field) ist keine gültige UUID")
        }
    }

    private static func validateDocumentID(
        _ documentID: String,
        expectedPrefix: String,
        payloadID: String,
        into issues: inout [String]
    ) {
        let expectedDocumentID = "\(expectedPrefix):\(payloadID)"
        if documentID != expectedDocumentID {
            issues.append("documentID passt nicht zu \(expectedPrefix).id")
        }
    }

    private static func validateKnownValue(
        _ value: String,
        field: String,
        allowedValues: Set<String>,
        into issues: inout [String]
    ) {
        if !allowedValues.contains(value) {
            issues.append("\(field) enthält einen unbekannten Wert")
        }
    }

    private static let episodeTypeValues: Set<String> = [
        EpisodeType.migraine.rawValue,
        EpisodeType.headache.rawValue,
        EpisodeType.unclear.rawValue,
        "Migräne",
        "Kopfschmerz",
        "Unklar"
    ]

    private static let menstruationStatusValues: Set<String> = [
        MenstruationStatus.unknown.rawValue,
        MenstruationStatus.none.rawValue,
        MenstruationStatus.active.rawValue,
        MenstruationStatus.expected.rawValue,
        "Nicht angegeben",
        "Nein",
        "Aktuell",
        "Erwartet"
    ]

    private static let medicationCategoryValues: Set<String> = [
        MedicationCategory.triptan.rawValue,
        MedicationCategory.nsar.rawValue,
        MedicationCategory.paracetamol.rawValue,
        MedicationCategory.antiemetic.rawValue,
        MedicationCategory.other.rawValue,
        "Triptan",
        "nsar",
        "NSAR",
        "Paracetamol",
        "Antiemetikum",
        "Sonstiges"
    ]

    private static let medicationEffectivenessValues: Set<String> = [
        MedicationEffectiveness.none.rawValue,
        MedicationEffectiveness.partial.rawValue,
        MedicationEffectiveness.good.rawValue,
        "Keine",
        "Teilweise",
        "Gut"
    ]
}

extension Episode {
    func syncEnvelope(deviceID: String, healthContextStore: HealthContextStore) -> SyncDocumentEnvelope {
        let healthContext = healthContextStore.load(for: id).map(HealthContextSnapshotData.init)

        return SyncDocumentEnvelope(
            documentID: "episode:\(id.uuidString)",
            entityType: .episode,
            modifiedAt: updatedAt,
            authorDeviceID: deviceID,
            deletedAt: deletedAt,
            payload: .episode(
                SyncEpisodePayload(
                    id: id.uuidString,
                    startedAt: startedAt,
                    endedAt: endedAt,
                    type: type.rawValue,
                    intensity: intensity,
                    painLocation: painLocation,
                    painCharacter: painCharacter,
                    notes: notes,
                    symptoms: symptoms,
                    triggers: triggers,
                    functionalImpact: functionalImpact,
                    menstruationStatus: menstruationStatus.rawValue,
                    medications: medications.map {
                        SyncMedicationEntryPayload(
                            id: $0.id.uuidString,
                            name: $0.name,
                            category: $0.category.rawValue,
                            dosage: $0.dosage,
                            quantity: $0.quantity,
                            takenAt: $0.takenAt,
                            effectiveness: $0.effectiveness.rawValue,
                            reliefStartedAt: $0.reliefStartedAt,
                            isRepeatDose: $0.isRepeatDose
                        )
                    },
                    continuousMedicationChecks: continuousMedicationChecks.map {
                        SyncContinuousMedicationCheckPayload(
                            id: $0.id.uuidString,
                            continuousMedicationID: $0.continuousMedicationID.uuidString,
                            name: $0.name,
                            dosage: $0.dosage,
                            frequency: $0.frequency,
                            wasTaken: $0.wasTaken
                        )
                    },
                    weatherSnapshot: weatherSnapshot.map {
                        SyncWeatherSnapshotPayload(
                            id: $0.id.uuidString,
                            recordedAt: $0.recordedAt,
                            temperature: $0.temperature,
                            condition: $0.condition,
                            humidity: $0.humidity,
                            pressure: $0.pressure,
                            precipitation: $0.precipitation,
                            weatherCode: $0.weatherCode,
                            source: $0.source,
                            dayRangeStart: $0.dayRangeStart,
                            dayRangeEnd: $0.dayRangeEnd,
                            contextRangeStart: $0.contextRangeStart,
                            contextRangeEnd: $0.contextRangeEnd,
                            contextPoints: $0.contextPoints
                        )
                    },
                    healthContext: healthContext
                )
            )
        )
    }
}

extension ContinuousMedication {
    func syncEnvelope(deviceID: String) -> SyncDocumentEnvelope {
        SyncDocumentEnvelope(
            documentID: "continuousMedication:\(id.uuidString)",
            entityType: .continuousMedication,
            modifiedAt: updatedAt,
            authorDeviceID: deviceID,
            payload: .continuousMedication(
                SyncContinuousMedicationPayload(
                    id: id.uuidString,
                    name: name,
                    dosage: dosage,
                    frequency: frequency,
                    startDate: startDate,
                    endDate: endDate,
                    createdAt: createdAt
                )
            )
        )
    }
}

extension MedicationDefinition {
    func syncEnvelope(deviceID: String) -> SyncDocumentEnvelope {
        SyncDocumentEnvelope(
            documentID: "medicationDefinition:\(catalogKey)",
            entityType: .medicationDefinition,
            modifiedAt: updatedAt,
            authorDeviceID: deviceID,
            deletedAt: deletedAt,
            payload: .medicationDefinition(
                SyncMedicationDefinitionPayload(
                    catalogKey: catalogKey,
                    groupID: groupID,
                    groupTitle: groupTitle,
                    groupFooter: groupFooter,
                    name: name,
                    category: category.rawValue,
                    suggestedDosage: suggestedDosage,
                    sortOrder: sortOrder,
                    isCustom: isCustom,
                    createdAt: createdAt
                )
            )
        )
    }
}
