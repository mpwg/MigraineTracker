import CloudKit
import Foundation

enum SyncConfiguration {
    static let containerIdentifier = "iCloud.eu.mpwg.MigraineTracker"
    static let zoneName = "MigraineTrackerSync"
    static let recordType = "SyncDocument"

    static let zoneID = CKRecordZone.ID(
        zoneName: zoneName,
        ownerName: CKCurrentUserDefaultName
    )
}

actor SyncStateStore {
    private struct PersistedSyncState: Codable {
        static let currentSchemaVersion = 1

        var schemaVersion = currentSchemaVersion
        var syncEnabled = false
        var engineStateData: Data?
        var shadows: [String: SyncShadow] = [:]
        var conflicts: [String: SyncConflict] = [:]
        var lastUploadedAt: Date?
        var lastDownloadedAt: Date?
        var lastError: String?
        var lastErrorIsRetryable = false

        private enum CodingKeys: String, CodingKey {
            case schemaVersion
            case syncEnabled
            case engineStateData
            case shadows
            case conflicts
            case lastUploadedAt
            case lastDownloadedAt
            case lastError
            case lastErrorIsRetryable
        }

        init() {}

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion

            guard schemaVersion == Self.currentSchemaVersion else {
                throw DecodingError.dataCorruptedError(
                    forKey: .schemaVersion,
                    in: container,
                    debugDescription: "Nicht unterstützte Sync-State-Schema-Version \(schemaVersion)."
                )
            }

            self.schemaVersion = schemaVersion
            self.syncEnabled = try container.decodeIfPresent(Bool.self, forKey: .syncEnabled) ?? false
            self.engineStateData = try container.decodeIfPresent(Data.self, forKey: .engineStateData)
            self.shadows = try container.decodeIfPresent([String: SyncShadow].self, forKey: .shadows) ?? [:]
            self.conflicts = try container.decodeIfPresent([String: SyncConflict].self, forKey: .conflicts) ?? [:]
            self.lastUploadedAt = try container.decodeIfPresent(Date.self, forKey: .lastUploadedAt)
            self.lastDownloadedAt = try container.decodeIfPresent(Date.self, forKey: .lastDownloadedAt)
            self.lastError = try container.decodeIfPresent(String.self, forKey: .lastError)
            self.lastErrorIsRetryable = try container.decodeIfPresent(Bool.self, forKey: .lastErrorIsRetryable) ?? false
        }
    }

    struct PersistenceEvent: Sendable {
        let level: AppLogLevel
        let operation: String
        let message: String
        let metadata: [String: String]
    }

    private let url: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var state: PersistedSyncState
    private var persistenceEvents: [PersistenceEvent]

    init(fileManager: FileManager = .default, baseDirectoryURL: URL? = nil) {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601

        let baseURL = baseDirectoryURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directory = baseURL.appendingPathComponent("Symi", isDirectory: true)
        self.url = directory.appendingPathComponent("sync-state.json")

        var initialState = PersistedSyncState()
        var initialEvents: [PersistenceEvent] = []

        do {
            try ProtectedFileStorage.createProtectedDirectory(at: directory, fileManager: fileManager)
        } catch {
            let message = "Sync-State-Verzeichnis konnte nicht erstellt werden: \(error.localizedDescription)"
            initialState.lastError = message
            initialEvents.append(
                PersistenceEvent(
                    level: .error,
                    operation: "stateStore.createDirectory.error",
                    message: message,
                    metadata: ["path": directory.path]
                )
            )
        }

        if fileManager.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                initialState = try decoder.decode(PersistedSyncState.self, from: data)
            } catch {
                let backupResult = Self.backUpCorruptStateFile(at: url, fileManager: fileManager)
                let message = "Sync-State-Datei konnte nicht gelesen werden und wurde zurückgesetzt: \(error.localizedDescription)"
                initialState = PersistedSyncState()
                initialState.lastError = message
                initialEvents.append(
                    PersistenceEvent(
                        level: .error,
                        operation: "stateStore.load.error",
                        message: message,
                        metadata: [
                            "path": url.path,
                            "backupPath": backupResult.backupURL?.path ?? "",
                            "backupError": backupResult.errorDescription ?? ""
                        ]
                    )
                )
            }
        }

        self.state = initialState
        self.persistenceEvents = initialEvents
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

        do {
            return try decoder.decode(CKSyncEngine.State.Serialization.self, from: data)
        } catch {
            recordPersistenceFailure(
                operation: "stateStore.engineState.decode.error",
                message: "CKSyncEngine-State konnte nicht gelesen werden: \(error.localizedDescription)",
                metadata: [:]
            )
            return nil
        }
    }

    func saveEngineState(_ serialization: CKSyncEngine.State.Serialization) {
        do {
            state.engineStateData = try encoder.encode(serialization)
            persist()
        } catch {
            recordPersistenceFailure(
                operation: "stateStore.engineState.encode.error",
                message: "CKSyncEngine-State konnte nicht gespeichert werden: \(error.localizedDescription)",
                metadata: [:]
            )
        }
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

    func lastErrorIsRetryable() -> Bool {
        state.lastError != nil && state.lastErrorIsRetryable
    }

    func setLastError(_ error: String?, isRetryable: Bool = true) {
        state.lastError = error
        state.lastErrorIsRetryable = error == nil ? false : isRetryable
        persist()
    }

    func clearLastError() {
        state.lastError = nil
        state.lastErrorIsRetryable = false
        persist()
    }

    func drainPersistenceEvents() -> [PersistenceEvent] {
        let events = persistenceEvents
        persistenceEvents.removeAll()
        return events
    }

    private func persist() {
        do {
            let data = try encoder.encode(state)
            try data.write(to: url, options: .atomic)
            try ProtectedFileStorage.applyProtection(to: url)
        } catch {
            recordPersistenceFailure(
                operation: "stateStore.persist.error",
                message: "Sync-State-Datei konnte nicht geschrieben werden: \(error.localizedDescription)",
                metadata: ["path": url.path]
            )
        }
    }

    private func recordPersistenceFailure(operation: String, message: String, metadata: [String: String]) {
        state.lastError = message
        state.lastErrorIsRetryable = false
        persistenceEvents.append(
            PersistenceEvent(
                level: .error,
                operation: operation,
                message: message,
                metadata: metadata
            )
        )
    }

    private static func backUpCorruptStateFile(
        at url: URL,
        fileManager: FileManager
    ) -> (backupURL: URL?, errorDescription: String?) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: .now)
            .replacingOccurrences(of: ":", with: "-")
        let backupURL = url
            .deletingLastPathComponent()
            .appendingPathComponent("sync-state.schema-\(PersistedSyncState.currentSchemaVersion).corrupt-\(timestamp).json")

        do {
            try fileManager.copyItem(at: url, to: backupURL)
            try ProtectedFileStorage.applyProtection(to: backupURL, fileManager: fileManager)
            return (backupURL, nil)
        } catch {
            return (nil, error.localizedDescription)
        }
    }
}
