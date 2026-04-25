import Foundation
import SwiftData

final class SwiftDataEpisodeRepository: EpisodeRepository, @unchecked Sendable {
    private let modelContainer: ModelContainer
    private let healthContextStore: HealthContextStore

    init(modelContainer: ModelContainer, healthContextStore: HealthContextStore) {
        self.modelContainer = modelContainer
        self.healthContextStore = healthContextStore
    }

    nonisolated func fetchRecent() throws -> [EpisodeRecord] {
        let descriptor = FetchDescriptor<Episode>(
            predicate: #Predicate<Episode> { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\Episode.startedAt, order: .reverse)]
        )
        return try readContext().fetch(descriptor)
            .map { EpisodeRecord(episode: $0, healthContextStore: healthContextStore) }
    }

    nonisolated func fetchByDay(_ day: Date) throws -> [EpisodeRecord] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let descriptor = FetchDescriptor<Episode>(
            predicate: #Predicate<Episode> { episode in
                episode.deletedAt == nil && episode.startedAt >= start && episode.startedAt < end
            },
            sortBy: [SortDescriptor(\Episode.startedAt, order: .reverse)]
        )
        return try readContext().fetch(descriptor)
            .map { EpisodeRecord(episode: $0, healthContextStore: healthContextStore) }
    }

    nonisolated func fetchByMonth(_ month: Date) throws -> [EpisodeRecord] {
        let calendar = Calendar.current
        let start = calendar.startOfMonth(for: month)
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        let descriptor = FetchDescriptor<Episode>(
            predicate: #Predicate<Episode> { episode in
                episode.deletedAt == nil && episode.startedAt >= start && episode.startedAt < end
            },
            sortBy: [SortDescriptor(\Episode.startedAt, order: .reverse)]
        )
        return try readContext().fetch(descriptor)
            .map { EpisodeRecord(episode: $0, healthContextStore: healthContextStore) }
    }

    nonisolated func load(id: UUID) throws -> EpisodeRecord? {
        let descriptor = FetchDescriptor<Episode>(
            predicate: #Predicate<Episode> { $0.id == id }
        )
        return try readContext().fetch(descriptor).first.map { EpisodeRecord(episode: $0, healthContextStore: healthContextStore) }
    }

    @discardableResult
    nonisolated func save(draft: EpisodeDraft, weatherSnapshot: WeatherSnapshotData?, healthContext: HealthContextSnapshotData?) throws -> UUID {
        let context = writeContext()
        let target: Episode

        if
            let id = draft.id,
            let existing = try fetchEpisode(id: id, in: context)
        {
            target = existing
        } else {
            target = Episode(startedAt: draft.startedAt, intensity: draft.intensity)
            context.insert(target)
        }

        target.markUpdated()
        target.type = draft.type
        target.startedAt = draft.startedAt
        target.endedAt = draft.endedAtEnabled ? draft.endedAt : nil
        target.intensity = draft.intensity
        target.painLocation = draft.painLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        target.painCharacter = draft.painCharacter.trimmingCharacters(in: .whitespacesAndNewlines)
        target.notes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        target.functionalImpact = draft.functionalImpact.trimmingCharacters(in: .whitespacesAndNewlines)
        target.menstruationStatus = draft.menstruationStatus
        target.symptoms = Array(draft.selectedSymptoms).sorted()
        target.triggers = Array(draft.selectedTriggers).sorted()

        for medication in target.medications {
            context.delete(medication)
        }

        if let existingWeatherSnapshot = target.weatherSnapshot {
            context.delete(existingWeatherSnapshot)
            target.weatherSnapshot = nil
        }

        target.medications = draft.medications
            .filter(\.isSelected)
            .map {
                MedicationEntry(
                    name: $0.name,
                    category: $0.category,
                    dosage: $0.dosage,
                    quantity: $0.quantity,
                    takenAt: draft.startedAt,
                    effectiveness: .partial,
                    episode: target
                )
            }

        if let weatherSnapshot {
            target.weatherSnapshot = WeatherSnapshot(snapshot: weatherSnapshot, episode: target)
        }

        try context.save()
        healthContextStore.save(healthContext, for: target.id)
        return target.id
    }

    nonisolated func softDelete(id: UUID) throws {
        let context = writeContext()
        guard let episode = try fetchEpisode(id: id, in: context) else {
            return
        }

        episode.markDeleted()
        try context.save()
    }

    nonisolated func restore(id: UUID) throws {
        let context = writeContext()
        guard let episode = try fetchEpisode(id: id, in: context) else {
            return
        }

        episode.restore()
        try context.save()
    }

    nonisolated func fetchDeleted() throws -> [EpisodeRecord] {
        let descriptor = FetchDescriptor<Episode>(
            predicate: #Predicate<Episode> { $0.deletedAt != nil },
            sortBy: [SortDescriptor(\Episode.startedAt, order: .reverse)]
        )
        return try readContext().fetch(descriptor)
            .map { EpisodeRecord(episode: $0, healthContextStore: healthContextStore) }
    }

    nonisolated private func readContext() -> ModelContext {
        ModelContext(modelContainer)
    }

    nonisolated private func writeContext() -> ModelContext {
        ModelContext(modelContainer)
    }

    nonisolated private func fetchEpisode(id: UUID, in context: ModelContext) throws -> Episode? {
        let descriptor = FetchDescriptor<Episode>(
            predicate: #Predicate<Episode> { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }
}

final class SwiftDataMedicationCatalogRepository: MedicationCatalogRepository, @unchecked Sendable {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    nonisolated func fetchDefinitions(searchText: String?) throws -> [MedicationDefinitionRecord] {
        let basePredicate: Predicate<MedicationDefinition>
        if let searchText, !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            basePredicate = #Predicate<MedicationDefinition> {
                $0.deletedAt == nil && $0.name.localizedStandardContains(searchText)
            }
        } else {
            basePredicate = #Predicate<MedicationDefinition> { $0.deletedAt == nil }
        }

        let descriptor = FetchDescriptor<MedicationDefinition>(
            predicate: basePredicate,
            sortBy: [SortDescriptor(\MedicationDefinition.sortOrder), SortDescriptor(\MedicationDefinition.name)]
        )

        return try readContext().fetch(descriptor).map(MedicationDefinitionRecord.init)
    }

    nonisolated func saveCustomDefinition(_ draft: CustomMedicationDefinitionDraft) throws -> MedicationDefinitionRecord {
        let context = writeContext()
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDosage = draft.dosage.trimmingCharacters(in: .whitespacesAndNewlines)

        let definition: MedicationDefinition
        if let existing = try fetchDefinition(catalogKey: draft.id, in: context) {
            definition = existing
            definition.markUpdated()
            definition.name = trimmedName
            definition.category = draft.category
            definition.suggestedDosage = trimmedDosage
        } else {
            var sortDescriptor = FetchDescriptor<MedicationDefinition>(
                sortBy: [SortDescriptor(\MedicationDefinition.sortOrder, order: .reverse)]
            )
            sortDescriptor.fetchLimit = 1
            let nextSortOrder = (try? context.fetch(sortDescriptor).first?.sortOrder) ?? 0
            definition = MedicationDefinition(
                catalogKey: draft.id.hasPrefix("custom:") ? draft.id : "custom:\(UUID().uuidString)",
                groupID: "custom-medications",
                groupTitle: "Eigene Medikamente",
                groupFooter: "Eigene Medikamente werden lokal in SwiftData gespeichert und bleiben in deiner persönlichen Auswahlliste verfügbar.",
                name: trimmedName,
                category: draft.category,
                suggestedDosage: trimmedDosage,
                sortOrder: nextSortOrder + 1,
                isCustom: true
            )
            context.insert(definition)
        }

        try context.save()
        return MedicationDefinitionRecord(definition: definition)
    }

    nonisolated func softDeleteCustomDefinition(catalogKey: String) throws {
        let context = writeContext()
        guard let definition = try fetchDefinition(catalogKey: catalogKey, in: context) else {
            return
        }

        definition.markDeleted()
        try context.save()
    }

    nonisolated func fetchDeletedDefinitions() throws -> [MedicationDefinitionRecord] {
        let descriptor = FetchDescriptor<MedicationDefinition>(
            predicate: #Predicate<MedicationDefinition> { $0.deletedAt != nil },
            sortBy: [SortDescriptor(\MedicationDefinition.updatedAt, order: .reverse)]
        )
        return try readContext().fetch(descriptor).map(MedicationDefinitionRecord.init)
    }

    nonisolated private func readContext() -> ModelContext {
        ModelContext(modelContainer)
    }

    nonisolated private func writeContext() -> ModelContext {
        ModelContext(modelContainer)
    }

    nonisolated private func fetchDefinition(catalogKey: String, in context: ModelContext) throws -> MedicationDefinition? {
        let descriptor = FetchDescriptor<MedicationDefinition>(
            predicate: #Predicate<MedicationDefinition> { $0.catalogKey == catalogKey }
        )
        return try context.fetch(descriptor).first
    }
}

final class SwiftDataExportRepository: ExportRepository, @unchecked Sendable {
    private let modelContainer: ModelContainer
    private let healthContextStore: HealthContextStore

    init(modelContainer: ModelContainer, healthContextStore: HealthContextStore) {
        self.modelContainer = modelContainer
        self.healthContextStore = healthContextStore
    }

    nonisolated func buildSummary(startDate: Date, endDate: Date) throws -> ExportPeriodSummary {
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
        let descriptor = FetchDescriptor<Episode>(
            predicate: #Predicate<Episode> { episode in
                episode.deletedAt == nil && episode.startedAt >= startDate && episode.startedAt <= endOfDay
            },
            sortBy: [SortDescriptor(\Episode.startedAt, order: .reverse)]
        )
        let filtered = try readContext().fetch(descriptor)
            .map { EpisodeExportRecord(episode: $0, healthContext: healthContextStore.load(for: $0.id)) }

        return ExportPeriodSummary(startDate: startDate, endDate: endDate, records: filtered)
    }

    nonisolated func createPDF(summary: ExportPeriodSummary, mode: PDFReportMode) throws -> URL {
        try PDFExportWriter.write(summary: summary, mode: mode)
    }

    nonisolated func createBackup() throws -> URL {
        let readContext = readContext()
        let episodes = try readContext.fetch(FetchDescriptor<Episode>(sortBy: [SortDescriptor(\Episode.startedAt, order: .reverse)]))
        let definitions = try readContext.fetch(
            FetchDescriptor<MedicationDefinition>(
                predicate: #Predicate<MedicationDefinition> { $0.isCustom },
                sortBy: [SortDescriptor(\MedicationDefinition.sortOrder)]
            )
        )
        let snapshot = DataTransferSnapshot(
            episodes: episodes,
            customMedicationDefinitions: definitions,
            healthContextStore: healthContextStore
        )
        return try snapshot.writeToTemporaryFile()
    }

    nonisolated func importBackup(from url: URL) throws {
        let snapshot = try DataTransferSnapshot.load(from: url)
        let context = writeContext()
        try snapshot.merge(into: context)
    }

    nonisolated private func readContext() -> ModelContext {
        ModelContext(modelContainer)
    }

    nonisolated private func writeContext() -> ModelContext {
        ModelContext(modelContainer)
    }
}

private extension EpisodeRecord {
    nonisolated init(episode: Episode, healthContextStore: HealthContextStore) {
        self.init(
            id: episode.id,
            startedAt: episode.startedAt,
            endedAt: episode.endedAt,
            updatedAt: episode.updatedAt,
            deletedAt: episode.deletedAt,
            type: episode.type,
            intensity: episode.intensity,
            painLocation: episode.painLocation,
            painCharacter: episode.painCharacter,
            notes: episode.notes,
            symptoms: episode.symptoms,
            triggers: episode.triggers,
            functionalImpact: episode.functionalImpact,
            menstruationStatus: episode.menstruationStatus,
            medications: episode.medications.map(MedicationRecord.init),
            weather: episode.weatherSnapshot.map(WeatherRecord.init),
            healthContext: healthContextStore.load(for: episode.id)
        )
    }
}

private extension MedicationRecord {
    nonisolated init(entry: MedicationEntry) {
        self.init(
            id: entry.id,
            name: entry.name,
            category: entry.category,
            dosage: entry.dosage,
            quantity: entry.quantity,
            takenAt: entry.takenAt,
            effectiveness: entry.effectiveness,
            reliefStartedAt: entry.reliefStartedAt,
            isRepeatDose: entry.isRepeatDose
        )
    }
}

private extension WeatherRecord {
    nonisolated init(snapshot: WeatherSnapshot) {
        self.init(
            recordedAt: snapshot.recordedAt,
            condition: snapshot.condition,
            temperature: snapshot.temperature,
            humidity: snapshot.humidity,
            pressure: snapshot.pressure,
            precipitation: snapshot.precipitation,
            weatherCode: snapshot.weatherCode,
            source: snapshot.source
        )
    }
}

private extension MedicationDefinitionRecord {
    nonisolated init(definition: MedicationDefinition) {
        self.init(
            catalogKey: definition.catalogKey,
            groupID: definition.groupID,
            groupTitle: definition.groupTitle,
            groupFooter: definition.groupFooter,
            name: definition.name,
            category: definition.category,
            suggestedDosage: definition.suggestedDosage,
            sortOrder: definition.sortOrder,
            isCustom: definition.isCustom,
            isDeleted: definition.isDeleted
        )
    }
}
