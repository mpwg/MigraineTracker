import Foundation
import SwiftData

@MainActor
struct LocalSyncRepository {
    let modelContainer: ModelContainer

    func allEnvelopes(deviceID: String) throws -> [SyncDocumentEnvelope] {
        let context = ModelContext(modelContainer)
        let episodes = try context.fetch(FetchDescriptor<Episode>())
        let customDefinitions = try context.fetch(FetchDescriptor<MedicationDefinition>())
            .filter(\.isCustom)

        return episodes.map { $0.syncEnvelope(deviceID: deviceID) } +
            customDefinitions.map { $0.syncEnvelope(deviceID: deviceID) }
    }

    func envelope(documentID: String, deviceID: String) throws -> SyncDocumentEnvelope? {
        let envelopes = try allEnvelopes(deviceID: deviceID)
        return envelopes.first { $0.documentID == documentID }
    }

    func apply(remote envelope: SyncDocumentEnvelope) throws {
        let context = ModelContext(modelContainer)

        switch envelope.payload {
        case .episode(let payload):
            try applyEpisodePayload(payload, from: envelope, in: context)
        case .medicationDefinition(let payload):
            try applyMedicationDefinitionPayload(payload, from: envelope, in: context)
        }

        try context.save()
    }

    private func applyEpisodePayload(
        _ payload: SyncEpisodePayload,
        from envelope: SyncDocumentEnvelope,
        in context: ModelContext
    ) throws {
        let episodeID = UUID(uuidString: payload.id) ?? UUID()
        let existing = try context.fetch(FetchDescriptor<Episode>()).first { $0.id == episodeID }
        let target = existing ?? Episode(
            id: episodeID,
            startedAt: payload.startedAt,
            endedAt: payload.endedAt,
            updatedAt: envelope.modifiedAt,
            deletedAt: envelope.deletedAt,
            type: EpisodeType(rawValue: payload.type) ?? .unclear,
            intensity: payload.intensity
        )

        target.startedAt = payload.startedAt
        target.endedAt = payload.endedAt
        target.updatedAt = envelope.modifiedAt
        target.deletedAt = envelope.deletedAt
        target.type = EpisodeType(rawValue: payload.type) ?? .unclear
        target.intensity = payload.intensity
        target.painLocation = payload.painLocation
        target.painCharacter = payload.painCharacter
        target.notes = payload.notes
        target.symptoms = payload.symptoms
        target.triggers = payload.triggers
        target.functionalImpact = payload.functionalImpact
        target.menstruationStatus = MenstruationStatus(rawValue: payload.menstruationStatus) ?? .unknown

        for medication in target.medications {
            context.delete(medication)
        }

        if let weatherSnapshot = target.weatherSnapshot {
            context.delete(weatherSnapshot)
            target.weatherSnapshot = nil
        }

        target.medications = payload.medications.map { medication in
            MedicationEntry(
                id: UUID(uuidString: medication.id) ?? UUID(),
                name: medication.name,
                category: MedicationCategory(rawValue: medication.category) ?? .other,
                dosage: medication.dosage,
                quantity: medication.quantity,
                takenAt: medication.takenAt,
                effectiveness: MedicationEffectiveness(rawValue: medication.effectiveness) ?? .partial,
                reliefStartedAt: medication.reliefStartedAt,
                isRepeatDose: medication.isRepeatDose,
                episode: target
            )
        }
        target.weatherSnapshot = payload.weatherSnapshot.map { weather in
            WeatherSnapshot(
                id: UUID(uuidString: weather.id) ?? UUID(),
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
        }

        if existing == nil {
            context.insert(target)
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
            category: MedicationCategory(rawValue: payload.category) ?? .other,
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
        target.category = MedicationCategory(rawValue: payload.category) ?? .other
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
}

extension Episode {
    func syncEnvelope(deviceID: String) -> SyncDocumentEnvelope {
        SyncDocumentEnvelope(
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
                    }
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
