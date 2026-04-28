import SwiftUI
import Sentry
import TelemetryDeck

import SwiftData
import OSLog

@main
struct SymiApp: App {
    private static let logger = Logger(subsystem: "Symi", category: "Persistence")
    private let launchConfiguration: AppLaunchConfiguration
    private let initialStartupState: AppStartupState

    init() {
        let launchConfiguration = AppLaunchConfiguration.current
        self.launchConfiguration = launchConfiguration

        Self.configureTelemetry(for: launchConfiguration)
        self.initialStartupState = Self.makeInitialStartupState(launchConfiguration: launchConfiguration)
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(
                launchConfiguration: launchConfiguration,
                initialStartupState: initialStartupState
            )
        }
        #if targetEnvironment(macCatalyst)
        .defaultSize(width: SymiSize.defaultWindowWidth, height: SymiSize.defaultWindowHeight)
        .windowResizability(.contentSize)
        #endif
    }

    @MainActor
    static func makeContainer(schema: Schema, configuration: ModelConfiguration) throws -> ModelContainer {
        try makeContainer(schema: schema, configuration: configuration) {
            try ModelContainer(
                for: schema,
                migrationPlan: SymiMigrationPlan.self,
                configurations: [configuration]
            )
        }
    }

    @MainActor
    static func makeContainer(
        schema: Schema,
        configuration: ModelConfiguration,
        loadContainer: () throws -> ModelContainer
    ) throws -> ModelContainer {
        do {
            logger.debug("Versuche ModelContainer für lokalen Store zu laden.")
            return try loadContainer()
        } catch {
            let context = PersistentStoreRecoveryService.recoveryContext(for: error, storeURL: configuration.url)
            logger.error(
                "ModelContainer konnte nicht geladen werden. Recovery wird vorbereitet. Grund: \(context.reason.rawValue, privacy: .public), Fehler: \(context.errorSummary, privacy: .public)"
            )
            throw PersistentStoreLoadError.recoveryRequired(context)
        }
    }

    @MainActor
    static func makeAppRuntimeEnvironment(
        launchConfiguration: AppLaunchConfiguration,
        storeURL overrideStoreURL: URL? = nil,
        applicationSupportDirectoryURL: URL? = nil
    ) throws -> AppRuntimeEnvironment {
        let schema = Schema(versionedSchema: SymiSchemaV6.self)
        let storeURL = try resolvedStoreURL(
            overrideStoreURL: overrideStoreURL,
            launchConfiguration: launchConfiguration,
            applicationSupportDirectoryURL: applicationSupportDirectoryURL
        )
        let configuration = ModelConfiguration(
            "default",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )

        let container = try makeContainer(schema: schema, configuration: configuration)
        let appLogStore = AppLogStore()
        let healthContextStore = HealthContextStore()
        let syncCoordinator = SyncCoordinator(
            modelContainer: container,
            appLogStore: appLogStore,
            healthContextStore: healthContextStore,
            autostart: !launchConfiguration.isRunningTests
        )
        let appContainer = AppContainer(
            modelContainer: container,
            syncCoordinator: syncCoordinator,
            appLogStore: appLogStore,
            healthContextStore: healthContextStore
        )

        return AppRuntimeEnvironment(
            modelContainer: container,
            appContainer: appContainer,
            appLogStore: appLogStore,
            syncCoordinator: syncCoordinator,
            screenshotSeed: nil
        )
    }

    @MainActor
    static func makeInitialStartupState(launchConfiguration: AppLaunchConfiguration) -> AppStartupState {
        do {
            if launchConfiguration.isScreenshotMode {
                let environment = try ScreenshotBootstrap.makeEnvironment(seedName: launchConfiguration.screenshotSeedName)
                return .app(
                    AppRuntimeEnvironment(
                        modelContainer: environment.0,
                        appContainer: environment.1,
                        appLogStore: environment.2,
                        syncCoordinator: environment.3,
                        screenshotSeed: environment.4
                    )
                )
            }

            return .app(try makeAppRuntimeEnvironment(launchConfiguration: launchConfiguration))
        } catch PersistentStoreLoadError.recoveryRequired(let context) {
            do {
                return .recovery(
                    StoreRecoveryEnvironment(
                        context: context,
                        fallbackContainer: try makeRecoveryContainer()
                    )
                )
            } catch {
                logger.error("Recovery-Container konnte nicht erstellt werden. Safe-Mode wird angezeigt. Fehler: \(Self.sanitizedSummary(for: error), privacy: .public)")
                return .safeMode(
                    AppStartupFailureContext(
                        reason: .recoveryUnavailable,
                        errorSummary: sanitizedSummary(for: error),
                        storeURL: context.storeURL,
                        recoveryContext: context
                    )
                )
            }
        } catch {
            logger.error("App-Start konnte nicht vorbereitet werden. Safe-Mode wird angezeigt. Fehler: \(Self.sanitizedSummary(for: error), privacy: .public)")
            return .safeMode(
                AppStartupFailureContext(
                    reason: .bootstrapFailure,
                    errorSummary: sanitizedSummary(for: error),
                    storeURL: nil,
                    recoveryContext: nil
                )
            )
        }
    }

    @MainActor
    private static func makeRecoveryContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SymiSchemaV6.self)
        let configuration = ModelConfiguration(
            "recovery",
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )

        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func configureTelemetry(for launchConfiguration: AppLaunchConfiguration) {
        if !launchConfiguration.isScreenshotMode, !launchConfiguration.isRunningTests, let sentryDSN = Self.sentryDSN {
            SentrySDK.start { options in
                options.dsn = sentryDSN

                options.sendDefaultPii = false
                options.tracesSampleRate = 0.2

                options.configureProfiling = {
                    $0.sessionSampleRate = 0.05
                    $0.lifecycle = .trace
                }

                options.attachScreenshot = false
                options.attachViewHierarchy = false
                options.debug = false
                options.enableLogs = false
            }
        } else {
            Self.logger.notice("Sentry ist deaktiviert, weil keine gültige DSN in der App-Konfiguration gefunden wurde.")
        }

        if !launchConfiguration.isScreenshotMode, !launchConfiguration.isRunningTests, let telemetryAppID = Self.telemetryAppID {
            TelemetryDeck.initialize(config: .init(appID: telemetryAppID))
        }
    }

    static func defaultStoreURL(
        applicationSupportDirectoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> URL {
        guard let applicationSupportURL = applicationSupportDirectoryURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw AppStartupPreparationError.applicationSupportDirectoryUnavailable
        }

        try fileManager.createDirectory(at: applicationSupportURL, withIntermediateDirectories: true)
        return applicationSupportURL.appending(path: "default.store")
    }

    private static func resolvedStoreURL(
        overrideStoreURL: URL?,
        launchConfiguration: AppLaunchConfiguration,
        applicationSupportDirectoryURL: URL?
    ) throws -> URL {
        if let overrideStoreURL {
            return overrideStoreURL
        }

        if launchConfiguration.isRunningTests {
            return unitTestStoreURL()
        }

        return try defaultStoreURL(applicationSupportDirectoryURL: applicationSupportDirectoryURL)
    }

    private static func unitTestStoreURL() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "Symi-UnitTests-\(UUID().uuidString).store")
    }

    private static var sentryDSN: String? {
        normalize(Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String)
    }

    private static var telemetryAppID: String? {
        normalize(Bundle.main.object(forInfoDictionaryKey: "TELEMETRY_APP_ID") as? String)
    }

    private static func normalize(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil
        }

        if trimmed.hasPrefix("$("), trimmed.hasSuffix(")") {
            return nil
        }

        return trimmed
    }

    static func sanitizedSummary(for error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.domain) \(nsError.code)"
    }
}

@MainActor
enum AppStartupState {
    case app(AppRuntimeEnvironment)
    case recovery(StoreRecoveryEnvironment)
    case safeMode(AppStartupFailureContext)
}

@MainActor
final class AppRuntimeEnvironment {
    let modelContainer: ModelContainer
    let appContainer: AppContainer
    let appLogStore: AppLogStore
    let syncCoordinator: SyncCoordinator
    let screenshotSeed: ScreenshotSeed?

    init(
        modelContainer: ModelContainer,
        appContainer: AppContainer,
        appLogStore: AppLogStore,
        syncCoordinator: SyncCoordinator,
        screenshotSeed: ScreenshotSeed?
    ) {
        self.modelContainer = modelContainer
        self.appContainer = appContainer
        self.appLogStore = appLogStore
        self.syncCoordinator = syncCoordinator
        self.screenshotSeed = screenshotSeed
    }
}

@MainActor
struct StoreRecoveryEnvironment {
    let context: PersistentStoreRecoveryContext
    let fallbackContainer: ModelContainer
}

private struct AppRootView: View {
    let launchConfiguration: AppLaunchConfiguration
    @State private var startupState: AppStartupState

    init(launchConfiguration: AppLaunchConfiguration, initialStartupState: AppStartupState) {
        self.launchConfiguration = launchConfiguration
        _startupState = State(initialValue: initialStartupState)
    }

    var body: some View {
        switch startupState {
        case .app(let environment):
            appContent(environment: environment)
                .modelContainer(environment.modelContainer)
        case .recovery(let environment):
            StoreRecoveryView(
                context: environment.context,
                prepareStoreBackup: {
                    try PersistentStoreRecoveryService.copyStoreFilesForSharing(from: environment.context.storeURL)
                },
                startEmptyStore: {
                    try PersistentStoreRecoveryService.removeStoreFilesAfterUserConfirmation(at: environment.context.storeURL)
                    return try SymiApp.makeAppRuntimeEnvironment(
                        launchConfiguration: launchConfiguration,
                        storeURL: environment.context.storeURL
                    )
                },
                didRecover: { recoveredEnvironment in
                    startupState = .app(recoveredEnvironment)
                }
            )
            .modelContainer(environment.fallbackContainer)
        case .safeMode(let context):
            StartupSafeModeView(
                context: context,
                prepareStoreBackup: {
                    guard let storeURL = context.storeURL else {
                        throw PersistentStoreRecoveryFileError.noStoreFilesFound
                    }

                    return try PersistentStoreRecoveryService.copyStoreFilesForSharing(from: storeURL)
                },
                startEmptyStore: {
                    guard let storeURL = context.storeURL else {
                        throw PersistentStoreRecoveryFileError.noStoreFilesFound
                    }

                    try PersistentStoreRecoveryService.removeStoreFilesAfterUserConfirmation(at: storeURL)
                    return try SymiApp.makeAppRuntimeEnvironment(
                        launchConfiguration: launchConfiguration,
                        storeURL: storeURL
                    )
                },
                didRecover: { recoveredEnvironment in
                    startupState = .app(recoveredEnvironment)
                }
            )
        }
    }

    @ViewBuilder
    private func appContent(environment: AppRuntimeEnvironment) -> some View {
        if launchConfiguration.isScreenshotMode, let screenshotSeed = environment.screenshotSeed {
            ScreenshotRootView(
                appContainer: environment.appContainer,
                configuration: launchConfiguration,
                seed: screenshotSeed
            )
        } else {
            AppShellView(appContainer: environment.appContainer)
        }
    }
}
