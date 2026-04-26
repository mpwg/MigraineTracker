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
    private(set) var continuousMedications: [ContinuousMedicationRecord] = []
    private(set) var logEntries: [AppLogEntry] = []
    private(set) var logShareURL: URL?
    private(set) var healthSettingsRevision = 0
    var logFilter: AppLogFilter = .all
    var continuousMedicationEditor: ContinuousMedicationDraft?
    var continuousMedicationMessage: String?

    private let episodeRepository: EpisodeRepository
    private let medicationRepository: MedicationCatalogRepository
    private let continuousMedicationRepository: ContinuousMedicationRepository
    private let loadSettingsUseCase: LoadSettingsUseCase
    private let restoreDeletedItemUseCase: RestoreDeletedItemUseCase
    private let syncService: SyncService
    private let appLogService: AppLogService
    private let healthService: HealthService
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var restoreTask: Task<Void, Never>?
    @ObservationIgnored private var logRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var logClearTask: Task<Void, Never>?

    init(
        episodeRepository: EpisodeRepository,
        medicationRepository: MedicationCatalogRepository,
        continuousMedicationRepository: ContinuousMedicationRepository,
        syncService: SyncService,
        appLogService: AppLogService,
        healthService: HealthService
    ) {
        self.episodeRepository = episodeRepository
        self.medicationRepository = medicationRepository
        self.continuousMedicationRepository = continuousMedicationRepository
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
        loadTask?.cancel()
        syncService.refreshStatus()

        let episodeRepository = episodeRepository
        let medicationRepository = medicationRepository
        let continuousMedicationRepository = continuousMedicationRepository
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let loadedSummary = try await loadSettingsUseCase.execute()
                let deleted = try await Task.detached(priority: .userInitiated) {
                    (
                        try episodeRepository.fetchDeleted(),
                        try medicationRepository.fetchDeletedDefinitions(),
                        try continuousMedicationRepository.fetchAll()
                    )
                }.value
                guard !Task.isCancelled else { return }
                summary = loadedSummary
                deletedEpisodes = deleted.0
                deletedDefinitions = deleted.1
                continuousMedications = deleted.2
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
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
        restoreTask?.cancel()
        restoreTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await restoreDeletedItemUseCase.restoreEpisode(id: id)
            } catch is CancellationError {
                return
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            load()
        }
    }

    func restoreMedicationDefinition(_ definition: MedicationDefinitionRecord) {
        restoreTask?.cancel()
        restoreTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await restoreDeletedItemUseCase.restoreMedicationDefinition(definition)
            } catch is CancellationError {
                return
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            load()
        }
    }

    func presentContinuousMedicationEditor(for medication: ContinuousMedicationRecord?) {
        continuousMedicationEditor = medication.map(ContinuousMedicationDraft.init(record:)) ?? ContinuousMedicationDraft()
        continuousMedicationMessage = nil
    }

    func saveContinuousMedication(_ draft: ContinuousMedicationDraft) async {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            continuousMedicationMessage = "Bitte gib ein Medikament an."
            return
        }

        let repository = continuousMedicationRepository
        var normalizedDraft = draft
        normalizedDraft.name = trimmedName

        do {
            _ = try await Task.detached(priority: .userInitiated) {
                try repository.save(normalizedDraft)
            }.value
            continuousMedicationEditor = nil
            continuousMedicationMessage = nil
            load()
        } catch {
            continuousMedicationMessage = "Dauermedikation konnte nicht gespeichert werden."
        }
    }

    func endContinuousMedication(id: UUID) {
        let repository = continuousMedicationRepository
        Task { [weak self] in
            guard let self else { return }
            guard let medication = continuousMedications.first(where: { $0.id == id }) else { return }
            var draft = ContinuousMedicationDraft(record: medication)
            draft.endDate = .now

            do {
                _ = try await Task.detached(priority: .userInitiated) {
                    try repository.save(draft)
                }.value
                load()
            } catch {
                continuousMedicationMessage = "Dauermedikation konnte nicht beendet werden."
            }
        }
    }

    func refreshLog(limit: Int = 200) {
        logRefreshTask?.cancel()
        logRefreshTask = Task { [weak self] in
            guard let self else { return }
            let entries = await appLogService.recentEntries(filter: logFilter, limit: limit)
            let shareURL = await appLogService.exportLogFileURL(filter: logFilter)
            guard !Task.isCancelled else { return }
            logEntries = entries
            logShareURL = shareURL
        }
    }

    func clearLog() {
        logClearTask?.cancel()
        logRefreshTask?.cancel()
        logClearTask = Task { [weak self] in
            guard let self else { return }
            await appLogService.clear()
            guard !Task.isCancelled else { return }
            logEntries = []
            logShareURL = nil
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
