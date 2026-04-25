import Foundation
import SwiftData
import Testing
@testable import Symi

@MainActor
struct PersistentStoreRecoveryTests {
    @Test
    func unknownModelVersionDoesNotDeleteStoreFiles() throws {
        let directory = try makeTemporaryDirectory()
        let storeURL = directory.appending(path: "default.store")
        let walURL = directory.appending(path: "default.store-wal")
        let shmURL = directory.appending(path: "default.store-shm")
        let storeData = Data("store-sentinel".utf8)
        let walData = Data("wal-sentinel".utf8)
        let shmData = Data("shm-sentinel".utf8)
        try storeData.write(to: storeURL)
        try walData.write(to: walURL)
        try shmData.write(to: shmURL)

        let schema = Schema(versionedSchema: SymiSchemaV5.self)
        let configuration = ModelConfiguration(
            "default",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let unknownModelVersionError = NSError(
            domain: NSCocoaErrorDomain,
            code: PersistentStoreRecoveryService.unknownModelVersionErrorCode
        )

        do {
            _ = try SymiApp.makeContainer(schema: schema, configuration: configuration) {
                throw unknownModelVersionError
            }
            Issue.record("Ein unbekannter Modellversionsfehler muss in den Recovery-Zustand laufen.")
        } catch PersistentStoreLoadError.recoveryRequired(let context) {
            #expect(context.reason == .unknownModelVersion)
            #expect(context.storeURL == storeURL)
        } catch {
            Issue.record("Unerwarteter Fehler: \(error)")
        }

        #expect(FileManager.default.fileExists(atPath: storeURL.path))
        #expect(FileManager.default.fileExists(atPath: walURL.path))
        #expect(FileManager.default.fileExists(atPath: shmURL.path))
        #expect(try Data(contentsOf: storeURL) == storeData)
        #expect(try Data(contentsOf: walURL) == walData)
        #expect(try Data(contentsOf: shmURL) == shmData)
    }

    @Test
    func migrationErrorsAreClassifiedForRecovery() {
        let migrationError = NSError(
            domain: NSCocoaErrorDomain,
            code: PersistentStoreRecoveryService.migrationErrorCodeRange.lowerBound + 10
        )

        let reason = PersistentStoreRecoveryService.recoveryReason(for: migrationError)

        #expect(reason == .migrationFailure)
    }

    @Test
    func backupPreparationCopiesStoreFilesWithoutChangingOriginals() throws {
        let directory = try makeTemporaryDirectory()
        let storeURL = directory.appending(path: "default.store")
        let walURL = directory.appending(path: "default.store-wal")
        let storeData = Data("store-sentinel".utf8)
        let walData = Data("wal-sentinel".utf8)
        try storeData.write(to: storeURL)
        try walData.write(to: walURL)

        let backupURLs = try PersistentStoreRecoveryService.copyStoreFilesForSharing(
            from: storeURL,
            now: Date(timeIntervalSince1970: 1_000)
        )

        #expect(backupURLs.count == 2)
        #expect(try Data(contentsOf: storeURL) == storeData)
        #expect(try Data(contentsOf: walURL) == walData)
        #expect(backupURLs.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
    }
}

private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
