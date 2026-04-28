import Foundation
import Testing
@testable import Symi

struct FileProtectionPolicyTests {
    @Test
    func protectedDirectoryAndFileUseCompleteProtection() throws {
        let directory = try makeTemporaryDirectory()
        let protectedDirectory = directory.appendingPathComponent("Protected", isDirectory: true)
        let protectedFile = protectedDirectory.appendingPathComponent("health-context.json")

        try ProtectedFileStorage.createProtectedDirectory(at: protectedDirectory)
        try Data("sensibel".utf8).write(to: protectedFile, options: .atomic)
        try ProtectedFileStorage.applyProtection(to: protectedFile)

        try expectCompleteProtectionWhenAvailable(at: protectedDirectory)
        try expectCompleteProtectionWhenAvailable(at: protectedFile)
    }

    @Test
    func temporaryExportFilesAreProtectedExcludedFromBackupAndExpire() throws {
        let fileManager = FileManager.default
        let activeURL = fileManager.temporaryDirectory.appendingPathComponent("schmerztagebuch-export-\(UUID().uuidString).json5")
        let expiredURL = fileManager.temporaryDirectory.appendingPathComponent("Symi-Bericht-\(UUID().uuidString).pdf")
        defer {
            try? fileManager.removeItem(at: activeURL)
            try? fileManager.removeItem(at: expiredURL)
        }

        try TemporaryExportFileLifecycle.prepareProtectedTemporaryFile(at: activeURL)
        try Data("aktiv".utf8).write(to: activeURL, options: .atomic)
        try TemporaryExportFileLifecycle.finalizeProtectedTemporaryFile(at: activeURL)

        try Data("abgelaufen".utf8).write(to: expiredURL, options: .atomic)
        let expiredDate = Date(timeIntervalSinceNow: -(TemporaryExportFileLifecycle.expirationInterval + 60))
        try fileManager.setAttributes([.modificationDate: expiredDate], ofItemAtPath: expiredURL.path)

        try TemporaryExportFileLifecycle.cleanupExpiredFiles(now: .now)

        try expectCompleteProtectionWhenAvailable(at: activeURL)
        #expect(try activeURL.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
        #expect(fileManager.fileExists(atPath: activeURL.path))
        #expect(!fileManager.fileExists(atPath: expiredURL.path))
    }

    @Test
    @MainActor
    func healthContextSidecarsAreProtected() throws {
        let baseURL = try makeTemporaryDirectory()
        let episodeID = UUID()
        let store = HealthContextStore(baseURL: baseURL)

        try store.save(
            HealthContextSnapshotData(
                recordedAt: Date(timeIntervalSince1970: 1_000),
                source: "Test",
                sleepMinutes: 420,
                stepCount: 1_200,
                averageHeartRate: nil,
                restingHeartRate: 62,
                heartRateVariability: nil,
                menstrualFlow: nil,
                symptoms: []
            ),
            for: episodeID
        )

        let sidecarURL = baseURL
            .appendingPathComponent("Symi", isDirectory: true)
            .appendingPathComponent("HealthContext", isDirectory: true)
            .appendingPathComponent("\(episodeID.uuidString).json")
        try expectCompleteProtectionWhenAvailable(at: sidecarURL)
    }
}

private func expectCompleteProtectionWhenAvailable(at url: URL, fileManager: FileManager = .default) throws {
    let protection = try fileManager.attributesOfItem(atPath: url.path)[.protectionKey] as? FileProtectionType
    if let protection {
        #expect(protection == ProtectedFileStorage.fileProtectionType)
    }
}

private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
