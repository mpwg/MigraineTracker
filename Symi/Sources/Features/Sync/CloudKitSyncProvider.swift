import CloudKit
import Foundation

enum SyncProviderEvent: Sendable {
    case didUpdateState(CKSyncEngine.State.Serialization)
    case didFetchRecords([CKRecord])
    case didDeleteRecords([CKRecord.ID])
    case didSendRecords([CKRecord])
    case didFailToSend([SyncFailedRecordSave])
    case didEncounterError(String)
    case didRecoverAccountAvailability
}

struct SyncFailedRecordSave: Sendable {
    let recordID: CKRecord.ID
    let error: CKError
    let serverRecord: CKRecord?

    init(recordID: CKRecord.ID, error: CKError, serverRecord: CKRecord? = nil) {
        self.recordID = recordID
        self.error = error
        self.serverRecord = serverRecord
    }
}

protocol SyncProvider: AnyObject, Sendable {
    var queuedChangeCount: Int { get async }
    var accountAvailability: SyncServiceState { get async }

    func start() async throws
    func stop() async
    func queue(recordNames: [String]) async
    func fetch() async throws
    func send() async throws
    func deleteCloudData() async throws
}

actor CloudKitSyncProviderState {
    private var syncEngine: CKSyncEngine?
    private var pendingRecordNames = Set<String>()

    var queuedChangeCount: Int {
        if let syncEngine {
            return syncEngine.state.pendingRecordZoneChanges.count + syncEngine.state.pendingDatabaseChanges.count
        }

        return pendingRecordNames.count
    }

    func hasSyncEngine() -> Bool {
        syncEngine != nil
    }

    func installSyncEngine(_ engine: CKSyncEngine) {
        syncEngine = engine
    }

    func stopSyncEngine() async {
        await syncEngine?.cancelOperations()
        syncEngine = nil
    }

    func queue(recordNames: [String], zoneID: CKRecordZone.ID) -> Bool {
        pendingRecordNames.formUnion(recordNames)

        guard let syncEngine else {
            return false
        }

        syncEngine.state.add(pendingRecordZoneChanges: pendingRecordZoneChanges(for: recordNames, zoneID: zoneID))
        return true
    }

    func removeSentRecordNames(_ recordNames: [String]) {
        pendingRecordNames.subtract(recordNames)
    }

    func fetchChanges(zoneID: CKRecordZone.ID) async throws -> Bool {
        guard let syncEngine else {
            return false
        }

        try await syncEngine.fetchChanges(
            .init(scope: .zoneIDs([zoneID]))
        )
        return true
    }

    func sendChanges(zoneID: CKRecordZone.ID) async throws -> Bool {
        guard let syncEngine else {
            return false
        }

        try await syncEngine.sendChanges(
            .init(scope: .zoneIDs([zoneID]))
        )
        return true
    }

    private func pendingRecordZoneChanges(
        for recordNames: [String],
        zoneID: CKRecordZone.ID
    ) -> [CKSyncEngine.PendingRecordZoneChange] {
        recordNames.map {
            CKSyncEngine.PendingRecordZoneChange.saveRecord(
                CKRecord.ID(recordName: $0, zoneID: zoneID)
            )
        }
    }
}

final class CloudKitSyncProvider: NSObject, SyncProvider {
    private let stateStore: SyncStateStore
    private let zoneID: CKRecordZone.ID
    private let recordProvider: @Sendable (CKRecord.ID) async -> CKRecord?
    private let eventHandler: @Sendable (SyncProviderEvent) async -> Void
    private let appLogStore: AppLogStore
    private let providerState = CloudKitSyncProviderState()
    private let container = CKContainer(identifier: SyncConfiguration.containerIdentifier)

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
            await providerState.queuedChangeCount
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
        guard await !providerState.hasSyncEngine() else {
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
        await providerState.installSyncEngine(engine)
        await log(level: .info, operation: "provider.start", message: "CloudKit-Sync-Engine gestartet.", metadata: [
            "zone": zoneID.zoneName
        ])
    }

    func stop() async {
        await providerState.stopSyncEngine()
        await log(level: .info, operation: "provider.stop", message: "CloudKit-Sync-Engine gestoppt.")
    }

    func queue(recordNames: [String]) async {
        await log(level: .debug, operation: "provider.queue", message: "Records für Upload markiert.", metadata: [
            "count": "\(recordNames.count)",
            "recordNames": recordNames.sorted().joined(separator: ",")
        ])

        let wasQueuedInEngine = await providerState.queue(recordNames: recordNames, zoneID: zoneID)
        guard wasQueuedInEngine else {
            await log(level: .warning, operation: "provider.queue.deferred", message: "Queue wurde vorgemerkt, Engine ist aber noch nicht aktiv.")
            return
        }
    }

    func fetch() async throws {
        guard await providerState.hasSyncEngine() else {
            await log(level: .warning, operation: "provider.fetch.skip", message: "Fetch übersprungen, da keine Sync-Engine aktiv ist.")
            return
        }

        await log(level: .info, operation: "provider.fetch.start", message: "CloudKit-Änderungen werden geladen.")
        _ = try await providerState.fetchChanges(zoneID: zoneID)
        await log(level: .info, operation: "provider.fetch.finish", message: "CloudKit-Änderungen wurden geladen.")
    }

    func send() async throws {
        guard await providerState.hasSyncEngine() else {
            await log(level: .warning, operation: "provider.send.skip", message: "Upload übersprungen, da keine Sync-Engine aktiv ist.")
            return
        }

        let pendingRecordCount = await queuedChangeCount
        await log(level: .info, operation: "provider.send.start", message: "CloudKit-Änderungen werden gesendet.", metadata: [
            "pendingRecords": "\(pendingRecordCount)"
        ])
        do {
            _ = try await providerState.sendChanges(zoneID: zoneID)
        } catch let error as CKError {
            if await handlePartialSendFailure(error) {
                await log(level: .warning, operation: "provider.send.partialFailure", message: "CloudKit hat einzelne Records abgelehnt; Details wurden an den Coordinator übergeben.")
                return
            }
            throw error
        }
        await log(level: .info, operation: "provider.send.finish", message: "CloudKit-Änderungen wurden gesendet.")
    }

    func deleteCloudData() async throws {
        await providerState.stopSyncEngine()
        await log(level: .warning, operation: "provider.deleteCloudData.start", message: "Bestätigtes Löschen der Cloud-Daten wird gestartet.", metadata: [
            "zone": zoneID.zoneName
        ])

        do {
            let results = try await container.privateCloudDatabase.modifyRecordZones(
                saving: [],
                deleting: [zoneID]
            )
            if case let .failure(error)? = results.deleteResults[zoneID] {
                if let cloudKitError = error as? CKError, cloudKitError.code == .zoneNotFound {
                    await log(level: .info, operation: "provider.deleteCloudData.missingZone", message: "Keine Cloud-Datenzone zum Löschen gefunden.", metadata: [
                        "zone": zoneID.zoneName
                    ])
                    return
                }

                throw error
            }
            await log(level: .warning, operation: "provider.deleteCloudData.finish", message: "Cloud-Daten wurden aus iCloud entfernt.", metadata: [
                "zone": zoneID.zoneName
            ])
        } catch let error as CKError where error.code == .zoneNotFound {
            await log(level: .info, operation: "provider.deleteCloudData.missingZone", message: "Keine Cloud-Datenzone zum Löschen gefunden.", metadata: [
                "zone": zoneID.zoneName
            ])
        }
    }

    private func handlePartialSendFailure(_ error: CKError) async -> Bool {
        let partialErrors: [(CKRecord.ID, CKError)]
        if let errors = error.userInfo[CKPartialErrorsByItemIDKey] as? [CKRecord.ID: Error] {
            partialErrors = errors.compactMap { recordID, error in
                guard let ckError = error as? CKError else {
                    return nil
                }

                return (recordID, ckError)
            }
        } else if let errors = error.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {
            partialErrors = errors.compactMap { key, error in
                guard let recordID = key as? CKRecord.ID, let ckError = error as? CKError else {
                    return nil
                }

                return (recordID, ckError)
            }
        } else {
            return false
        }

        var failures: [SyncFailedRecordSave] = []
        for (recordID, recordError) in partialErrors {
            let serverRecord = await resolvedServerRecord(for: recordID, error: recordError)
            failures.append(SyncFailedRecordSave(recordID: recordID, error: recordError, serverRecord: serverRecord))
        }

        guard !failures.isEmpty else {
            return false
        }

        await eventHandler(.didFailToSend(failures))
        return true
    }

    private func resolvedServerRecord(for recordID: CKRecord.ID, error: CKError) async -> CKRecord? {
        if let serverRecord = error.serverRecord {
            return serverRecord
        }

        guard error.code == .serverRecordChanged else {
            return nil
        }

        do {
            return try await container.privateCloudDatabase.record(for: recordID)
        } catch {
            await log(level: .warning, operation: "provider.serverRecordChanged.fetchFailed", message: "Vorhandener Server-Record konnte nach Konfliktmeldung nicht geladen werden.", metadata: [
                "recordID": recordID.recordName,
                "error": error.localizedDescription
            ])
            return nil
        }
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
                SyncFailedRecordSave(recordID: $0.record.recordID, error: $0.error, serverRecord: $0.error.serverRecord)
            }
            await providerState.removeSentRecordNames(changes.savedRecords.map { $0.recordID.recordName })
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
                await eventHandler(.didRecoverAccountAvailability)
            @unknown default:
                await log(level: .warning, operation: "provider.event.accountChange.unknown", message: "Unbekannte iCloud-Änderung erkannt.")
                await eventHandler(.didEncounterError("Unbekannte iCloud-Änderung erkannt."))
            }
        case .fetchedDatabaseChanges:
            await log(level: .debug, operation: "provider.event.fetchedDatabaseChanges", message: "Datenbankweite Änderungen wurden verarbeitet.")
        @unknown default:
            await log(level: .warning, operation: "provider.event.unknown", message: "Unbekanntes CKSyncEngine-Ereignis empfangen.")
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

    static func record(
        for envelope: SyncDocumentEnvelope,
        zoneID: CKRecordZone.ID,
        existingSystemFields: Data?,
        systemFieldsFallback: ((CloudKitRecordSystemFieldsFallbackReason) -> Void)? = nil
    ) -> CKRecord? {
        let recordID = CKRecord.ID(recordName: envelope.documentID, zoneID: zoneID)
        let restoredRecord = existingRecord(for: recordID, systemFields: existingSystemFields)
        if let fallbackReason = restoredRecord.fallbackReason {
            systemFieldsFallback?(fallbackReason)
        }

        let record = restoredRecord.record ?? CKRecord(
            recordType: SyncConfiguration.recordType,
            recordID: recordID
        )

        let data: Data
        do {
            data = try encodedPayloadData(for: envelope)
        } catch {
            return nil
        }

        guard let payloadString = String(data: data, encoding: .utf8) else {
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

        guard data.count <= SyncPayloadSchema.maximumCloudKitPayloadBytes else {
            return nil
        }

        let envelope: SyncDocumentEnvelope
        do {
            envelope = try decoder.decode(SyncDocumentEnvelope.self, from: data)
        } catch {
            return nil
        }

        guard
            record["documentID"] as? String == envelope.documentID,
            record["entityType"] as? String == envelope.entityType.rawValue,
            (record["schemaVersion"] as? NSNumber)?.intValue == envelope.schemaVersion
        else {
            return nil
        }

        return envelope
    }

    static func payloadByteCount(for envelope: SyncDocumentEnvelope) -> Int? {
        do {
            return try encoder.encode(envelope).count
        } catch {
            return nil
        }
    }

    static func systemFields(for record: CKRecord) -> Data? {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: archiver)
        archiver.finishEncoding()
        return archiver.encodedData
    }

    private static func existingRecord(
        for recordID: CKRecord.ID,
        systemFields: Data?
    ) -> (record: CKRecord?, fallbackReason: CloudKitRecordSystemFieldsFallbackReason?) {
        guard let systemFields else {
            return (nil, nil)
        }

        let unarchiver: NSKeyedUnarchiver
        do {
            unarchiver = try NSKeyedUnarchiver(forReadingFrom: systemFields)
        } catch {
            return (nil, .undecodableArchive)
        }

        unarchiver.requiresSecureCoding = true
        let record = CKRecord(coder: unarchiver)
        unarchiver.finishDecoding()

        guard let record else {
            return (nil, .missingRecord)
        }

        guard record.recordID == recordID else {
            return (nil, .recordIDMismatch)
        }

        return (record, nil)
    }

    private static func encodedPayloadData(for envelope: SyncDocumentEnvelope) throws -> Data {
        let data = try encoder.encode(envelope)
        guard data.count <= SyncPayloadSchema.maximumCloudKitPayloadBytes else {
            throw CloudKitRecordCodecError.payloadTooLarge(byteCount: data.count)
        }

        return data
    }
}

enum CloudKitRecordSystemFieldsFallbackReason: String, Equatable, Sendable {
    case undecodableArchive
    case missingRecord
    case recordIDMismatch
}

private enum CloudKitRecordCodecError: Error {
    case payloadTooLarge(byteCount: Int)
}
