import Foundation
import CoreLocation
import Testing
import WeatherKit
@testable import MigraineTracker

@MainActor
struct CoreArchitectureTests {
    @Test
    func saveEpisodeUseCaseRejectsInvalidDateRange() async {
        let repository = EpisodeRepositoryMock()
        let useCase = SaveEpisodeUseCase(repository: repository)
        var draft = EpisodeDraft.makeNew()
        draft.endedAtEnabled = true
        draft.startedAt = Date(timeIntervalSince1970: 2_000)
        draft.endedAt = Date(timeIntervalSince1970: 1_000)

        await #expect(throws: EpisodeSaveError.invalidDateRange) {
            try await useCase.execute(draft, weatherSnapshot: nil)
        }
    }

    @Test
    func saveEpisodeUseCasePassesWeatherSnapshotToRepository() async throws {
        let repository = EpisodeRepositoryMock()
        let useCase = SaveEpisodeUseCase(repository: repository)
        let draft = EpisodeDraft.makeNew()
        let snapshot = WeatherSnapshotData(
            recordedAt: Date(timeIntervalSince1970: 1_000),
            condition: "Regen",
            temperature: 18.5,
            humidity: 72,
            pressure: 1004,
            precipitation: 1.4,
            weatherCode: 63,
            source: "Apple Weather"
        )

        let savedID = try await useCase.execute(draft, weatherSnapshot: snapshot)

        #expect(savedID == repository.savedDraftID)
        #expect(repository.lastWeatherSnapshot == snapshot)
    }

    @Test
    func saveEpisodeUseCasePassesHealthContextToRepository() async throws {
        let repository = EpisodeRepositoryMock()
        let useCase = SaveEpisodeUseCase(repository: repository)
        let draft = EpisodeDraft.makeNew()
        let context = HealthContextSnapshotData(
            recordedAt: Date(timeIntervalSince1970: 2_000),
            source: "Apple Health",
            sleepMinutes: 420,
            stepCount: 3_200,
            averageHeartRate: 78,
            restingHeartRate: 62,
            heartRateVariability: 41,
            menstrualFlow: nil,
            symptoms: [
                HealthSymptomSampleData(
                    type: .headache,
                    severity: "Mittel",
                    startDate: draft.startedAt,
                    endDate: draft.startedAt,
                    source: "Health"
                )
            ]
        )

        _ = try await useCase.execute(draft, weatherSnapshot: nil, healthContext: context)

        #expect(repository.lastHealthContext == context)
    }

    @Test
    func healthSeverityMapperUsesPainIntensityBands() {
        #expect(HealthSeverityMapper.symptomSeverityLabel(forIntensity: 1) == "Leicht")
        #expect(HealthSeverityMapper.symptomSeverityLabel(forIntensity: 4) == "Mittel")
        #expect(HealthSeverityMapper.symptomSeverityLabel(forIntensity: 8) == "Stark")
    }

    @Test
    func healthTypePreferencesSeparateSelectionFromAuthorizationRequest() {
        let suiteName = "HealthTypePreferencesTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = HealthTypePreferences(defaults: defaults)

        let enabledTypes = preferences.enabledTypes(for: .read, definitions: HealthDataCatalog.readDefinitions)

        #expect(enabledTypes.contains(.sleep))
        #expect(preferences.hasRequestedAuthorization(for: .read) == false)

        preferences.markAuthorizationRequested(for: .read)

        #expect(preferences.hasRequestedAuthorization(for: .read) == true)
    }

    @Test
    func appleWeatherKitServiceSkipsDatesBeforeHourlyHistory() async throws {
        let service = AppleWeatherKitWeatherService()
        let oldDate = Date(timeIntervalSince1970: 1_627_775_999)
        let location = CLLocation(latitude: 48.2082, longitude: 16.3738)

        let snapshot = try await service.fetchWeather(for: oldDate, location: location)

        #expect(snapshot == nil)
    }

    @Test
    func weatherConditionMapperUsesGermanDescriptions() {
        #expect(WeatherConditionMapper.description(for: .clear) == "Klar")
        #expect(WeatherConditionMapper.description(for: .heavyRain) == "Starker Regen")
        #expect(WeatherConditionMapper.description(for: .thunderstorms) == "Gewitter")
    }

    @Test
    func saveEpisodeUseCaseRejectsFutureDate() async {
        let repository = EpisodeRepositoryMock()
        let useCase = SaveEpisodeUseCase(repository: repository)
        var draft = EpisodeDraft.makeNew()
        draft.startedAt = .now.addingTimeInterval(3_600)

        await #expect(throws: EpisodeSaveError.futureDate) {
            try await useCase.execute(draft, weatherSnapshot: nil)
        }
    }

    @Test
    func loadHistoryMonthUseCaseGroupsByCalendarDay() async throws {
        let repository = EpisodeRepositoryMock()
        let firstDay = Date(timeIntervalSince1970: 10_000)
        let sameDayLater = firstDay.addingTimeInterval(60 * 60)
        let secondDay = firstDay.addingTimeInterval(60 * 60 * 24)
        repository.monthRecords = [
            makeEpisode(id: UUID(), startedAt: firstDay, intensity: 5),
            makeEpisode(id: UUID(), startedAt: sameDayLater, intensity: 7),
            makeEpisode(id: UUID(), startedAt: secondDay, intensity: 3)
        ]

        let result = try await LoadHistoryMonthUseCase(repository: repository).execute(month: firstDay)

        #expect(result.episodesByDay.count == 2)
        #expect(result.episodesByDay[Calendar.current.startOfDay(for: firstDay)]?.count == 2)
        #expect(result.episodesByDay[Calendar.current.startOfDay(for: secondDay)]?.count == 1)
    }

    @Test
    func loadSettingsUseCaseCountsActiveTrashAndConflicts() async throws {
        let episodeRepository = EpisodeRepositoryMock()
        let medicationRepository = MedicationCatalogRepositoryMock()
        let syncService = SyncServiceMock()
        episodeRepository.recentRecords = [
            makeEpisode(id: UUID(), startedAt: .now, intensity: 5),
            makeEpisode(id: UUID(), startedAt: .now.addingTimeInterval(-1_000), intensity: 3)
        ]
        episodeRepository.deletedRecords = [
            makeEpisode(id: UUID(), startedAt: .now.addingTimeInterval(-2_000), intensity: 7, deletedAt: .now)
        ]
        medicationRepository.deletedDefinitions = [
            MedicationDefinitionRecord(
                catalogKey: "custom:1",
                groupID: "custom-medications",
                groupTitle: "Eigene Medikamente",
                groupFooter: nil,
                name: "Sumatriptan",
                category: .triptan,
                suggestedDosage: "50 mg",
                sortOrder: 1,
                isCustom: true,
                isDeleted: true
            )
        ]
        syncService.conflictsStorage = [
            SyncConflict(
                documentID: "episode-1",
                entityType: .episode,
                base: nil,
                local: sampleEnvelope(),
                remote: sampleEnvelope(),
                conflictingFields: ["notes"]
            )
        ]

        let summary = try await LoadSettingsUseCase(
            episodeRepository: episodeRepository,
            medicationRepository: medicationRepository,
            syncService: syncService
        ).execute()

        #expect(summary.activeEpisodeCount == 2)
        #expect(summary.trashCount == 2)
        #expect(summary.conflictCount == 1)
    }

    @Test
    func saveDoctorUseCaseRejectsMissingName() async {
        let repository = DoctorRepositoryMock()
        let useCase = SaveDoctorUseCase(repository: repository)

        await #expect(throws: DoctorSaveError.missingName) {
            try await useCase.execute(.makeNew())
        }
    }

    @Test
    func saveAppointmentUseCaseSchedulesReminderForSavedAppointment() async throws {
        let appointmentRepository = AppointmentRepositoryMock()
        let doctorRepository = DoctorRepositoryMock()
        let notificationService = NotificationServiceMock()
        let doctor = makeDoctor()
        doctorRepository.loadedDoctor = doctor

        let draft = AppointmentDraft.makeNew(doctor: doctor)

        let savedID = try await SaveAppointmentUseCase(
            appointmentRepository: appointmentRepository,
            doctorRepository: doctorRepository,
            notificationService: notificationService
        ).execute(draft)

        #expect(savedID == appointmentRepository.savedAppointmentID)
        #expect(notificationService.scheduledAppointment?.id == appointmentRepository.savedAppointmentID)
        #expect(appointmentRepository.lastReminderUpdate?.status == .scheduled)
        #expect(appointmentRepository.lastReminderUpdate?.requestID == "request-1")
    }

    @Test
    func deleteAppointmentUseCaseRemovesPendingNotification() async throws {
        let appointmentRepository = AppointmentRepositoryMock()
        let notificationService = NotificationServiceMock()
        appointmentRepository.loadedAppointment = makeAppointment(notificationRequestID: "existing-request")

        try await DeleteAppointmentUseCase(
            appointmentRepository: appointmentRepository,
            notificationService: notificationService
        ).execute(id: appointmentRepository.loadedAppointment!.id)

        #expect(notificationService.removedRequestIDs == ["existing-request"])
        #expect(appointmentRepository.deletedIDs == [appointmentRepository.loadedAppointment!.id])
    }
}

private final class EpisodeRepositoryMock: EpisodeRepository, @unchecked Sendable {
    var recentRecords: [EpisodeRecord] = []
    var monthRecords: [EpisodeRecord] = []
    var dayRecords: [EpisodeRecord] = []
    var loadedRecord: EpisodeRecord?
    var deletedRecords: [EpisodeRecord] = []
    var lastSavedDraft: EpisodeDraft?
    var lastWeatherSnapshot: WeatherSnapshotData?
    var lastHealthContext: HealthContextSnapshotData?
    let savedDraftID = UUID()

    func fetchRecent() throws -> [EpisodeRecord] { recentRecords }
    func fetchByDay(_ day: Date) throws -> [EpisodeRecord] { dayRecords }
    func fetchByMonth(_ month: Date) throws -> [EpisodeRecord] { monthRecords }
    func load(id: UUID) throws -> EpisodeRecord? { loadedRecord }
    func save(draft: EpisodeDraft, weatherSnapshot: WeatherSnapshotData?, healthContext: HealthContextSnapshotData?) throws -> UUID {
        lastSavedDraft = draft
        lastWeatherSnapshot = weatherSnapshot
        lastHealthContext = healthContext
        return savedDraftID
    }
    func softDelete(id: UUID) throws {}
    func restore(id: UUID) throws {}
    func fetchDeleted() throws -> [EpisodeRecord] { deletedRecords }
}

private final class MedicationCatalogRepositoryMock: MedicationCatalogRepository, @unchecked Sendable {
    var definitions: [MedicationDefinitionRecord] = []
    var deletedDefinitions: [MedicationDefinitionRecord] = []

    func fetchDefinitions(searchText: String?) throws -> [MedicationDefinitionRecord] { definitions }
    func saveCustomDefinition(_ draft: CustomMedicationDefinitionDraft) throws -> MedicationDefinitionRecord {
        MedicationDefinitionRecord(
            catalogKey: draft.id,
            groupID: "custom-medications",
            groupTitle: "Eigene Medikamente",
            groupFooter: nil,
            name: draft.name,
            category: draft.category,
            suggestedDosage: draft.dosage,
            sortOrder: 1,
            isCustom: true,
            isDeleted: false
        )
    }
    func softDeleteCustomDefinition(catalogKey: String) throws {}
    func fetchDeletedDefinitions() throws -> [MedicationDefinitionRecord] { deletedDefinitions }
}

@MainActor
private final class SyncServiceMock: SyncService {
    var isEnabled = false
    var status = SyncStatusSnapshot()
    var conflictsStorage: [SyncConflict] = []
    var conflicts: [SyncConflict] { conflictsStorage }

    func setSyncEnabled(_ enabled: Bool) { isEnabled = enabled }
    func refreshStatus() {}
    func syncNow() async {}
    func retryLastError() async {}
    func resolveConflictKeepingLocal(_ conflict: SyncConflict) async {}
    func resolveConflictUsingRemote(_ conflict: SyncConflict) async {}
}

private final class DoctorRepositoryMock: DoctorRepository, @unchecked Sendable {
    var doctors: [DoctorRecord] = []
    var loadedDoctor: DoctorRecord?
    var lastSavedDraft: DoctorDraft?
    var savedDoctorID = UUID()
    var deletedIDs: [UUID] = []

    func fetchAll() throws -> [DoctorRecord] { doctors }
    func load(id: UUID) throws -> DoctorRecord? { loadedDoctor }
    func save(draft: DoctorDraft) throws -> UUID {
        lastSavedDraft = draft
        return draft.id ?? savedDoctorID
    }
    func softDelete(id: UUID) throws {
        deletedIDs.append(id)
    }
}

private final class AppointmentRepositoryMock: AppointmentRepository, @unchecked Sendable {
    var appointments: [AppointmentRecord] = []
    var loadedAppointment: AppointmentRecord?
    var lastSavedDraft: AppointmentDraft?
    var savedAppointmentID = UUID()
    var lastReminderUpdate: (id: UUID, status: AppointmentReminderStatus, requestID: String?)?
    var deletedIDs: [UUID] = []

    func fetchUpcoming(limit: Int?) throws -> [AppointmentRecord] { appointments }
    func fetchUpcoming(for doctorID: UUID) throws -> [AppointmentRecord] { appointments.filter { $0.doctorID == doctorID } }
    func load(id: UUID) throws -> AppointmentRecord? {
        if let loadedAppointment, loadedAppointment.id == id {
            return loadedAppointment
        }

        if id == savedAppointmentID, let lastSavedDraft {
            return AppointmentRecord(
                id: savedAppointmentID,
                doctorID: lastSavedDraft.doctorID,
                createdAt: .now,
                updatedAt: .now,
                deletedAt: nil,
                scheduledAt: lastSavedDraft.scheduledAt,
                endsAt: lastSavedDraft.endsAtEnabled ? lastSavedDraft.endsAt : nil,
                practiceName: lastSavedDraft.practiceName,
                addressText: lastSavedDraft.addressText,
                note: lastSavedDraft.note,
                reminderEnabled: lastSavedDraft.reminderEnabled,
                reminderLeadTimeMinutes: lastSavedDraft.reminderLeadTimeMinutes,
                reminderStatus: .authorized,
                notificationRequestID: nil
            )
        }

        return nil
    }
    func save(draft: AppointmentDraft) throws -> UUID {
        lastSavedDraft = draft
        return draft.id ?? savedAppointmentID
    }
    func updateReminder(id: UUID, status: AppointmentReminderStatus, requestID: String?) throws {
        lastReminderUpdate = (id, status, requestID)
    }
    func softDelete(id: UUID) throws {
        deletedIDs.append(id)
    }
}

private final class NotificationServiceMock: NotificationService {
    var scheduledAppointment: AppointmentRecord?
    var scheduledDoctor: DoctorRecord?
    var removedRequestIDs: [String] = []
    var result = ReminderSchedulingResult(status: .scheduled, requestID: "request-1")

    func scheduleAppointmentReminder(for appointment: AppointmentRecord, doctor: DoctorRecord) async -> ReminderSchedulingResult {
        scheduledAppointment = appointment
        scheduledDoctor = doctor
        return result
    }

    func removePendingNotification(requestID: String) async {
        removedRequestIDs.append(requestID)
    }
}

private func makeEpisode(id: UUID, startedAt: Date, intensity: Int, deletedAt: Date? = nil) -> EpisodeRecord {
    EpisodeRecord(
        id: id,
        startedAt: startedAt,
        endedAt: nil,
        updatedAt: startedAt,
        deletedAt: deletedAt,
        type: .migraine,
        intensity: intensity,
        painLocation: "",
        painCharacter: "",
        notes: "",
        symptoms: [],
        triggers: [],
        functionalImpact: "",
        menstruationStatus: .unknown,
        medications: [],
        weather: nil,
        healthContext: nil
    )
}

private func sampleEnvelope() -> SyncDocumentEnvelope {
    SyncDocumentEnvelope(
        documentID: "episode-1",
        entityType: .episode,
        modifiedAt: .now,
        authorDeviceID: "device-a",
        payload: .episode(
            SyncEpisodePayload(
                id: "episode-1",
                startedAt: .now,
                endedAt: nil,
                type: "Migräne",
                intensity: 5,
                painLocation: "",
                painCharacter: "",
                notes: "",
                symptoms: [],
                triggers: [],
                functionalImpact: "",
                menstruationStatus: MenstruationStatus.unknown.rawValue,
                medications: [],
                weatherSnapshot: nil
            )
        )
    )
}

private func makeDoctor(id: UUID = UUID()) -> DoctorRecord {
    DoctorRecord(
        id: id,
        createdAt: .now,
        updatedAt: .now,
        deletedAt: nil,
        name: "Dr. Test",
        specialty: "Neurologie",
        street: "Teststraße 1",
        city: "Wien",
        state: "Wien",
        postalCode: "1010",
        phone: "",
        email: "",
        notes: "",
        source: .manual,
        appointments: []
    )
}

private func makeAppointment(id: UUID = UUID(), notificationRequestID: String?) -> AppointmentRecord {
    AppointmentRecord(
        id: id,
        doctorID: UUID(),
        createdAt: .now,
        updatedAt: .now,
        deletedAt: nil,
        scheduledAt: .now.addingTimeInterval(3_600),
        endsAt: nil,
        practiceName: "Ordination",
        addressText: "Teststraße 1",
        note: "",
        reminderEnabled: true,
        reminderLeadTimeMinutes: 24 * 60,
        reminderStatus: .scheduled,
        notificationRequestID: notificationRequestID
    )
}
