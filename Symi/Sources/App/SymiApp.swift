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
        .defaultSize(width: 1280, height: 800)
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
        storeURL overrideStoreURL: URL? = nil
    ) throws -> AppRuntimeEnvironment {
        let schema = Schema(versionedSchema: SymiSchemaV5.self)
        let storeURL = overrideStoreURL ?? (launchConfiguration.isRunningTests ? unitTestStoreURL() : defaultStoreURL())
        let configuration = ModelConfiguration(
            "default",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )

        let container = try makeContainer(schema: schema, configuration: configuration)
        let appLogStore = AppLogStore()
        let syncCoordinator = SyncCoordinator(
            modelContainer: container,
            appLogStore: appLogStore,
            autostart: !launchConfiguration.isRunningTests
        )
        let appContainer = AppContainer(
            modelContainer: container,
            syncCoordinator: syncCoordinator,
            appLogStore: appLogStore
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
    private static func makeInitialStartupState(launchConfiguration: AppLaunchConfiguration) -> AppStartupState {
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
                fatalError("Recovery-Container konnte nicht erstellt werden: \(error)")
            }
        } catch {
            fatalError("App-Start konnte nicht vorbereitet werden: \(error)")
        }
    }

    @MainActor
    private static func makeRecoveryContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SymiSchemaV5.self)
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

    private static func defaultStoreURL() -> URL {
        let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return applicationSupportURL.appending(path: "default.store")
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
}

@MainActor
enum AppStartupState {
    case app(AppRuntimeEnvironment)
    case recovery(StoreRecoveryEnvironment)
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
