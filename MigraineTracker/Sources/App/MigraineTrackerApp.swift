import SwiftUI
import Sentry
import TelemetryDeck

import SwiftData
import CoreData
import OSLog

@main
struct MigraineTrackerApp: App {
    private static let logger = Logger(subsystem: "MigraineTracker", category: "Persistence")
    private let modelContainer: ModelContainer
    private let appContainer: AppContainer
    private let appLogStore: AppLogStore
    @State private var syncCoordinator: SyncCoordinator

    init() {
        if let sentryDSN = Self.sentryDSN {
            SentrySDK.start { options in
                options.dsn = sentryDSN

                // Adds IP for users.
                // For more information, visit: https://docs.sentry.io/platforms/apple/data-management/data-collected/
                options.sendDefaultPii = true

                // Set tracesSampleRate to 1.0 to capture 100% of transactions for performance monitoring.
                // We recommend adjusting this value in production.
                options.tracesSampleRate = 1.0

                // Configure profiling. Visit https://docs.sentry.io/platforms/apple/profiling/ to learn more.
                options.configureProfiling = {
                    $0.sessionSampleRate = 1.0 // We recommend adjusting this value in production.
                    $0.lifecycle = .trace
                }

                // Uncomment the following lines to add more data to your events
                options.attachScreenshot = true // This adds a screenshot to the error events
                options.attachViewHierarchy = true // This adds the view hierarchy to the error events
                options.debug = true
                options.enableLogs = true
            }
        } else {
            Self.logger.notice("Sentry ist deaktiviert, weil keine gültige DSN in der App-Konfiguration gefunden wurde.")
        }
        if let telemetryAppID = Self.telemetryAppID {
            TelemetryDeck.initialize(config: .init(appID: telemetryAppID))
        }
        let schema = Schema(versionedSchema: MigraineTrackerSchemaV3.self)
        let storeURL = Self.defaultStoreURL()

        let configuration = ModelConfiguration(
            "default",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )

        do {
            let container = try Self.makeContainer(schema: schema, configuration: configuration)
            MedicationCatalog.importSeedDataIfNeeded(into: container)
            self.modelContainer = container
            let appLogStore = AppLogStore()
            self.appLogStore = appLogStore
            let syncCoordinator = SyncCoordinator(modelContainer: container, appLogStore: appLogStore)
            _syncCoordinator = State(initialValue: syncCoordinator)
            self.appContainer = AppContainer(
                modelContainer: container,
                syncCoordinator: syncCoordinator,
                appLogStore: appLogStore
            )
        } catch {
            fatalError("ModelContainer konnte nicht erstellt werden: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppShellView(appContainer: appContainer)
        }
        .modelContainer(modelContainer)
    }

    private static func makeContainer(schema: Schema, configuration: ModelConfiguration) throws -> ModelContainer {
        do {
            logger.debug("Versuche ModelContainer für Store unter \(configuration.url.path, privacy: .public) zu laden.")
            return try ModelContainer(
                for: schema,
                migrationPlan: MigraineTrackerMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            let errorDescription = String(describing: error)
            logger.error("Erster Ladeversuch des ModelContainer fehlgeschlagen: \(errorDescription, privacy: .public)")

            guard isUnknownModelVersionError(error) else {
                logger.error("Fehler wurde nicht als Reset-Fall erkannt. Beschreibung: \(errorDescription, privacy: .public)")
                throw error
            }

            logger.warning("Unbekannte Modellversion erkannt. SwiftData-Store wird vollständig zurückgesetzt: \(configuration.url.path, privacy: .public)")
            try resetPersistentStore(at: configuration.url)
            logger.notice("SwiftData-Store wurde zurückgesetzt. Erneuter Aufbau des ModelContainer startet.")

            return try ModelContainer(
                for: schema,
                migrationPlan: MigraineTrackerMigrationPlan.self,
                configurations: [configuration]
            )
        }
    }

    private static func isUnknownModelVersionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        let description = String(describing: error).lowercased()
        let localizedDescription = nsError.localizedDescription.lowercased()

        if nsError.domain == NSCocoaErrorDomain && nsError.code == 134504 {
            return true
        }

        if description.contains("loadissuemodelcontainer") {
            return true
        }

        if description.contains("unknown model version") || localizedDescription.contains("unknown model version") {
            return true
        }

        if description.contains("134504") || localizedDescription.contains("134504") {
            return true
        }

        return false
    }

    private static func defaultStoreURL() -> URL {
        let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return applicationSupportURL.appending(path: "default.store")
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

    private static func resetPersistentStore(at url: URL) throws {
        let directoryURL = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: NSManagedObjectModel())
        logger.notice("Zerstöre Persistent Store unter \(url.path, privacy: .public)")
        try coordinator.destroyPersistentStore(at: url, type: .sqlite)
        logger.notice("Persistent Store unter \(url.path, privacy: .public) wurde per Core Data API zerstört.")
    }
}
