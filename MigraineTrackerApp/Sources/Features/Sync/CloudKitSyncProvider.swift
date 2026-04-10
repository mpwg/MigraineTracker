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
    private var syncEngine: CKSyncEngine?
    private let container = CKContainer(identifier: SyncConfiguration.containerIdentifier)
    private var pendingRecordNames = Set<String>()

    init(
        stateStore: SyncStateStore,
        zoneID: CKRecordZone.ID,
        recordProvider: @escaping @Sendable (CKRecord.ID) async -> CKRecord?,
        eventHandler: @escaping @Sendable (SyncProviderEvent) async -> Void
    ) {
        self.stateStore = stateStore
        self.zoneID = zoneID
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
    }

    func stop() async {
        await syncEngine?.cancelOperations()
        syncEngine = nil
    }

    func queue(recordNames: [String]) async {
        pendingRecordNames.formUnion(recordNames)

        guard let syncEngine else {
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
            return
        }

        try await syncEngine.fetchChanges(
            .init(scope: .zoneIDs([zoneID]))
        )
    }

    func send() async throws {
        guard let syncEngine else {
            return
        }

        try await syncEngine.sendChanges(
            .init(scope: .zoneIDs([zoneID]))
        )
    }
}

extension CloudKitSyncProvider: CKSyncEngineDelegate {
    func handleEvent(_ event: CKSyncEngine.Event, syncEngine _: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let update):
            await eventHandler(.didUpdateState(update.stateSerialization))
        case .fetchedRecordZoneChanges(let changes):
            await eventHandler(.didFetchRecords(changes.modifications.map(\.record)))
            await eventHandler(.didDeleteRecords(changes.deletions.map(\.recordID)))
        case .sentRecordZoneChanges(let changes):
            let failures = changes.failedRecordSaves.map {
                SyncFailedRecordSave(recordID: $0.record.recordID, error: $0.error)
            }
            pendingRecordNames.subtract(changes.savedRecords.map { $0.recordID.recordName })
            await eventHandler(.didSendRecords(changes.savedRecords))
            if !failures.isEmpty {
                await eventHandler(.didFailToSend(failures))
            }
        case .sentDatabaseChanges(let changes):
            if !changes.failedZoneSaves.isEmpty {
                await eventHandler(.didEncounterError(changes.failedZoneSaves[0].error.localizedDescription))
            }
        case .didFetchRecordZoneChanges(let change):
            if let error = change.error {
                await eventHandler(.didEncounterError(error.localizedDescription))
            }
        case .didSendChanges:
            break
        case .didFetchChanges:
            break
        case .willFetchChanges:
            break
        case .willFetchRecordZoneChanges:
            break
        case .willSendChanges:
            break
        case .accountChange(let change):
            switch change.changeType {
            case .signOut, .switchAccounts:
                await eventHandler(.didEncounterError("Der iCloud-Account wurde geändert. Bitte prüfe den Sync-Status."))
            case .signIn:
                break
            @unknown default:
                await eventHandler(.didEncounterError("Unbekannte iCloud-Änderung erkannt."))
            }
        case .fetchedDatabaseChanges:
            break
        @unknown default:
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
