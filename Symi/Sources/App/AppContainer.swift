import Foundation
import SwiftData

@MainActor
final class AppContainer {
    let featureDependencies: AppFeatureDependencies
    let featureFlags: FeatureFlags

    private let startupMaintenanceService: StartupMaintenanceService
    private let syncCoordinator: SyncCoordinator

    init(
        modelContainer: ModelContainer,
        syncCoordinator: SyncCoordinator,
        appLogStore: AppLogStore,
        weatherService: any WeatherService = AppleWeatherKitWeatherService(),
        locationService: any LocationService = SystemLocationService(),
        healthService: any HealthService = AppleHealthKitService(),
        healthContextStore: HealthContextStore = HealthContextStore(),
        usageDataConsentService: UsageDataConsentService = AppTelemetryService.shared,
        featureFlags: FeatureFlags = .defaults
    ) {
        self.syncCoordinator = syncCoordinator
        self.featureFlags = featureFlags
        let episodeWeatherContextService = EpisodeWeatherContextService(
            weatherService: weatherService,
            locationService: locationService
        )
        let weatherBackfillService = WeatherBackfillService(
            modelContainer: modelContainer,
            weatherService: weatherService,
            locationService: locationService
        )
        self.startupMaintenanceService = StartupMaintenanceService(
            modelContainer: modelContainer,
            weatherBackfillService: weatherBackfillService
        )

        let episodeRepository = SwiftDataEpisodeRepository(modelContainer: modelContainer, healthContextStore: healthContextStore)
        let medicationCatalogRepository = SwiftDataMedicationCatalogRepository(modelContainer: modelContainer)
        let continuousMedicationRepository = SwiftDataContinuousMedicationRepository(modelContainer: modelContainer)
        let exportRepository = SwiftDataExportRepository(modelContainer: modelContainer, healthContextStore: healthContextStore)
        let insightEngine = InsightEngine()
        let syncService = SyncServiceAdapter(coordinator: syncCoordinator)

        let capture = CaptureFeatureDependencies(
            makeEntryFlowCoordinator: { initialStartedAt in
                EntryFlowCoordinator(
                    initialStartedAt: initialStartedAt,
                    episodeRepository: episodeRepository,
                    medicationRepository: medicationCatalogRepository,
                    continuousMedicationRepository: continuousMedicationRepository,
                    weatherContextService: episodeWeatherContextService,
                    healthService: healthService
                )
            },
            makeEpisodeEditorController: { episodeID, initialStartedAt in
                EpisodeEditorController(
                    episodeID: episodeID,
                    initialStartedAt: initialStartedAt,
                    episodeRepository: episodeRepository,
                    medicationRepository: medicationCatalogRepository,
                    syncService: syncService,
                    weatherContextService: episodeWeatherContextService,
                    healthService: healthService
                )
            }
        )
        let history = HistoryFeatureDependencies(
            makeHistoryController: {
                HistoryController(repository: episodeRepository)
            },
            loadEpisodeDetail: { episodeID in
                try await LoadEpisodeDetailUseCase(repository: episodeRepository).execute(id: episodeID)
            },
            deleteEpisode: { episodeID in
                try await DeleteEpisodeUseCase(repository: episodeRepository).execute(id: episodeID)
            },
            capture: capture
        )
        let insights = InsightsFeatureDependencies(
            loadResult: { period in
                try await LoadInsightResultUseCase(
                    repository: episodeRepository,
                    insightEngine: insightEngine
                ).execute(period: period)
            }
        )
        let dataExport = DataExportFeatureDependencies(
            makeDataExportController: {
                DataExportController(repository: exportRepository)
            }
        )
        let settings = SettingsFeatureDependencies(
            makeSettingsController: {
                SettingsController(
                    episodeRepository: episodeRepository,
                    medicationRepository: medicationCatalogRepository,
                    syncService: syncService,
                    appLogService: appLogStore,
                    healthService: healthService,
                    usageDataConsentService: usageDataConsentService
                )
            },
            makeSymiPlusStore: {
                SymiPlusStore()
            },
            dataExport: dataExport
        )
        let therapy = TherapyFeatureDependencies(
            makeTherapyViewModel: {
                TherapyViewModel(repository: continuousMedicationRepository)
            }
        )
        self.featureDependencies = AppFeatureDependencies(
            featureFlags: featureFlags,
            home: HomeFeatureDependencies(
                loadCalendarMonth: { month in
                    try await LoadHistoryMonthUseCase(repository: episodeRepository).execute(month: month)
                },
                loadPatternPreview: {
                    try await LoadHomePatternPreviewUseCase(
                        repository: episodeRepository,
                        insightEngine: insightEngine
                    ).execute()
                },
                capture: capture,
                history: history,
                insights: insights
            ),
            capture: capture,
            history: history,
            insights: insights,
            therapy: therapy,
            settings: settings,
            dataExport: dataExport
        )
    }

    func startDeferredMaintenanceIfNeeded() {
        startupMaintenanceService.startIfNeeded()
    }

    func appDidBecomeActive() {
        syncCoordinator.appDidBecomeActive()
    }
}

@MainActor
struct AppFeatureDependencies {
    let featureFlags: FeatureFlags
    let home: HomeFeatureDependencies
    let capture: CaptureFeatureDependencies
    let history: HistoryFeatureDependencies
    let insights: InsightsFeatureDependencies
    let therapy: TherapyFeatureDependencies
    let settings: SettingsFeatureDependencies
    let dataExport: DataExportFeatureDependencies
}

@MainActor
struct HomeFeatureDependencies {
    let loadCalendarMonth: (Date) async throws -> HistoryMonthData
    let loadPatternPreview: () async throws -> HomePatternPreviewData
    let capture: CaptureFeatureDependencies
    let history: HistoryFeatureDependencies
    let insights: InsightsFeatureDependencies
}

@MainActor
struct CaptureFeatureDependencies {
    let makeEntryFlowCoordinator: (Date?) -> EntryFlowCoordinator
    let makeEpisodeEditorController: (UUID?, Date?) -> EpisodeEditorController
}

@MainActor
struct HistoryFeatureDependencies {
    let makeHistoryController: () -> HistoryController
    let loadEpisodeDetail: (UUID) async throws -> EpisodeRecord?
    let deleteEpisode: (UUID) async throws -> Void
    let capture: CaptureFeatureDependencies
}

@MainActor
struct InsightsFeatureDependencies {
    let loadResult: (InsightPeriod) async throws -> InsightResult
}

@MainActor
struct TherapyFeatureDependencies {
    let makeTherapyViewModel: () -> TherapyViewModel
}

@MainActor
struct SettingsFeatureDependencies {
    let makeSettingsController: () -> SettingsController
    let makeSymiPlusStore: () -> SymiPlusStore
    let dataExport: DataExportFeatureDependencies
}

@MainActor
struct DataExportFeatureDependencies {
    let makeDataExportController: () -> DataExportController
}
