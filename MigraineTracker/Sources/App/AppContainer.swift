import Foundation
import SwiftData

@MainActor
final class AppContainer {
    let modelContainer: ModelContainer
    let syncCoordinator: SyncCoordinator
    let appLogStore: AppLogStore
    let weatherService: WeatherService
    let locationService: LocationService
    let weatherBackfillService: WeatherBackfillService

    let episodeRepository: EpisodeRepository
    let medicationCatalogRepository: MedicationCatalogRepository
    let exportRepository: ExportRepository
    let doctorRepository: DoctorRepository
    let doctorDirectoryRepository: DoctorDirectoryRepository
    let appointmentRepository: AppointmentRepository
    let syncService: SyncService
    let appLogService: AppLogService
    let notificationService: NotificationService

    init(
        modelContainer: ModelContainer,
        syncCoordinator: SyncCoordinator,
        appLogStore: AppLogStore,
        weatherService: any WeatherService = AppleWeatherKitWeatherService(),
        locationService: any LocationService = SystemLocationService(),
        notificationService: any NotificationService = UserNotificationService()
    ) {
        self.modelContainer = modelContainer
        self.syncCoordinator = syncCoordinator
        self.appLogStore = appLogStore
        self.weatherService = weatherService
        self.locationService = locationService
        self.weatherBackfillService = WeatherBackfillService(
            modelContainer: modelContainer,
            weatherService: weatherService,
            locationService: locationService
        )
        self.episodeRepository = SwiftDataEpisodeRepository(modelContainer: modelContainer)
        self.medicationCatalogRepository = SwiftDataMedicationCatalogRepository(modelContainer: modelContainer)
        self.exportRepository = SwiftDataExportRepository(modelContainer: modelContainer)
        self.doctorRepository = SwiftDataDoctorRepository(modelContainer: modelContainer)
        self.doctorDirectoryRepository = SwiftDataDoctorDirectoryRepository(modelContainer: modelContainer)
        self.appointmentRepository = SwiftDataAppointmentRepository(modelContainer: modelContainer)
        self.syncService = SyncServiceAdapter(coordinator: syncCoordinator)
        self.appLogService = appLogStore
        self.notificationService = notificationService
    }

    func makeEpisodeEditorController(episodeID: UUID? = nil, initialStartedAt: Date? = nil) -> EpisodeEditorController {
        EpisodeEditorController(
            episodeID: episodeID,
            initialStartedAt: initialStartedAt,
            episodeRepository: episodeRepository,
            medicationRepository: medicationCatalogRepository,
            weatherService: weatherService,
            locationService: locationService
        )
    }

    func makeHistoryController() -> HistoryController {
        HistoryController(repository: episodeRepository)
    }

    func makeSettingsController() -> SettingsController {
        SettingsController(
            episodeRepository: episodeRepository,
            medicationRepository: medicationCatalogRepository,
            syncService: syncService,
            appLogService: appLogService
        )
    }

    func makeDataExportController() -> DataExportController {
        DataExportController(repository: exportRepository)
    }

    func makeDoctorHubController() -> DoctorHubController {
        DoctorHubController(
            doctorRepository: doctorRepository,
            appointmentRepository: appointmentRepository
        )
    }

    func makeDoctorEditorController(doctor: DoctorRecord?) -> DoctorEditorController {
        DoctorEditorController(
            doctor: doctor,
            doctorRepository: doctorRepository,
            directoryRepository: doctorDirectoryRepository
        )
    }

    func makeAppointmentEditorController(appointment: AppointmentRecord?, doctor: DoctorRecord) -> AppointmentEditorController {
        AppointmentEditorController(
            appointment: appointment,
            doctor: doctor,
            appointmentRepository: appointmentRepository,
            doctorRepository: doctorRepository,
            notificationService: notificationService
        )
    }
}
