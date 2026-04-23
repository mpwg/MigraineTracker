import Foundation
import SwiftData

@MainActor
final class SwiftDataEpisodeRepository: EpisodeRepository {
    private let modelContainer: ModelContainer
    private let healthContextStore: HealthContextStore

    init(modelContainer: ModelContainer, healthContextStore: HealthContextStore) {
        self.modelContainer = modelContainer
        self.healthContextStore = healthContextStore
    }

    func fetchRecent() throws -> [EpisodeRecord] {
        let descriptor = FetchDescriptor<Episode>(
            predicate: #Predicate<Episode> { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\Episode.startedAt, order: .reverse)]
        )
        return try readContext().fetch(descriptor)
            .map { EpisodeRecord(episode: $0, healthContextStore: healthContextStore) }
    }

    func fetchByDay(_ day: Date) throws -> [EpisodeRecord] {
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

    func fetchByMonth(_ month: Date) throws -> [EpisodeRecord] {
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

    func load(id: UUID) throws -> EpisodeRecord? {
        let descriptor = FetchDescriptor<Episode>(
            predicate: #Predicate<Episode> { $0.id == id }
        )
        return try readContext().fetch(descriptor).first.map { EpisodeRecord(episode: $0, healthContextStore: healthContextStore) }
    }

    @discardableResult
    func save(draft: EpisodeDraft, weatherSnapshot: WeatherSnapshotData?, healthContext: HealthContextSnapshotData?) throws -> UUID {
        let target: Episode

        if
            let id = draft.id,
            let existing = try fetchEpisode(id: id)
        {
            target = existing
        } else {
            target = Episode(startedAt: draft.startedAt, intensity: draft.intensity)
            mainContext.insert(target)
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
            mainContext.delete(medication)
        }

        if let existingWeatherSnapshot = target.weatherSnapshot {
            mainContext.delete(existingWeatherSnapshot)
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

        try mainContext.save()
        healthContextStore.save(healthContext, for: target.id)
        return target.id
    }

    func softDelete(id: UUID) throws {
        guard let episode = try fetchEpisode(id: id) else {
            return
        }

        episode.markDeleted()
        try mainContext.save()
    }

    func restore(id: UUID) throws {
        guard let episode = try fetchEpisode(id: id) else {
            return
        }

        episode.restore()
        try mainContext.save()
    }

    func fetchDeleted() throws -> [EpisodeRecord] {
        let descriptor = FetchDescriptor<Episode>(
            predicate: #Predicate<Episode> { $0.deletedAt != nil },
            sortBy: [SortDescriptor(\Episode.startedAt, order: .reverse)]
        )
        return try readContext().fetch(descriptor)
            .map { EpisodeRecord(episode: $0, healthContextStore: healthContextStore) }
    }

    private var mainContext: ModelContext {
        modelContainer.mainContext
    }

    private func readContext() -> ModelContext {
        ModelContext(modelContainer)
    }

    private func fetchEpisode(id: UUID) throws -> Episode? {
        let descriptor = FetchDescriptor<Episode>(
            predicate: #Predicate<Episode> { $0.id == id }
        )
        return try mainContext.fetch(descriptor).first
    }
}

@MainActor
final class SwiftDataMedicationCatalogRepository: MedicationCatalogRepository {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func fetchDefinitions(searchText: String?) throws -> [MedicationDefinitionRecord] {
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
            let nextSortOrder = ((try? mainContext.fetch(FetchDescriptor<MedicationDefinition>())) ?? []).map(\.sortOrder).max() ?? 0
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
            mainContext.insert(definition)
        }

        try mainContext.save()
        return MedicationDefinitionRecord(definition: definition)
    }

    func softDeleteCustomDefinition(catalogKey: String) throws {
        guard let definition = try fetchDefinition(catalogKey: catalogKey) else {
            return
        }

        definition.markDeleted()
        try mainContext.save()
    }

    func fetchDeletedDefinitions() throws -> [MedicationDefinitionRecord] {
        let descriptor = FetchDescriptor<MedicationDefinition>(
            predicate: #Predicate<MedicationDefinition> { $0.deletedAt != nil },
            sortBy: [SortDescriptor(\MedicationDefinition.updatedAt, order: .reverse)]
        )
        return try readContext().fetch(descriptor).map(MedicationDefinitionRecord.init)
    }

    private var mainContext: ModelContext {
        modelContainer.mainContext
    }

    private func readContext() -> ModelContext {
        ModelContext(modelContainer)
    }

    private func fetchDefinition(catalogKey: String) throws -> MedicationDefinition? {
        let descriptor = FetchDescriptor<MedicationDefinition>(
            predicate: #Predicate<MedicationDefinition> { $0.catalogKey == catalogKey }
        )
        return try mainContext.fetch(descriptor).first
    }
}

@MainActor
final class SwiftDataExportRepository: ExportRepository {
    private let modelContainer: ModelContainer
    private let healthContextStore: HealthContextStore

    init(modelContainer: ModelContainer, healthContextStore: HealthContextStore) {
        self.modelContainer = modelContainer
        self.healthContextStore = healthContextStore
    }

    func buildSummary(startDate: Date, endDate: Date) throws -> ExportPeriodSummary {
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

    func createPDF(summary: ExportPeriodSummary, mode: PDFReportMode) throws -> URL {
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
        try snapshot.merge(into: mainContext)
    }

    private var mainContext: ModelContext {
        modelContainer.mainContext
    }

    private func readContext() -> ModelContext {
        ModelContext(modelContainer)
    }
}

@MainActor
final class SwiftDataDoctorRepository: DoctorRepository {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func fetchAll() throws -> [DoctorRecord] {
        let descriptor = FetchDescriptor<Doctor>(
            predicate: #Predicate<Doctor> { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\Doctor.name), SortDescriptor(\Doctor.specialty)]
        )
        return try readContext().fetch(descriptor).map(DoctorRecord.init)
    }

    func load(id: UUID) throws -> DoctorRecord? {
        let descriptor = FetchDescriptor<Doctor>(
            predicate: #Predicate<Doctor> { $0.id == id }
        )
        return try readContext().fetch(descriptor).first.map(DoctorRecord.init)
    }

    @discardableResult
    func save(draft: DoctorDraft) throws -> UUID {
        let doctor: Doctor

        if let id = draft.id, let existing = try fetchDoctor(id: id) {
            doctor = existing
        } else {
            doctor = Doctor(name: draft.name)
            mainContext.insert(doctor)
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

        try mainContext.save()
        return doctor.id
    }

    func softDelete(id: UUID) throws {
        guard let doctor = try fetchDoctor(id: id) else {
            return
        }

        doctor.markDeleted()
        for appointment in doctor.appointments {
            appointment.markDeleted()
        }
        try mainContext.save()
    }

    private var mainContext: ModelContext {
        modelContainer.mainContext
    }

    private func readContext() -> ModelContext {
        ModelContext(modelContainer)
    }

    private func fetchDoctor(id: UUID) throws -> Doctor? {
        let descriptor = FetchDescriptor<Doctor>(
            predicate: #Predicate<Doctor> { $0.id == id }
        )
        return try mainContext.fetch(descriptor).first
    }
}

@MainActor
final class SwiftDataDoctorDirectoryRepository: DoctorDirectoryRepository {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func fetchEntries(searchText: String?) throws -> [DoctorDirectoryRecord] {
        let descriptor: FetchDescriptor<DoctorDirectoryEntry>
        if let searchText, !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            descriptor = FetchDescriptor<DoctorDirectoryEntry>(
                predicate: #Predicate<DoctorDirectoryEntry> {
                    $0.name.localizedStandardContains(searchText)
                        || $0.specialty.localizedStandardContains(searchText)
                        || $0.city.localizedStandardContains(searchText)
                        || $0.street.localizedStandardContains(searchText)
                },
                sortBy: [SortDescriptor(\DoctorDirectoryEntry.name), SortDescriptor(\DoctorDirectoryEntry.city)]
            )
        } else {
            descriptor = FetchDescriptor<DoctorDirectoryEntry>(
                sortBy: [SortDescriptor(\DoctorDirectoryEntry.name), SortDescriptor(\DoctorDirectoryEntry.city)]
            )
        }

        return try readContext().fetch(descriptor).map(DoctorDirectoryRecord.init)
    }

    func sourceAttribution() -> (label: String, url: String) {
        let firstEntry = try? readContext().fetch(FetchDescriptor<DoctorDirectoryEntry>()).first
        return (
            firstEntry?.sourceLabel ?? "ÖGK Vertragspartner Fachärztinnen und Fachärzte",
            firstEntry?.sourceURL ?? "https://www.gesundheitskasse.at/cdscontent/?contentid=10007.884365"
        )
    }

    private func readContext() -> ModelContext {
        ModelContext(modelContainer)
    }
}

@MainActor
final class SwiftDataAppointmentRepository: AppointmentRepository {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func fetchUpcoming(limit: Int?) throws -> [AppointmentRecord] {
        let now = Date.now
        let descriptor = FetchDescriptor<DoctorAppointment>(
            predicate: #Predicate<DoctorAppointment> { $0.deletedAt == nil && $0.scheduledAt >= now },
            sortBy: [SortDescriptor(\DoctorAppointment.scheduledAt)]
        )
        let records = try readContext().fetch(descriptor).map(AppointmentRecord.init)

        if let limit {
            return Array(records.prefix(limit))
        }

        return records
    }

    func fetchUpcoming(for doctorID: UUID) throws -> [AppointmentRecord] {
        let now = Date.now
        let descriptor = FetchDescriptor<DoctorAppointment>(
            predicate: #Predicate<DoctorAppointment> { $0.deletedAt == nil && $0.scheduledAt >= now },
            sortBy: [SortDescriptor(\DoctorAppointment.scheduledAt)]
        )
        return try readContext().fetch(descriptor)
            .filter { $0.doctor?.id == doctorID }
            .map(AppointmentRecord.init)
    }

    func load(id: UUID) throws -> AppointmentRecord? {
        let descriptor = FetchDescriptor<DoctorAppointment>(
            predicate: #Predicate<DoctorAppointment> { $0.id == id }
        )
        return try readContext().fetch(descriptor).first.map(AppointmentRecord.init)
    }

    @discardableResult
    func save(draft: AppointmentDraft) throws -> UUID {
        guard let doctor = try fetchDoctor(id: draft.doctorID) else {
            throw AppointmentSaveError.missingDoctor
        }

        let appointment: DoctorAppointment
        if let id = draft.id, let existing = try fetchAppointment(id: id) {
            appointment = existing
        } else {
            appointment = DoctorAppointment(scheduledAt: draft.scheduledAt, doctor: doctor)
            mainContext.insert(appointment)
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

        try mainContext.save()
        return appointment.id
    }

    func updateReminder(id: UUID, status: AppointmentReminderStatus, requestID: String?) throws {
        guard let appointment = try fetchAppointment(id: id) else {
            return
        }

        appointment.markUpdated()
        appointment.reminderStatus = status
        appointment.notificationRequestID = requestID
        try mainContext.save()
    }

    func softDelete(id: UUID) throws {
        guard let appointment = try fetchAppointment(id: id) else {
            return
        }

        appointment.markDeleted()
        appointment.notificationRequestID = nil
        try mainContext.save()
    }

    private var mainContext: ModelContext {
        modelContainer.mainContext
    }

    private func readContext() -> ModelContext {
        ModelContext(modelContainer)
    }

    private func fetchDoctor(id: UUID) throws -> Doctor? {
        let descriptor = FetchDescriptor<Doctor>(
            predicate: #Predicate<Doctor> { $0.id == id }
        )
        return try mainContext.fetch(descriptor).first
    }

    private func fetchAppointment(id: UUID) throws -> DoctorAppointment? {
        let descriptor = FetchDescriptor<DoctorAppointment>(
            predicate: #Predicate<DoctorAppointment> { $0.id == id }
        )
        return try mainContext.fetch(descriptor).first
    }
}

private extension EpisodeRecord {
    init(episode: Episode, healthContextStore: HealthContextStore) {
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

private extension DoctorRecord {
    init(doctor: Doctor) {
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
    init(appointment: DoctorAppointment) {
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
    init(entry: DoctorDirectoryEntry) {
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
