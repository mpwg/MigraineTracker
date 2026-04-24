import CloudKit
import Foundation

enum SyncProviderEvent: Sendable {
    case didUpdateState(CKSyncEngine.State.Serialization)
    case didFetchRecords([CKRecord])
    case didDeleteRecords([CKRecord.ID])
    case didSendRecords([CKRecord])
    case didFailToSend([SyncFailedRecordSave])
    case didEncounterError(String)
}

struct SyncFailedRecordSave: Sendable {
    let recordID: CKRecord.ID
    let error: CKError
}

protocol SyncProvider: AnyObject {
    var queuedChangeCount: Int { get async }
    var accountAvailability: SyncServiceState { get async }

    func start() async throws
    func stop() async
    func queue(recordNames: [String]) async
    func fetch() async throws
    func send() async throws
}

final class CloudKitSyncProvider: NSObject, @unchecked Sendable, SyncProvider {
    private let stateStore: SyncStateStore
    private let zoneID: CKRecordZone.ID
    private let recordProvider: @Sendable (CKRecord.ID) async -> CKRecord?
    private let eventHandler: @Sendable (SyncProviderEvent) async -> Void
    private let appLogStore: AppLogStore
    private var syncEngine: CKSyncEngine?
    private let container = CKContainer(identifier: SyncConfiguration.containerIdentifier)
    private var pendingRecordNames = Set<String>()

    init(
        stateStore: SyncStateStore,
        zoneID: CKRecordZone.ID,
        appLogStore: AppLogStore,
        recordProvider: @escaping @Sendable (CKRecord.ID) async -> CKRecord?,
        eventHandler: @escaping @Sendable (SyncProviderEvent) async -> Void
    ) {
        self.stateStore = stateStore
        self.zoneID = zoneID
        self.appLogStore = appLogStore
        self.recordProvider = recordProvider
        self.eventHandler = eventHandler
    }

    var queuedChangeCount: Int {
        get async {
            if let syncEngine {
                return syncEngine.state.pendingRecordZoneChanges.count + syncEngine.state.pendingDatabaseChanges.count
            }

            return pendingRecordNames.count
        }
    }

    var accountAvailability: SyncServiceState {
        get async {
            do {
                switch try await container.accountStatus() {
                case .available:
                    return .ready
                case .noAccount:
                    return .noICloudAccount
                default:
                    return .needsAttention
                }
            } catch {
                return .needsAttention
            }
        }
    }

    func start() async throws {
        guard syncEngine == nil else {
            await log(level: .debug, operation: "provider.start.skip", message: "Sync-Engine läuft bereits.")
            return
        }

        let database = container.privateCloudDatabase
        let configuration = CKSyncEngine.Configuration(
            database: database,
            stateSerialization: await stateStore.engineState(),
            delegate: self
        )

        let engine = CKSyncEngine(configuration)
        engine.state.add(
            pendingDatabaseChanges: [
                .saveZone(CKRecordZone(zoneID: zoneID))
            ]
        )
        syncEngine = engine
        await log(level: .info, operation: "provider.start", message: "CloudKit-Sync-Engine gestartet.", metadata: [
            "zone": zoneID.zoneName
        ])
    }

    func stop() async {
        await syncEngine?.cancelOperations()
        syncEngine = nil
        await log(level: .info, operation: "provider.stop", message: "CloudKit-Sync-Engine gestoppt.")
    }

    func queue(recordNames: [String]) async {
        pendingRecordNames.formUnion(recordNames)
        await log(level: .debug, operation: "provider.queue", message: "Records für Upload markiert.", metadata: [
            "count": "\(recordNames.count)",
            "recordNames": recordNames.sorted().joined(separator: ",")
        ])

        guard let syncEngine else {
            await log(level: .warning, operation: "provider.queue.deferred", message: "Queue wurde vorgemerkt, Engine ist aber noch nicht aktiv.")
            return
        }

        let changes = recordNames.map {
            CKSyncEngine.PendingRecordZoneChange.saveRecord(
                CKRecord.ID(recordName: $0, zoneID: zoneID)
            )
        }
        syncEngine.state.add(pendingRecordZoneChanges: changes)
    }

    func fetch() async throws {
        guard let syncEngine else {
            await log(level: .warning, operation: "provider.fetch.skip", message: "Fetch übersprungen, da keine Sync-Engine aktiv ist.")
            return
        }

        await log(level: .info, operation: "provider.fetch.start", message: "CloudKit-Änderungen werden geladen.")
        try await syncEngine.fetchChanges(
            .init(scope: .zoneIDs([zoneID]))
        )
        await log(level: .info, operation: "provider.fetch.finish", message: "CloudKit-Änderungen wurden geladen.")
    }

    func send() async throws {
        guard let syncEngine else {
            await log(level: .warning, operation: "provider.send.skip", message: "Upload übersprungen, da keine Sync-Engine aktiv ist.")
            return
        }

        await log(level: .info, operation: "provider.send.start", message: "CloudKit-Änderungen werden gesendet.", metadata: [
            "pendingRecords": "\(await queuedChangeCount)"
        ])
        try await syncEngine.sendChanges(
            .init(scope: .zoneIDs([zoneID]))
        )
        await log(level: .info, operation: "provider.send.finish", message: "CloudKit-Änderungen wurden gesendet.")
    }
}

extension CloudKitSyncProvider: CKSyncEngineDelegate {
    func handleEvent(_ event: CKSyncEngine.Event, syncEngine _: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let update):
            await log(level: .debug, operation: "provider.event.stateUpdate", message: "Sync-Statusserialisierung aktualisiert.")
            await eventHandler(.didUpdateState(update.stateSerialization))
        case .fetchedRecordZoneChanges(let changes):
            await log(level: .info, operation: "provider.event.fetchedRecordZoneChanges", message: "Remote-Änderungen empfangen.", metadata: [
                "modifications": "\(changes.modifications.count)",
                "deletions": "\(changes.deletions.count)"
            ])
            await eventHandler(.didFetchRecords(changes.modifications.map(\.record)))
            await eventHandler(.didDeleteRecords(changes.deletions.map(\.recordID)))
        case .sentRecordZoneChanges(let changes):
            let failures = changes.failedRecordSaves.map {
                SyncFailedRecordSave(recordID: $0.record.recordID, error: $0.error)
            }
            pendingRecordNames.subtract(changes.savedRecords.map { $0.recordID.recordName })
            await log(level: failures.isEmpty ? .info : .warning, operation: "provider.event.sentRecordZoneChanges", message: "Upload-Ergebnis erhalten.", metadata: [
                "savedRecords": "\(changes.savedRecords.count)",
                "failedRecords": "\(failures.count)"
            ])
            await eventHandler(.didSendRecords(changes.savedRecords))
            if !failures.isEmpty {
                await eventHandler(.didFailToSend(failures))
            }
        case .sentDatabaseChanges(let changes):
            if !changes.failedZoneSaves.isEmpty {
                await log(level: .error, operation: "provider.event.sentDatabaseChanges.error", message: "Zone konnte nicht gespeichert werden.", metadata: [
                    "failedZoneSaves": "\(changes.failedZoneSaves.count)"
                ])
                await eventHandler(.didEncounterError(changes.failedZoneSaves[0].error.localizedDescription))
            }
        case .didFetchRecordZoneChanges(let change):
            if let error = change.error {
                await log(level: .error, operation: "provider.event.didFetchRecordZoneChanges.error", message: "Fehler beim Laden einer Zone.", metadata: [
                    "error": error.localizedDescription
                ])
                await eventHandler(.didEncounterError(error.localizedDescription))
            }
        case .didSendChanges:
            await log(level: .debug, operation: "provider.event.didSendChanges", message: "CKSyncEngine meldet abgeschlossenen Sendelauf.")
        case .didFetchChanges:
            await log(level: .debug, operation: "provider.event.didFetchChanges", message: "CKSyncEngine meldet abgeschlossenen Fetch-Lauf.")
        case .willFetchChanges:
            await log(level: .debug, operation: "provider.event.willFetchChanges", message: "CKSyncEngine startet einen Fetch-Lauf.")
        case .willFetchRecordZoneChanges:
            await log(level: .debug, operation: "provider.event.willFetchRecordZoneChanges", message: "CKSyncEngine lädt Zonendetails.")
        case .willSendChanges:
            await log(level: .debug, operation: "provider.event.willSendChanges", message: "CKSyncEngine startet einen Sendelauf.")
        case .accountChange(let change):
            switch change.changeType {
            case .signOut, .switchAccounts:
                await log(level: .warning, operation: "provider.event.accountChange", message: "iCloud-Account wurde geändert.", metadata: [
                    "changeType": "\(change.changeType)"
                ])
                await eventHandler(.didEncounterError("Der iCloud-Account wurde geändert. Bitte prüfe den Sync-Status."))
            case .signIn:
                await log(level: .info, operation: "provider.event.accountChange", message: "iCloud-Account ist wieder verfügbar.", metadata: [
                    "changeType": "\(change.changeType)"
                ])
                break
            @unknown default:
                await log(level: .warning, operation: "provider.event.accountChange.unknown", message: "Unbekannte iCloud-Änderung erkannt.")
                await eventHandler(.didEncounterError("Unbekannte iCloud-Änderung erkannt."))
            }
        case .fetchedDatabaseChanges:
            await log(level: .debug, operation: "provider.event.fetchedDatabaseChanges", message: "Datenbankweite Änderungen wurden verarbeitet.")
        @unknown default:
            await log(level: .warning, operation: "provider.event.unknown", message: "Unbekanntes CKSyncEngine-Ereignis empfangen.")
            break
        }
    }

    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let changes = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        return await CKSyncEngine.RecordZoneChangeBatch(
            pendingChanges: changes,
            recordProvider: recordProvider
        )
    }

    private func log(
        level: AppLogLevel,
        operation: String,
        message: String,
        metadata: [String: String] = [:]
    ) async {
        await appLogStore.log(
            level: level,
            category: .sync,
            operation: operation,
            message: message,
            metadata: metadata
        )
    }
}

enum CloudKitRecordCodec {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func record(for envelope: SyncDocumentEnvelope, zoneID: CKRecordZone.ID, existingSystemFields: Data?) -> CKRecord? {
        let recordID = CKRecord.ID(recordName: envelope.documentID, zoneID: zoneID)
        let record = existingRecord(for: recordID, systemFields: existingSystemFields) ?? CKRecord(
            recordType: SyncConfiguration.recordType,
            recordID: recordID
        )

        guard let data = try? encoder.encode(envelope), let payloadString = String(data: data, encoding: .utf8) else {
            return nil
        }

        record["documentID"] = envelope.documentID as CKRecordValue
        record["entityType"] = envelope.entityType.rawValue as CKRecordValue
        record["schemaVersion"] = NSNumber(value: envelope.schemaVersion)
        record["modifiedAt"] = envelope.modifiedAt as CKRecordValue
        record["authorDeviceID"] = envelope.authorDeviceID as CKRecordValue
        record["payloadJSON"] = payloadString as CKRecordValue
        if let deletedAt = envelope.deletedAt {
            record["deletedAt"] = deletedAt as CKRecordValue
        } else {
            record["deletedAt"] = nil
        }

        return record
    }

    static func envelope(from record: CKRecord) -> SyncDocumentEnvelope? {
        guard let payloadString = record["payloadJSON"] as? String, let data = payloadString.data(using: .utf8) else {
            return nil
        }

        return try? decoder.decode(SyncDocumentEnvelope.self, from: data)
    }

    static func systemFields(for record: CKRecord) -> Data? {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: archiver)
        archiver.finishEncoding()
        return archiver.encodedData
    }

    private static func existingRecord(for recordID: CKRecord.ID, systemFields: Data?) -> CKRecord? {
        guard let systemFields else {
            return nil
        }

        let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: systemFields)
        unarchiver?.requiresSecureCoding = true
        let record = CKRecord(coder: unarchiver!)
        unarchiver?.finishDecoding()
        guard let record else {
            return nil
        }

        return record.recordID == recordID ? record : CKRecord(recordType: SyncConfiguration.recordType, recordID: recordID)
    }
}
