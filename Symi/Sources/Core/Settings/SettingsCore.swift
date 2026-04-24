import Foundation
import Observation

struct SettingsSummaryData: Equatable {
    let activeEpisodeCount: Int
    let trashCount: Int
    let conflictCount: Int
}

struct TrashedMedicationDefinitionItem: Identifiable, Equatable {
    let id: String
    let name: String
    let category: MedicationCategory
}

struct LoadSettingsUseCase {
    let episodeRepository: EpisodeRepository
    let medicationRepository: MedicationCatalogRepository
    let syncService: SyncService

    func execute() async throws -> SettingsSummaryData {
        let episodeRepository = episodeRepository
        let medicationRepository = medicationRepository
        let result = try await Task.detached(priority: .userInitiated) {
            let recent = try episodeRepository.fetchRecent()
            let deletedEpisodes = try episodeRepository.fetchDeleted()
            let deletedDefinitions = try medicationRepository.fetchDeletedDefinitions()
            return (recent.count, deletedEpisodes.count + deletedDefinitions.count)
        }.value

        return SettingsSummaryData(
            activeEpisodeCount: result.0,
            trashCount: result.1,
            conflictCount: syncService.conflicts.count
        )
    }
}

struct RestoreDeletedItemUseCase {
    let episodeRepository: EpisodeRepository
    let medicationRepository: MedicationCatalogRepository

    func restoreEpisode(id: UUID) async throws {
        let episodeRepository = episodeRepository
        try await Task.detached(priority: .userInitiated) {
            try episodeRepository.restore(id: id)
        }.value
    }

    func restoreMedicationDefinition(_ definition: MedicationDefinitionRecord) async throws {
        let medicationRepository = medicationRepository
        let draft = CustomMedicationDefinitionDraft(
            id: definition.catalogKey,
            originalSelectionKey: definition.selectionKey,
            name: definition.name,
            category: definition.category,
            dosage: definition.suggestedDosage
        )
        _ = try await Task.detached(priority: .userInitiated) {
            try medicationRepository.saveCustomDefinition(draft)
        }.value
    }
}

protocol SyncService: AnyObject {
    var isEnabled: Bool { get }
    var status: SyncStatusSnapshot { get }
    var conflicts: [SyncConflict] { get }

    func setSyncEnabled(_ enabled: Bool)
    func refreshStatus()
    func syncNow() async
    func retryLastError() async
    func resolveConflictKeepingLocal(_ conflict: SyncConflict) async
    func resolveConflictUsingRemote(_ conflict: SyncConflict) async
}

protocol AppLogService {
    func recentEntries(filter: AppLogFilter, limit: Int) async -> [AppLogEntry]
    func exportLogFileURL(filter: AppLogFilter) async -> URL?
    func clear() async
}

@MainActor
@Observable
final class SettingsController {
    private(set) var summary = SettingsSummaryData(activeEpisodeCount: 0, trashCount: 0, conflictCount: 0)
    private(set) var deletedEpisodes: [EpisodeRecord] = []
    private(set) var deletedDefinitions: [MedicationDefinitionRecord] = []
    private(set) var logEntries: [AppLogEntry] = []
    private(set) var logShareURL: URL?
    private(set) var healthSettingsRevision = 0
    var logFilter: AppLogFilter = .all

    private let episodeRepository: EpisodeRepository
    private let medicationRepository: MedicationCatalogRepository
    private let loadSettingsUseCase: LoadSettingsUseCase
    private let restoreDeletedItemUseCase: RestoreDeletedItemUseCase
    private let syncService: SyncService
    private let appLogService: AppLogService
    private let healthService: HealthService

    init(
        episodeRepository: EpisodeRepository,
        medicationRepository: MedicationCatalogRepository,
        syncService: SyncService,
        appLogService: AppLogService,
        healthService: HealthService
    ) {
        self.episodeRepository = episodeRepository
        self.medicationRepository = medicationRepository
        self.syncService = syncService
        self.appLogService = appLogService
        self.healthService = healthService
        self.loadSettingsUseCase = LoadSettingsUseCase(
            episodeRepository: episodeRepository,
            medicationRepository: medicationRepository,
            syncService: syncService
        )
        self.restoreDeletedItemUseCase = RestoreDeletedItemUseCase(
            episodeRepository: episodeRepository,
            medicationRepository: medicationRepository
        )
    }

    var syncStatus: SyncStatusSnapshot {
        syncService.status
    }

    var isSyncEnabled: Bool {
        syncService.isEnabled
    }

    var conflicts: [SyncConflict] {
        syncService.conflicts
    }

    var healthAuthorization: HealthAuthorizationSnapshot {
        healthService.authorizationSnapshot()
    }

    var healthReadDefinitions: [HealthDataTypeDefinition] {
        healthService.readDefinitions
    }

    var healthWriteDefinitions: [HealthDataTypeDefinition] {
        healthService.writeDefinitions
    }

    func load() {
        syncService.refreshStatus()

        let episodeRepository = episodeRepository
        let medicationRepository = medicationRepository
        Task {
            do {
                summary = try await loadSettingsUseCase.execute()
                let deleted = try await Task.detached(priority: .userInitiated) {
                    (
                        try episodeRepository.fetchDeleted(),
                        try medicationRepository.fetchDeletedDefinitions()
                    )
                }.value
                deletedEpisodes = deleted.0
                deletedDefinitions = deleted.1
            } catch {
                summary = SettingsSummaryData(
                    activeEpisodeCount: 0,
                    trashCount: deletedEpisodes.count + deletedDefinitions.count,
                    conflictCount: syncService.conflicts.count
                )
            }
        }
    }

    func setSyncEnabled(_ enabled: Bool) {
        syncService.setSyncEnabled(enabled)
        load()
    }

    func syncNow() async {
        await syncService.syncNow()
        load()
    }

    func retryLastError() async {
        await syncService.retryLastError()
        load()
    }

    func resolveConflictKeepingLocal(_ conflict: SyncConflict) async {
        await syncService.resolveConflictKeepingLocal(conflict)
        load()
    }

    func resolveConflictUsingRemote(_ conflict: SyncConflict) async {
        await syncService.resolveConflictUsingRemote(conflict)
        load()
    }

    func restoreEpisode(id: UUID) {
        Task {
            try? await restoreDeletedItemUseCase.restoreEpisode(id: id)
            load()
        }
    }

    func restoreMedicationDefinition(_ definition: MedicationDefinitionRecord) {
        Task {
            try? await restoreDeletedItemUseCase.restoreMedicationDefinition(definition)
            load()
        }
    }

    func refreshLog(limit: Int = 200) {
        Task {
            let entries = await appLogService.recentEntries(filter: logFilter, limit: limit)
            let shareURL = await appLogService.exportLogFileURL(filter: logFilter)
            await MainActor.run {
                self.logEntries = entries
                self.logShareURL = shareURL
            }
        }
    }

    func clearLog() {
        Task {
            await appLogService.clear()
            await MainActor.run {
                self.logEntries = []
                self.logShareURL = nil
            }
        }
    }

    func setHealthDataTypeEnabled(_ enabled: Bool, type: HealthDataTypeID, direction: HealthDataDirection) {
        healthService.setEnabled(enabled, for: type, direction: direction)
        healthSettingsRevision += 1
    }

    func requestHealthReadAuthorization() async {
        try? await healthService.requestReadAuthorization()
        healthSettingsRevision += 1
    }

    func requestHealthWriteAuthorization() async {
        try? await healthService.requestWriteAuthorization()
        healthSettingsRevision += 1
    }
}
