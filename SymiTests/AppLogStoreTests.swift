import Foundation
import Testing
@testable import Symi

struct AppLogStoreTests {
    @Test
    func persistsAndLoadsEntries() async throws {
        let directory = try makeTemporaryDirectory()
        let store = AppLogStore(fileManager: .default, baseDirectoryURL: directory, retentionWindow: 60 * 60 * 24 * 7, maxEntryCount: 10)

        await store.log(level: .info, category: .sync, operation: "sync.start", message: "Start", metadata: ["count": "1"])
        let entries = await store.recentEntries()

        #expect(entries.count == 1)
        #expect(entries.first?.operation == "sync.start")

        let reloadedStore = AppLogStore(fileManager: .default, baseDirectoryURL: directory, retentionWindow: 60 * 60 * 24 * 7, maxEntryCount: 10)
        let reloadedEntries = await reloadedStore.recentEntries()
        #expect(reloadedEntries.count == 1)
    }

    @Test
    func retentionRemovesExpiredEntries() async throws {
        let directory = try makeTemporaryDirectory()
        let store = AppLogStore(fileManager: .default, baseDirectoryURL: directory, retentionWindow: -1, maxEntryCount: 10)
        await store.log(level: .info, category: .sync, operation: "expired", message: "Alt")

        let entries = await store.recentEntries()
        #expect(entries.isEmpty)
    }

    @Test
    func clearRemovesEntries() async throws {
        let directory = try makeTemporaryDirectory()
        let store = AppLogStore(fileManager: .default, baseDirectoryURL: directory, retentionWindow: 60 * 60 * 24 * 7, maxEntryCount: 10)
        await store.log(level: .error, category: .sync, operation: "sync.error", message: "Fehler")
        await store.clear()

        let entries = await store.recentEntries()
        #expect(entries.isEmpty)
    }

    @Test
    func exportCreatesFileForAvailableEntries() async throws {
        let directory = try makeTemporaryDirectory()
        let store = AppLogStore(fileManager: .default, baseDirectoryURL: directory, retentionWindow: 60 * 60 * 24 * 7, maxEntryCount: 10)
        await store.log(level: .warning, category: .sync, operation: "sync.warning", message: "Warnung")

        let url = await store.exportLogFileURL()

        #expect(url != nil)
        #expect(url.map { FileManager.default.fileExists(atPath: $0.path) } == true)
    }

    @Test
    func errorFilterReturnsOnlyErrors() async throws {
        let directory = try makeTemporaryDirectory()
        let store = AppLogStore(fileManager: .default, baseDirectoryURL: directory, retentionWindow: 60 * 60 * 24 * 7, maxEntryCount: 10)
        await store.log(level: .info, category: .sync, operation: "sync.info", message: "Info")
        await store.log(level: .error, category: .sync, operation: "sync.error", message: "Fehler")

        let entries = await store.recentEntries(filter: .errors)

        #expect(entries.count == 1)
        #expect(entries.first?.level == .error)
    }
}

private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
