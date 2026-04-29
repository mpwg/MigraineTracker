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
        await store.log(level: .critical, category: .sync, operation: "sync.critical", message: "Kritisch")

        let entries = await store.recentEntries(filter: .errors)

        #expect(entries.count == 2)
        #expect(entries.contains { $0.level == .error })
        #expect(entries.contains { $0.level == .critical })
    }

    @Test
    func sentryReporterCreatesBreadcrumbForInfoLog() async throws {
        let client = CapturingSentryClient()
        let reporter = await AppSentryLogReporter(client: client)
        await reporter.setEnabled(true)
        let store = AppLogStore(
            fileManager: .default,
            baseDirectoryURL: try makeTemporaryDirectory(),
            retentionWindow: 60 * 60 * 24 * 7,
            maxEntryCount: 10,
            remoteReporter: reporter
        )

        await store.log(level: .info, category: .sync, operation: "sync.info", message: "Info", metadata: ["count": "1"])

        let breadcrumbs = await client.breadcrumbs
        let events = await client.events
        #expect(breadcrumbs.count == 1)
        #expect(events.isEmpty)
        #expect(breadcrumbs.first?.level == .info)
        #expect(breadcrumbs.first?.category == "sync")
        #expect(breadcrumbs.first?.data["operation"] == "sync.info")
    }

    @Test
    func sentryReporterCreatesEventForErrorLog() async throws {
        let client = CapturingSentryClient()
        let reporter = await AppSentryLogReporter(client: client)
        await reporter.setEnabled(true)
        let store = AppLogStore(
            fileManager: .default,
            baseDirectoryURL: try makeTemporaryDirectory(),
            retentionWindow: 60 * 60 * 24 * 7,
            maxEntryCount: 10,
            remoteReporter: reporter
        )

        await store.log(level: .error, category: .sync, operation: "sync.error", message: "Fehler")

        let breadcrumbs = await client.breadcrumbs
        let events = await client.events
        #expect(breadcrumbs.count == 1)
        #expect(events.count == 1)
        #expect(events.first?.level == .error)
        #expect(events.first?.message == "Fehler")
    }

    @Test
    func sentryReporterMapsCriticalLogsToFatalEvents() async throws {
        let client = CapturingSentryClient()
        let reporter = await AppSentryLogReporter(client: client)
        await reporter.setEnabled(true)
        let store = AppLogStore(
            fileManager: .default,
            baseDirectoryURL: try makeTemporaryDirectory(),
            retentionWindow: 60 * 60 * 24 * 7,
            maxEntryCount: 10,
            remoteReporter: reporter
        )

        await store.log(level: .critical, category: .app, operation: "startup.failure", message: "Start fehlgeschlagen")

        let breadcrumbs = await client.breadcrumbs
        let events = await client.events
        #expect(breadcrumbs.first?.level == .fatal)
        #expect(events.first?.level == .fatal)
    }

    @Test
    func sentryReporterRedactsSensitiveMetadataAndText() async throws {
        let client = CapturingSentryClient()
        let reporter = await AppSentryLogReporter(client: client)
        await reporter.setEnabled(true)
        let store = AppLogStore(
            fileManager: .default,
            baseDirectoryURL: try makeTemporaryDirectory(),
            retentionWindow: 60 * 60 * 24 * 7,
            maxEntryCount: 10,
            remoteReporter: reporter
        )

        await store.log(
            level: .error,
            category: .app,
            operation: "support.contact",
            message: "Kontakt test@example.com wegen Medikament Aspirin",
            metadata: [
                "medicationName": "Aspirin",
                "note": "starke Schmerzen",
                "safeCount": "3"
            ]
        )

        let event = try #require((await client.events).first)
        #expect(event.message == "Kontakt [redacted] wegen [redacted]")
        #expect(event.extra["medicationName"] == "[redacted]")
        #expect(event.extra["note"] == "[redacted]")
        #expect(event.extra["safeCount"] == "3")
    }

    @Test
    func sentryReporterDoesNothingWhenDisabled() async throws {
        let client = CapturingSentryClient()
        let reporter = await AppSentryLogReporter(client: client)
        let store = AppLogStore(
            fileManager: .default,
            baseDirectoryURL: try makeTemporaryDirectory(),
            retentionWindow: 60 * 60 * 24 * 7,
            maxEntryCount: 10,
            remoteReporter: reporter
        )

        await store.log(level: .error, category: .sync, operation: "sync.error", message: "Fehler")

        let breadcrumbs = await client.breadcrumbs
        let events = await client.events
        #expect(breadcrumbs.isEmpty)
        #expect(events.isEmpty)
    }
}

private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

private actor CapturingSentryClient: AppSentryClient {
    private var capturedBreadcrumbs: [AppRemoteLogBreadcrumb] = []
    private var capturedEvents: [AppRemoteLogEvent] = []

    var breadcrumbs: [AppRemoteLogBreadcrumb] {
        capturedBreadcrumbs
    }

    var events: [AppRemoteLogEvent] {
        capturedEvents
    }

    func addBreadcrumb(_ breadcrumb: AppRemoteLogBreadcrumb) {
        capturedBreadcrumbs.append(breadcrumb)
    }

    func captureEvent(_ event: AppRemoteLogEvent) {
        capturedEvents.append(event)
    }
}
