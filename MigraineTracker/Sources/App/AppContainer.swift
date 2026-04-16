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
    let syncService: SyncService
    let appLogService: AppLogService

    init(modelContainer: ModelContainer, syncCoordinator: SyncCoordinator, appLogStore: AppLogStore) {
        self.modelContainer = modelContainer
        self.syncCoordinator = syncCoordinator
        self.appLogStore = appLogStore
        let weatherService = OpenMeteoDwdWeatherService()
        let locationService = SystemLocationService()
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
        self.syncService = SyncServiceAdapter(coordinator: syncCoordinator)
        self.appLogService = appLogStore
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
}
