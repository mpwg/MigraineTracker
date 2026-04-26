import Foundation
import SwiftData

@MainActor
final class AppContainer {
    let modelContainer: ModelContainer
    let syncCoordinator: SyncCoordinator
    let appLogStore: AppLogStore
    let weatherService: WeatherService
    let locationService: LocationService
    let healthService: HealthService
    let healthContextStore: HealthContextStore
    let episodeWeatherContextService: EpisodeWeatherContextProviding
    let weatherBackfillService: WeatherBackfillService
    let startupMaintenanceService: StartupMaintenanceService

    let episodeRepository: EpisodeRepository
    let medicationCatalogRepository: MedicationCatalogRepository
    let continuousMedicationRepository: ContinuousMedicationRepository
    let exportRepository: ExportRepository
    let syncService: SyncService
    let appLogService: AppLogService

    init(
        modelContainer: ModelContainer,
        syncCoordinator: SyncCoordinator,
        appLogStore: AppLogStore,
        weatherService: any WeatherService = AppleWeatherKitWeatherService(),
        locationService: any LocationService = SystemLocationService(),
        healthService: any HealthService = AppleHealthKitService(),
        healthContextStore: HealthContextStore = HealthContextStore()
    ) {
        self.modelContainer = modelContainer
        self.syncCoordinator = syncCoordinator
        self.appLogStore = appLogStore
        self.weatherService = weatherService
        self.locationService = locationService
        self.healthService = healthService
        self.healthContextStore = healthContextStore
        self.episodeWeatherContextService = EpisodeWeatherContextService(
            weatherService: weatherService,
            locationService: locationService
        )
        self.weatherBackfillService = WeatherBackfillService(
            modelContainer: modelContainer,
            weatherService: weatherService,
            locationService: locationService
        )
        self.startupMaintenanceService = StartupMaintenanceService(
            modelContainer: modelContainer,
            weatherBackfillService: weatherBackfillService
        )
        self.episodeRepository = SwiftDataEpisodeRepository(modelContainer: modelContainer, healthContextStore: healthContextStore)
        self.medicationCatalogRepository = SwiftDataMedicationCatalogRepository(modelContainer: modelContainer)
        self.continuousMedicationRepository = SwiftDataContinuousMedicationRepository(modelContainer: modelContainer)
        self.exportRepository = SwiftDataExportRepository(modelContainer: modelContainer, healthContextStore: healthContextStore)
        self.syncService = SyncServiceAdapter(coordinator: syncCoordinator)
        self.appLogService = appLogStore
    }

    func startDeferredMaintenanceIfNeeded() {
        startupMaintenanceService.startIfNeeded()
    }

    func makeEpisodeEditorController(episodeID: UUID? = nil, initialStartedAt: Date? = nil) -> EpisodeEditorController {
        EpisodeEditorController(
            episodeID: episodeID,
            initialStartedAt: initialStartedAt,
            episodeRepository: episodeRepository,
            medicationRepository: medicationCatalogRepository,
            weatherContextService: episodeWeatherContextService,
            healthService: healthService
        )
    }

    func makeEntryFlowCoordinator(initialStartedAt: Date? = nil) -> EntryFlowCoordinator {
        EntryFlowCoordinator(
            initialStartedAt: initialStartedAt,
            episodeRepository: episodeRepository,
            medicationRepository: medicationCatalogRepository,
            continuousMedicationRepository: continuousMedicationRepository,
            weatherContextService: episodeWeatherContextService,
            healthService: healthService
        )
    }

    func makeHistoryController() -> HistoryController {
        HistoryController(repository: episodeRepository)
    }

    func makeSettingsController() -> SettingsController {
        SettingsController(
            episodeRepository: episodeRepository,
            medicationRepository: medicationCatalogRepository,
            continuousMedicationRepository: continuousMedicationRepository,
            syncService: syncService,
            appLogService: appLogService,
            healthService: healthService
        )
    }

    func makeDataExportController() -> DataExportController {
        DataExportController(repository: exportRepository)
    }

}
