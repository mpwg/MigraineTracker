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
    func disableSyncAndDeleteCloudData() async
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
    private let usageDataConsentService: UsageDataConsentService
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var restoreTask: Task<Void, Never>?
    @ObservationIgnored private var logRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var logClearTask: Task<Void, Never>?

    init(
        episodeRepository: EpisodeRepository,
        medicationRepository: MedicationCatalogRepository,
        syncService: SyncService,
        appLogService: AppLogService,
        healthService: HealthService,
        usageDataConsentService: UsageDataConsentService
    ) {
        self.episodeRepository = episodeRepository
        self.medicationRepository = medicationRepository
        self.syncService = syncService
        self.appLogService = appLogService
        self.healthService = healthService
        self.usageDataConsentService = usageDataConsentService
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

    var canOfferCloudDataDeletion: Bool {
        syncService.status.lastDownloadedAt != nil ||
            syncService.status.lastUploadedAt != nil ||
            !syncService.conflicts.isEmpty
    }

    var isCloudUnavailableForSyncDisableFlow: Bool {
        switch syncService.status.state {
        case .noICloudAccount, .offline, .needsAttention:
            return true
        case .disabled, .ready, .syncing, .conflict:
            return false
        }
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

    var isUsageDataCollectionAllowed: Bool {
        usageDataConsentService.usageDataConsent == .allowed
    }

    var syncStatusTitle: String {
        if !isSyncEnabled {
            return "Synchronisation deaktiviert"
        }

        if !syncService.conflicts.isEmpty {
            return "Konflikt vorhanden"
        }

        switch syncService.status.state {
        case .disabled:
            return "Synchronisation deaktiviert"
        case .ready:
            return "Synchronisiert"
        case .syncing:
            return "Wird synchronisiert …"
        case .needsAttention, .noICloudAccount, .offline:
            return "iCloud nicht verfügbar"
        case .conflict:
            return "Konflikt vorhanden"
        }
    }

    var syncStatusDetail: String {
        if !isSyncEnabled {
            return "Änderungen bleiben lokal auf diesem Gerät."
        }

        if syncService.status.queuedUpdates > 0 {
            return "\(syncService.status.queuedUpdates) Änderung\(syncService.status.queuedUpdates == 1 ? " wartet" : "en warten") auf Upload"
        }

        if !syncService.conflicts.isEmpty {
            return "\(syncService.conflicts.count) Konflikt\(syncService.conflicts.count == 1 ? "" : "e") warten auf deine Entscheidung"
        }

        guard let lastSyncDate else {
            return "Noch keine Daten synchronisiert"
        }

        return "Letzte Aktualisierung: \(relativeDateFormatter.localizedString(for: lastSyncDate, relativeTo: .now))"
    }

    var syncLogSubtitle: String {
        if let latest = logEntries.first {
            return "Letzter Eintrag: \(latest.timestamp.formatted(date: .abbreviated, time: .shortened))"
        }

        return "Letzter Eintrag: Noch kein Protokoll vorhanden"
    }

    var userFacingSyncErrorMessage: String? {
        guard let lastError = syncService.status.lastError?.trimmingCharacters(in: .whitespacesAndNewlines), !lastError.isEmpty else {
            return nil
        }

        if lastError.localizedCaseInsensitiveContains("Could not determine iCloud account status") {
            return "iCloud ist derzeit nicht verfügbar"
        }

        return "Die Synchronisation ist gerade nicht verfügbar. Bitte versuche es später erneut."
    }

    var isHealthConnected: Bool {
        let status = healthAuthorization
        return status.isAvailable && (status.isReadEnabled || status.isWriteEnabled)
    }

    var healthConnectionStatusTitle: String {
        isHealthConnected ? "Verbunden" : "Nicht verbunden"
    }

    var appVersionDisplay: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let cleanVersion = version?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBuild = build?.trimmingCharacters(in: .whitespacesAndNewlines)

        switch (cleanVersion?.isEmpty == false ? cleanVersion : nil, cleanBuild?.isEmpty == false ? cleanBuild : nil) {
        case let (version?, build?):
            return "\(version) (\(build))"
        case let (version?, nil):
            return version
        case let (nil, build?):
            return build
        case (nil, nil):
            return "Unbekannt"
        }
    }

    private var lastSyncDate: Date? {
        [syncService.status.lastUploadedAt, syncService.status.lastDownloadedAt]
            .compactMap { $0 }
            .max()
    }

    func load() {
        loadTask?.cancel()
        syncService.refreshStatus()

        let episodeRepository = episodeRepository
        let medicationRepository = medicationRepository
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let loadedSummary = try await loadSettingsUseCase.execute()
                let deleted = try await Task.detached(priority: .userInitiated) {
                    (
                        try episodeRepository.fetchDeleted(),
                        try medicationRepository.fetchDeletedDefinitions()
                    )
                }.value
                guard !Task.isCancelled else { return }
                summary = loadedSummary
                deletedEpisodes = deleted.0
                deletedDefinitions = deleted.1
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

    func disableSyncKeepingCloudData() {
        syncService.setSyncEnabled(false)
        load()
    }

    func disableSyncAndDeleteCloudData() async {
        await syncService.disableSyncAndDeleteCloudData()
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

    func requestHealthAuthorization() async {
        healthReadDefinitions.forEach { definition in
            healthService.setEnabled(true, for: definition.id, direction: .read)
        }
        healthWriteDefinitions.forEach { definition in
            healthService.setEnabled(true, for: definition.id, direction: .write)
        }
        try? await healthService.requestAuthorization()
        healthSettingsRevision += 1
    }

    func requestMissingHealthAuthorization() async {
        try? await healthService.requestMissingAuthorization()
        healthSettingsRevision += 1
    }

    func reloadHealthAuthorizationState() {
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

    func disconnectAppleHealthIntegration() {
        healthReadDefinitions.forEach { definition in
            healthService.setEnabled(false, for: definition.id, direction: .read)
        }
        healthWriteDefinitions.forEach { definition in
            healthService.setEnabled(false, for: definition.id, direction: .write)
        }
        healthSettingsRevision += 1
    }

    func setUsageDataCollectionAllowed(_ allowed: Bool) {
        usageDataConsentService.setUsageDataCollectionAllowed(allowed)
    }

    private var relativeDateFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }
}
