import SwiftUI
import SwiftData
import OSLog
import Sentry
import TelemetryDeck

@main
struct SymiApp: App {
    private static let logger = Logger(subsystem: "Symi", category: "Persistence")
    private let launchConfiguration: AppLaunchConfiguration
    private let initialStartupState: AppStartupState
    @State private var telemetryService = AppTelemetryService.shared

    init() {
        let launchConfiguration = AppLaunchConfiguration.current
        self.launchConfiguration = launchConfiguration

        self.initialStartupState = Self.makeInitialStartupState(launchConfiguration: launchConfiguration)
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(
                launchConfiguration: launchConfiguration,
                initialStartupState: initialStartupState,
                telemetryService: telemetryService
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
            let container = try loadContainer()
            try protectPersistentStoreFiles(at: configuration.url)
            return container
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
        let schema = Schema(versionedSchema: SymiSchemaV9.self)
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
        let appLogStore = AppLogStore(remoteReporter: AppTelemetryGateway.sentryLogReporter)
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
            healthContextStore: healthContextStore,
            featureFlags: launchConfiguration.featureFlags
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
            #if DEBUG
            if launchConfiguration.isScreenshotMode {
                let environment = try ScreenshotBootstrap.makeEnvironment(seedName: launchConfiguration.screenshotSeedName)
                return .app(
                    AppRuntimeEnvironment(
                        modelContainer: environment.modelContainer,
                        appContainer: environment.appContainer,
                        appLogStore: environment.appLogStore,
                        syncCoordinator: environment.syncCoordinator,
                        screenshotSeed: environment.seed
                    )
                )
            }
            #endif

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
        let schema = Schema(versionedSchema: SymiSchemaV9.self)
        let configuration = ModelConfiguration(
            "recovery",
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )

        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func defaultStoreURL(
        applicationSupportDirectoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> URL {
        guard let applicationSupportURL = applicationSupportDirectoryURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw AppStartupPreparationError.applicationSupportDirectoryUnavailable
        }

        try fileManager.createDirectory(at: applicationSupportURL, withIntermediateDirectories: true)
        try ProtectedFileStorage.applyProtection(to: applicationSupportURL, fileManager: fileManager)
        return applicationSupportURL.appending(path: "default.store")
    }

    static func protectPersistentStoreFiles(at storeURL: URL, fileManager: FileManager = .default) throws {
        try ProtectedFileStorage.applyProtection(to: storeURL.deletingLastPathComponent(), fileManager: fileManager)
        for fileURL in PersistentStoreRecoveryService.storeFileCandidates(for: storeURL) where fileManager.fileExists(atPath: fileURL.path) {
            if fileURL.hasDirectoryPath {
                try ProtectedFileStorage.applyProtectionRecursively(to: fileURL, fileManager: fileManager)
            } else {
                try ProtectedFileStorage.applyProtection(to: fileURL, fileManager: fileManager)
            }
        }
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
    @Bindable var telemetryService: AppTelemetryService
    @State private var startupState: AppStartupState
    @State private var isUsageDataConsentPromptPresented = false

    init(
        launchConfiguration: AppLaunchConfiguration,
        initialStartupState: AppStartupState,
        telemetryService: AppTelemetryService
    ) {
        self.launchConfiguration = launchConfiguration
        self.telemetryService = telemetryService
        _startupState = State(initialValue: initialStartupState)
    }

    var body: some View {
        rootContent
            .task {
                telemetryService.configureIfPermitted(launchConfiguration: launchConfiguration)
                presentUsageDataConsentPromptIfNeeded()
            }
            .sheet(
                isPresented: $isUsageDataConsentPromptPresented,
                onDismiss: {
                    if telemetryService.shouldAskForUsageDataConsent {
                        telemetryService.setUsageDataCollectionAllowed(false)
                    }
                },
                content: {
                DataSharingSheet {
                    telemetryService.setUsageDataCollectionAllowed(true)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                }
            )
    }

    @ViewBuilder
    private var rootContent: some View {
        switch startupState {
        case .app(let environment):
            appContent(environment: environment)
                .modelContainer(environment.modelContainer)
                .environment(\.featureFlags, environment.appContainer.featureFlags)
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
                    presentUsageDataConsentPromptIfNeeded()
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
                    presentUsageDataConsentPromptIfNeeded()
                }
            )
        }
    }

    @ViewBuilder
    private func appContent(environment: AppRuntimeEnvironment) -> some View {
        #if DEBUG
        if launchConfiguration.isScreenshotMode, let screenshotSeed = environment.screenshotSeed {
            ScreenshotRootView(
                appContainer: environment.appContainer,
                configuration: launchConfiguration,
                seed: screenshotSeed
            )
        } else {
            AppShellView(appContainer: environment.appContainer)
        }
        #else
        AppShellView(appContainer: environment.appContainer)
        #endif
    }

    private func presentUsageDataConsentPromptIfNeeded() {
        guard !launchConfiguration.isScreenshotMode, !launchConfiguration.isRunningTests else {
            return
        }

        guard case .app = startupState, telemetryService.shouldAskForUsageDataConsent else {
            return
        }

        isUsageDataConsentPromptPresented = true
    }
}

@MainActor
enum AppTelemetryGateway {
    static let sentryLogReporter = AppSentryLogReporter(client: SentrySDKLogClient())

    static func startSentry(dsn: String) {
        SentrySDK.start { options in
            options.dsn = dsn

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
    }

    static func stopSentry() {
        SentrySDK.close()
    }

    static func setSentryLogReportingEnabled(_ enabled: Bool) {
        sentryLogReporter.setEnabled(enabled)
    }

    static func startTelemetryDeck(appID: String) {
        TelemetryDeck.initialize(config: .init(appID: appID))
    }

    static func stopTelemetryDeck() {
        TelemetryDeck.terminate()
    }
}

private struct SentrySDKLogClient: AppSentryClient {
    func addBreadcrumb(_ breadcrumb: AppRemoteLogBreadcrumb) {
        let sentryBreadcrumb = Breadcrumb(level: breadcrumb.level.sentryLevel, category: breadcrumb.category)
        sentryBreadcrumb.message = breadcrumb.message
        sentryBreadcrumb.type = "log"
        sentryBreadcrumb.data = breadcrumb.data
        SentrySDK.addBreadcrumb(sentryBreadcrumb)
    }

    func captureEvent(_ event: AppRemoteLogEvent) {
        let sentryEvent = Event(level: event.level.sentryLevel)
        sentryEvent.message = SentryMessage(formatted: event.message)
        sentryEvent.logger = "Symi.AppLog"
        sentryEvent.extra = event.extra
        SentrySDK.capture(event: sentryEvent)
    }
}

private extension AppRemoteLogLevel {
    var sentryLevel: SentryLevel {
        switch self {
        case .debug:
            .debug
        case .info:
            .info
        case .warning:
            .warning
        case .error:
            .error
        case .fatal:
            .fatal
        }
    }
}
