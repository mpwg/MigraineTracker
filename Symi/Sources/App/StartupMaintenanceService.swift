import Foundation
import SwiftData

@MainActor
final class StartupMaintenanceService {
    private static let seedImportDelay: Duration = .milliseconds(500)
    private static let weatherBackfillDelay: Duration = .seconds(4)

    private let modelContainer: ModelContainer
    private let weatherBackfillService: WeatherBackfillService
    private var maintenanceTask: Task<Void, Never>?

    init(modelContainer: ModelContainer, weatherBackfillService: WeatherBackfillService) {
        self.modelContainer = modelContainer
        self.weatherBackfillService = weatherBackfillService
    }

    func startIfNeeded() {
        guard maintenanceTask == nil else {
            return
        }

        let modelContainer = modelContainer
        let weatherBackfillService = weatherBackfillService

        maintenanceTask = Task(priority: .background) {
            try? await Task.sleep(for: Self.seedImportDelay)
            guard !Task.isCancelled else {
                return
            }

            await Task.detached(priority: .utility) {
                MedicationCatalog.importSeedDataIfNeeded(into: modelContainer)
                DoctorDirectoryCatalog.importSeedDataIfNeeded(into: modelContainer)
            }.value

            try? await Task.sleep(for: Self.weatherBackfillDelay - Self.seedImportDelay)
            guard !Task.isCancelled else {
                return
            }

            await weatherBackfillService.runIfNeeded()
        }
    }

    deinit {
        maintenanceTask?.cancel()
    }
}
