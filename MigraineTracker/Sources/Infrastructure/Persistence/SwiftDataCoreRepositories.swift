import Foundation
import SwiftData

@MainActor
final class SwiftDataEpisodeRepository: EpisodeRepository {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func fetchRecent() throws -> [EpisodeRecord] {
        let descriptor = FetchDescriptor<Episode>(sortBy: [SortDescriptor(\Episode.startedAt, order: .reverse)])
        return try context.fetch(descriptor)
            .filter { !$0.isDeleted }
            .map(EpisodeRecord.init)
    }

    func fetchByDay(_ day: Date) throws -> [EpisodeRecord] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let descriptor = FetchDescriptor<Episode>(
            predicate: #Predicate<Episode> { episode in
                episode.startedAt >= start && episode.startedAt < end
            },
            sortBy: [SortDescriptor(\Episode.startedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
            .filter { !$0.isDeleted }
            .map(EpisodeRecord.init)
    }

    func fetchByMonth(_ month: Date) throws -> [EpisodeRecord] {
        let calendar = Calendar.current
        let start = calendar.startOfMonth(for: month)
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        let descriptor = FetchDescriptor<Episode>(
            predicate: #Predicate<Episode> { episode in
                episode.startedAt >= start && episode.startedAt < end
            },
            sortBy: [SortDescriptor(\Episode.startedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
            .filter { !$0.isDeleted }
            .map(EpisodeRecord.init)
    }

    func load(id: UUID) throws -> EpisodeRecord? {
        let descriptor = FetchDescriptor<Episode>(
            predicate: #Predicate<Episode> { $0.id == id }
        )
        return try context.fetch(descriptor).first.map(EpisodeRecord.init)
    }

    @discardableResult
    func save(draft: EpisodeDraft, weatherSnapshot: WeatherSnapshotData?) throws -> UUID {
        let target: Episode

        if
            let id = draft.id,
            let existing = try fetchEpisode(id: id)
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
        return target.id
    }

    func softDelete(id: UUID) throws {
        guard let episode = try fetchEpisode(id: id) else {
            return
        }

        episode.markDeleted()
        try context.save()
    }

    func restore(id: UUID) throws {
        guard let episode = try fetchEpisode(id: id) else {
            return
        }

        episode.restore()
        try context.save()
    }

    func fetchDeleted() throws -> [EpisodeRecord] {
        let descriptor = FetchDescriptor<Episode>(sortBy: [SortDescriptor(\Episode.startedAt, order: .reverse)])
        return try context.fetch(descriptor)
            .filter(\.isDeleted)
            .map(EpisodeRecord.init)
    }

    private var context: ModelContext {
        modelContainer.mainContext
    }

    private func fetchEpisode(id: UUID) throws -> Episode? {
        let descriptor = FetchDescriptor<Episode>(
            predicate: #Predicate<Episode> { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }
}

@MainActor
final class SwiftDataMedicationCatalogRepository: MedicationCatalogRepository {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func fetchDefinitions(searchText: String?) throws -> [MedicationDefinitionRecord] {
        let descriptor = FetchDescriptor<MedicationDefinition>(
            sortBy: [SortDescriptor(\MedicationDefinition.sortOrder), SortDescriptor(\MedicationDefinition.name)]
        )

        let definitions = try context.fetch(descriptor)
            .filter { !$0.isDeleted }

        guard let searchText, !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return definitions.map(MedicationDefinitionRecord.init)
        }

        return definitions
            .filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            .map(MedicationDefinitionRecord.init)
    }

    func saveCustomDefinition(_ draft: CustomMedicationDefinitionDraft) throws -> MedicationDefinitionRecord {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDosage = draft.dosage.trimmingCharacters(in: .whitespacesAndNewlines)

        let definition: MedicationDefinition
        if let existing = try fetchDefinition(catalogKey: draft.id) {
            definition = existing
            definition.markUpdated()
            definition.name = trimmedName
            definition.category = draft.category
            definition.suggestedDosage = trimmedDosage
        } else {
            let nextSortOrder = ((try? context.fetch(FetchDescriptor<MedicationDefinition>())) ?? []).map(\.sortOrder).max() ?? 0
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

    func softDeleteCustomDefinition(catalogKey: String) throws {
        guard let definition = try fetchDefinition(catalogKey: catalogKey) else {
            return
        }

        definition.markDeleted()
        try context.save()
    }

    func fetchDeletedDefinitions() throws -> [MedicationDefinitionRecord] {
        let descriptor = FetchDescriptor<MedicationDefinition>(
            sortBy: [SortDescriptor(\MedicationDefinition.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
            .filter(\.isDeleted)
            .map(MedicationDefinitionRecord.init)
    }

    private var context: ModelContext {
        modelContainer.mainContext
    }

    private func fetchDefinition(catalogKey: String) throws -> MedicationDefinition? {
        let descriptor = FetchDescriptor<MedicationDefinition>(
            predicate: #Predicate<MedicationDefinition> { $0.catalogKey == catalogKey }
        )
        return try context.fetch(descriptor).first
    }
}

@MainActor
final class SwiftDataExportRepository: ExportRepository {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func buildSummary(startDate: Date, endDate: Date) throws -> ExportPeriodSummary {
        let episodes = try context.fetch(FetchDescriptor<Episode>(sortBy: [SortDescriptor(\Episode.startedAt, order: .reverse)]))
            .filter { !$0.isDeleted }

        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
        let filtered = episodes
            .filter { $0.startedAt >= startDate && $0.startedAt <= endOfDay }
            .map(EpisodeExportRecord.init)

        return ExportPeriodSummary(startDate: startDate, endDate: endDate, records: filtered)
    }

    func createPDF(summary: ExportPeriodSummary) throws -> URL {
        try PDFExportWriter.write(summary: summary)
    }

    func createBackup() throws -> URL {
        let episodes = try context.fetch(FetchDescriptor<Episode>(sortBy: [SortDescriptor(\Episode.startedAt, order: .reverse)]))
        let definitions = try context.fetch(FetchDescriptor<MedicationDefinition>(sortBy: [SortDescriptor(\MedicationDefinition.sortOrder)]))
            .filter(\.isCustom)
        let snapshot = DataTransferSnapshot(episodes: episodes, customMedicationDefinitions: definitions)
        return try snapshot.writeToTemporaryFile()
    }

    func importBackup(from url: URL) throws {
        let snapshot = try DataTransferSnapshot.load(from: url)
        try snapshot.merge(into: context)
    }

    private var context: ModelContext {
        modelContainer.mainContext
    }
}

private extension EpisodeRecord {
    init(episode: Episode) {
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
            weather: episode.weatherSnapshot.map(WeatherRecord.init)
        )
    }
}

private extension MedicationRecord {
    init(entry: MedicationEntry) {
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
    init(snapshot: WeatherSnapshot) {
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
    init(definition: MedicationDefinition) {
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
