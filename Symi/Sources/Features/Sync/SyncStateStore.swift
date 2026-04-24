import CloudKit
import Foundation

enum SyncConfiguration {
    static let containerIdentifier = "iCloud.eu.mpwg.MigraineTracker"
    static let zoneName = "MigraineTrackerSync"
    static let subscriptionID = "MigraineTrackerSyncSubscription"
    static let recordType = "SyncDocument"

    static let zoneID = CKRecordZone.ID(
        zoneName: zoneName,
        ownerName: CKCurrentUserDefaultName
    )
}

actor SyncStateStore {
    private struct PersistedSyncState: Codable {
        var syncEnabled = false
        var engineStateData: Data?
        var shadows: [String: SyncShadow] = [:]
        var conflicts: [String: SyncConflict] = [:]
        var lastUploadedAt: Date?
        var lastDownloadedAt: Date?
        var lastError: String?
    }

    private let url: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var state: PersistedSyncState

    init(fileManager: FileManager = .default) {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601

        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directory = baseURL.appendingPathComponent("Symi", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        self.url = directory.appendingPathComponent("sync-state.json")

        if
            let data = try? Data(contentsOf: url),
            let persisted = try? decoder.decode(PersistedSyncState.self, from: data)
        {
            self.state = persisted
        } else {
            self.state = PersistedSyncState()
        }
    }

    func syncEnabled() -> Bool {
        state.syncEnabled
    }

    func setSyncEnabled(_ enabled: Bool) {
        state.syncEnabled = enabled
        persist()
    }

    func engineState() -> CKSyncEngine.State.Serialization? {
        guard let data = state.engineStateData else {
            return nil
        }

        return try? decoder.decode(CKSyncEngine.State.Serialization.self, from: data)
    }

    func saveEngineState(_ serialization: CKSyncEngine.State.Serialization) {
        state.engineStateData = try? encoder.encode(serialization)
        persist()
    }

    func shadows() -> [String: SyncShadow] {
        state.shadows
    }

    func shadow(for documentID: String) -> SyncShadow? {
        state.shadows[documentID]
    }

    func saveShadow(_ shadow: SyncShadow, for documentID: String) {
        state.shadows[documentID] = shadow
        persist()
    }

    func removeShadow(documentID: String) {
        state.shadows.removeValue(forKey: documentID)
        persist()
    }

    func conflicts() -> [SyncConflict] {
        state.conflicts.values.sorted { $0.detectedAt > $1.detectedAt }
    }

    func saveConflict(_ conflict: SyncConflict) {
        state.conflicts[conflict.documentID] = conflict
        persist()
    }

    func removeConflict(documentID: String) {
        state.conflicts.removeValue(forKey: documentID)
        persist()
    }

    func lastUploadedAt() -> Date? {
        state.lastUploadedAt
    }

    func setLastUploadedAt(_ date: Date?) {
        state.lastUploadedAt = date
        persist()
    }

    func lastDownloadedAt() -> Date? {
        state.lastDownloadedAt
    }

    func setLastDownloadedAt(_ date: Date?) {
        state.lastDownloadedAt = date
        persist()
    }

    func lastError() -> String? {
        state.lastError
    }

    func setLastError(_ error: String?) {
        state.lastError = error
        persist()
    }

    func clearLastError() {
        state.lastError = nil
        persist()
    }

    private func persist() {
        guard let data = try? encoder.encode(state) else {
            return
        }

        try? data.write(to: url, options: .atomic)
    }
}
