import SwiftUI
import SwiftData

@main
struct MigraineTrackerApp: App {
    private let modelContainer: ModelContainer
    @StateObject private var syncCoordinator: SyncCoordinator

    init() {
        let schema = Schema([
            Episode.self,
            MedicationEntry.self,
            MedicationDefinition.self,
            WeatherSnapshot.self,
        ])

        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            MedicationCatalog.importSeedDataIfNeeded(into: container)
            self.modelContainer = container
            _syncCoordinator = StateObject(wrappedValue: SyncCoordinator(modelContainer: container))
        } catch {
            fatalError("ModelContainer konnte nicht erstellt werden: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .environmentObject(syncCoordinator)
        }
        .modelContainer(modelContainer)
    }
}
