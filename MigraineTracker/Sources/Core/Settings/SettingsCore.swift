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

    func execute() throws -> SettingsSummaryData {
        let recent = try episodeRepository.fetchRecent()
        let deletedEpisodes = try episodeRepository.fetchDeleted()
        let deletedDefinitions = try medicationRepository.fetchDeletedDefinitions()

        return SettingsSummaryData(
            activeEpisodeCount: recent.count,
            trashCount: deletedEpisodes.count + deletedDefinitions.count,
            conflictCount: syncService.conflicts.count
        )
    }
}

struct RestoreDeletedItemUseCase {
    let episodeRepository: EpisodeRepository
    let medicationRepository: MedicationCatalogRepository

    func restoreEpisode(id: UUID) throws {
        try episodeRepository.restore(id: id)
    }

    func restoreMedicationDefinition(_ definition: MedicationDefinitionRecord) throws {
        _ = try medicationRepository.saveCustomDefinition(
            CustomMedicationDefinitionDraft(
                id: definition.catalogKey,
                originalSelectionKey: definition.selectionKey,
                name: definition.name,
                category: definition.category,
                dosage: definition.suggestedDosage
            )
        )
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
    var logFilter: AppLogFilter = .all

    private let episodeRepository: EpisodeRepository
    private let medicationRepository: MedicationCatalogRepository
    private let loadSettingsUseCase: LoadSettingsUseCase
    private let restoreDeletedItemUseCase: RestoreDeletedItemUseCase
    private let syncService: SyncService
    private let appLogService: AppLogService

    init(
        episodeRepository: EpisodeRepository,
        medicationRepository: MedicationCatalogRepository,
        syncService: SyncService,
        appLogService: AppLogService
    ) {
        self.episodeRepository = episodeRepository
        self.medicationRepository = medicationRepository
        self.syncService = syncService
        self.appLogService = appLogService
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

    func load() {
        syncService.refreshStatus()

        do {
            summary = try loadSettingsUseCase.execute()
            deletedEpisodes = try episodeRepository.fetchDeleted()
            deletedDefinitions = try medicationRepository.fetchDeletedDefinitions()
        } catch {
            summary = SettingsSummaryData(
                activeEpisodeCount: 0,
                trashCount: deletedEpisodes.count + deletedDefinitions.count,
                conflictCount: syncService.conflicts.count
            )
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
        try? restoreDeletedItemUseCase.restoreEpisode(id: id)
        load()
    }

    func restoreMedicationDefinition(_ definition: MedicationDefinitionRecord) {
        try? restoreDeletedItemUseCase.restoreMedicationDefinition(definition)
        load()
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
}
