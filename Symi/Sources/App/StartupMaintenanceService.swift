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
                try? Self.normalizePersistentEnumValues(in: modelContainer)
                MedicationCatalog.importSeedDataIfNeeded(into: modelContainer)
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

    nonisolated static func normalizePersistentEnumValues(in modelContainer: ModelContainer) throws {
        let context = ModelContext(modelContainer)
        var didChange = false

        let episodes = try context.fetch(FetchDescriptor<Episode>())
        for episode in episodes {
            let normalizedType = EpisodeType(storageValue: episode.typeRaw).rawValue
            if episode.typeRaw != normalizedType {
                episode.typeRaw = normalizedType
                didChange = true
            }

            let normalizedMenstruationStatus = MenstruationStatus(storageValue: episode.menstruationStatusRaw).rawValue
            if episode.menstruationStatusRaw != normalizedMenstruationStatus {
                episode.menstruationStatusRaw = normalizedMenstruationStatus
                didChange = true
            }

            for medication in episode.medications {
                let normalizedCategory = MedicationCategory(storageValue: medication.categoryRaw).rawValue
                if medication.categoryRaw != normalizedCategory {
                    medication.categoryRaw = normalizedCategory
                    didChange = true
                }

                let normalizedEffectiveness = MedicationEffectiveness(storageValue: medication.effectivenessRaw).rawValue
                if medication.effectivenessRaw != normalizedEffectiveness {
                    medication.effectivenessRaw = normalizedEffectiveness
                    didChange = true
                }
            }
        }

        let definitions = try context.fetch(FetchDescriptor<MedicationDefinition>())
        for definition in definitions {
            let normalizedCategory = MedicationCategory(storageValue: definition.categoryRaw).rawValue
            if definition.categoryRaw != normalizedCategory {
                definition.categoryRaw = normalizedCategory
                didChange = true
            }
        }

        if didChange {
            try context.save()
        }
    }
}
