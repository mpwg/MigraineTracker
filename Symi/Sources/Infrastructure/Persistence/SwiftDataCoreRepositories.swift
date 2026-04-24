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

    func createBackup() throws -> URL {
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

    func importBackup(from url: URL) throws {
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

final class SwiftDataDoctorRepository: DoctorRepository, @unchecked Sendable {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    nonisolated func fetchAll() throws -> [DoctorRecord] {
        let descriptor = FetchDescriptor<Doctor>(
            predicate: #Predicate<Doctor> { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\Doctor.name), SortDescriptor(\Doctor.specialty)]
        )
        return try readContext().fetch(descriptor).map(DoctorRecord.init)
    }

    nonisolated func load(id: UUID) throws -> DoctorRecord? {
        let descriptor = FetchDescriptor<Doctor>(
            predicate: #Predicate<Doctor> { $0.id == id }
        )
        return try readContext().fetch(descriptor).first.map(DoctorRecord.init)
    }

    @discardableResult
    nonisolated func save(draft: DoctorDraft) throws -> UUID {
        let context = writeContext()
        let doctor: Doctor

        if let id = draft.id, let existing = try fetchDoctor(id: id, in: context) {
            doctor = existing
        } else {
            doctor = Doctor(name: draft.name)
            context.insert(doctor)
        }

        doctor.markUpdated()
        doctor.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        doctor.specialty = draft.specialty.trimmingCharacters(in: .whitespacesAndNewlines)
        doctor.street = draft.street.trimmingCharacters(in: .whitespacesAndNewlines)
        doctor.city = draft.city.trimmingCharacters(in: .whitespacesAndNewlines)
        doctor.state = draft.state.trimmingCharacters(in: .whitespacesAndNewlines)
        let postalCode = draft.postalCode.trimmingCharacters(in: .whitespacesAndNewlines)
        doctor.postalCode = postalCode.isEmpty ? nil : postalCode
        doctor.phone = draft.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        doctor.email = draft.email.trimmingCharacters(in: .whitespacesAndNewlines)
        doctor.notes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        doctor.source = draft.source

        try context.save()
        return doctor.id
    }

    nonisolated func softDelete(id: UUID) throws {
        let context = writeContext()
        guard let doctor = try fetchDoctor(id: id, in: context) else {
            return
        }

        doctor.markDeleted()
        for appointment in doctor.appointments {
            appointment.markDeleted()
        }
        try context.save()
    }

    nonisolated private func readContext() -> ModelContext {
        ModelContext(modelContainer)
    }

    nonisolated private func writeContext() -> ModelContext {
        ModelContext(modelContainer)
    }

    nonisolated private func fetchDoctor(id: UUID, in context: ModelContext) throws -> Doctor? {
        let descriptor = FetchDescriptor<Doctor>(
            predicate: #Predicate<Doctor> { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }
}

final class SwiftDataDoctorDirectoryRepository: DoctorDirectoryRepository, @unchecked Sendable {
    nonisolated private static let searchResultLimit = 120

    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    nonisolated func fetchEntries(searchText: String?) throws -> [DoctorDirectoryRecord] {
        var descriptor: FetchDescriptor<DoctorDirectoryEntry>
        let trimmedSearchText = searchText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedSearchText.isEmpty {
            descriptor = FetchDescriptor<DoctorDirectoryEntry>(
                predicate: #Predicate<DoctorDirectoryEntry> {
                    $0.name.localizedStandardContains(trimmedSearchText)
                        || $0.specialty.localizedStandardContains(trimmedSearchText)
                        || $0.city.localizedStandardContains(trimmedSearchText)
                        || $0.street.localizedStandardContains(trimmedSearchText)
                },
                sortBy: [SortDescriptor(\DoctorDirectoryEntry.name), SortDescriptor(\DoctorDirectoryEntry.city)]
            )
        } else {
            return []
        }
        descriptor.fetchLimit = Self.searchResultLimit

        return try readContext().fetch(descriptor).map(DoctorDirectoryRecord.init)
    }

    nonisolated func sourceAttribution() -> (label: String, url: String) {
        var descriptor = FetchDescriptor<DoctorDirectoryEntry>()
        descriptor.fetchLimit = 1
        let firstEntry = try? readContext().fetch(descriptor).first
        return (
            firstEntry?.sourceLabel ?? "ÖGK Vertragspartner Fachärztinnen und Fachärzte",
            firstEntry?.sourceURL ?? "https://www.gesundheitskasse.at/cdscontent/?contentid=10007.884365"
        )
    }

    nonisolated private func readContext() -> ModelContext {
        ModelContext(modelContainer)
    }
}

final class SwiftDataAppointmentRepository: AppointmentRepository, @unchecked Sendable {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    nonisolated func fetchUpcoming(limit: Int?) throws -> [AppointmentRecord] {
        let now = Date.now
        var descriptor = FetchDescriptor<DoctorAppointment>(
            predicate: #Predicate<DoctorAppointment> { $0.deletedAt == nil && $0.scheduledAt >= now },
            sortBy: [SortDescriptor(\DoctorAppointment.scheduledAt)]
        )
        if let limit {
            descriptor.fetchLimit = limit
        }

        return try readContext().fetch(descriptor).map(AppointmentRecord.init)
    }

    nonisolated func fetchUpcoming(for doctorID: UUID) throws -> [AppointmentRecord] {
        let now = Date.now
        let descriptor = FetchDescriptor<DoctorAppointment>(
            predicate: #Predicate<DoctorAppointment> { appointment in
                appointment.deletedAt == nil && appointment.scheduledAt >= now && appointment.doctor?.id == doctorID
            },
            sortBy: [SortDescriptor(\DoctorAppointment.scheduledAt)]
        )
        return try readContext().fetch(descriptor).map(AppointmentRecord.init)
    }

    nonisolated func load(id: UUID) throws -> AppointmentRecord? {
        let descriptor = FetchDescriptor<DoctorAppointment>(
            predicate: #Predicate<DoctorAppointment> { $0.id == id }
        )
        return try readContext().fetch(descriptor).first.map(AppointmentRecord.init)
    }

    @discardableResult
    nonisolated func save(draft: AppointmentDraft) throws -> UUID {
        let context = writeContext()
        guard let doctor = try fetchDoctor(id: draft.doctorID, in: context) else {
            throw AppointmentSaveError.missingDoctor
        }

        let appointment: DoctorAppointment
        if let id = draft.id, let existing = try fetchAppointment(id: id, in: context) {
            appointment = existing
        } else {
            appointment = DoctorAppointment(scheduledAt: draft.scheduledAt, doctor: doctor)
            context.insert(appointment)
        }

        appointment.markUpdated()
        appointment.doctor = doctor
        appointment.scheduledAt = draft.scheduledAt
        appointment.endsAt = draft.endsAtEnabled ? draft.endsAt : nil
        appointment.practiceName = draft.practiceName.trimmingCharacters(in: .whitespacesAndNewlines)
        appointment.addressText = draft.addressText.trimmingCharacters(in: .whitespacesAndNewlines)
        appointment.note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        appointment.reminderEnabled = draft.reminderEnabled
        appointment.reminderLeadTimeMinutes = draft.reminderLeadTimeMinutes
        if !draft.reminderEnabled {
            appointment.reminderStatus = .notRequested
            appointment.notificationRequestID = nil
        }

        try context.save()
        return appointment.id
    }

    nonisolated func updateReminder(id: UUID, status: AppointmentReminderStatus, requestID: String?) throws {
        let context = writeContext()
        guard let appointment = try fetchAppointment(id: id, in: context) else {
            return
        }

        appointment.markUpdated()
        appointment.reminderStatus = status
        appointment.notificationRequestID = requestID
        try context.save()
    }

    nonisolated func softDelete(id: UUID) throws {
        let context = writeContext()
        guard let appointment = try fetchAppointment(id: id, in: context) else {
            return
        }

        appointment.markDeleted()
        appointment.notificationRequestID = nil
        try context.save()
    }

    nonisolated private func readContext() -> ModelContext {
        ModelContext(modelContainer)
    }

    nonisolated private func writeContext() -> ModelContext {
        ModelContext(modelContainer)
    }

    nonisolated private func fetchDoctor(id: UUID, in context: ModelContext) throws -> Doctor? {
        let descriptor = FetchDescriptor<Doctor>(
            predicate: #Predicate<Doctor> { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    nonisolated private func fetchAppointment(id: UUID, in context: ModelContext) throws -> DoctorAppointment? {
        let descriptor = FetchDescriptor<DoctorAppointment>(
            predicate: #Predicate<DoctorAppointment> { $0.id == id }
        )
        return try context.fetch(descriptor).first
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

private extension DoctorRecord {
    nonisolated init(doctor: Doctor) {
        self.init(
            id: doctor.id,
            createdAt: doctor.createdAt,
            updatedAt: doctor.updatedAt,
            deletedAt: doctor.deletedAt,
            name: doctor.name,
            specialty: doctor.specialty,
            street: doctor.street,
            city: doctor.city,
            state: doctor.state,
            postalCode: doctor.postalCode,
            phone: doctor.phone,
            email: doctor.email,
            notes: doctor.notes,
            source: doctor.source,
            appointments: doctor.appointments
                .filter { !$0.isDeleted }
                .sorted(by: { $0.scheduledAt < $1.scheduledAt })
                .map(AppointmentRecord.init)
        )
    }
}

private extension AppointmentRecord {
    nonisolated init(appointment: DoctorAppointment) {
        self.init(
            id: appointment.id,
            doctorID: appointment.doctor?.id,
            createdAt: appointment.createdAt,
            updatedAt: appointment.updatedAt,
            deletedAt: appointment.deletedAt,
            scheduledAt: appointment.scheduledAt,
            endsAt: appointment.endsAt,
            practiceName: appointment.practiceName,
            addressText: appointment.addressText,
            note: appointment.note,
            reminderEnabled: appointment.reminderEnabled,
            reminderLeadTimeMinutes: appointment.reminderLeadTimeMinutes,
            reminderStatus: appointment.reminderStatus,
            notificationRequestID: appointment.notificationRequestID
        )
    }
}

private extension DoctorDirectoryRecord {
    nonisolated init(entry: DoctorDirectoryEntry) {
        self.init(
            id: entry.id,
            name: entry.name,
            specialty: entry.specialty,
            street: entry.street,
            city: entry.city,
            state: entry.state,
            postalCode: entry.postalCode,
            sourceLabel: entry.sourceLabel,
            sourceURL: entry.sourceURL
        )
    }
}
