import SwiftUI
import SwiftData
import CoreData
import OSLog

@main
struct MigraineTrackerApp: App {
    private static let logger = Logger(subsystem: "MigraineTracker", category: "Persistence")
    private let modelContainer: ModelContainer
    private let appLogStore: AppLogStore
    @State private var syncCoordinator: SyncCoordinator
    @State private var appLogViewModel: AppLogViewModel

    init() {
        let schema = Schema(versionedSchema: MigraineTrackerSchemaV2.self)
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
            _syncCoordinator = State(initialValue: SyncCoordinator(modelContainer: container, appLogStore: appLogStore))
            _appLogViewModel = State(initialValue: AppLogViewModel(store: appLogStore))
        } catch {
            fatalError("ModelContainer konnte nicht erstellt werden: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .environment(syncCoordinator)
                .environment(appLogViewModel)
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

    private static func resetPersistentStore(at url: URL) throws {
        let directoryURL = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: NSManagedObjectModel())
        logger.notice("Zerstöre Persistent Store unter \(url.path, privacy: .public)")
        try coordinator.destroyPersistentStore(at: url, type: .sqlite)
        logger.notice("Persistent Store unter \(url.path, privacy: .public) wurde per Core Data API zerstört.")
    }
}
