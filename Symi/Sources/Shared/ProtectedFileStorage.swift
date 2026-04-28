import Foundation

nonisolated enum ProtectedFileStorage {
    static let fileProtectionType = FileProtectionType.complete

    static func createProtectedDirectory(
        at url: URL,
        fileManager: FileManager = .default,
        excludedFromBackup: Bool = false
    ) throws {
        try fileManager.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: fileProtectionType]
        )
        try applyProtection(to: url, fileManager: fileManager, excludedFromBackup: excludedFromBackup)
    }

    static func applyProtection(
        to url: URL,
        fileManager: FileManager = .default,
        excludedFromBackup: Bool = false
    ) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        try fileManager.setAttributes([.protectionKey: fileProtectionType], ofItemAtPath: url.path)
        try setBackupExclusion(excludedFromBackup, for: url)
    }

    static func applyProtectionRecursively(
        to url: URL,
        fileManager: FileManager = .default,
        excludedFromBackup: Bool = false
    ) throws {
        try applyProtection(to: url, fileManager: fileManager, excludedFromBackup: excludedFromBackup)

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for case let itemURL as URL in enumerator {
            try applyProtection(to: itemURL, fileManager: fileManager, excludedFromBackup: excludedFromBackup)
        }
    }

    private static func setBackupExclusion(_ excluded: Bool, for url: URL) throws {
        var mutableURL = url
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = excluded
        try mutableURL.setResourceValues(resourceValues)
    }
}

nonisolated enum TemporaryExportFileLifecycle {
    static let expirationInterval: TimeInterval = 60 * 60 * 24

    static let managedFilePrefixes = [
        "Symi-Bericht-",
        "schmerztagebuch-export-",
        "sync-log-"
    ]

    static func prepareProtectedTemporaryFile(
        at url: URL,
        fileManager: FileManager = .default,
        now: Date = .now
    ) throws {
        try cleanupExpiredFiles(fileManager: fileManager, now: now)

        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    static func finalizeProtectedTemporaryFile(
        at url: URL,
        fileManager: FileManager = .default
    ) throws {
        try ProtectedFileStorage.applyProtection(to: url, fileManager: fileManager, excludedFromBackup: true)
    }

    static func cleanupManagedFile(at url: URL?, fileManager: FileManager = .default) {
        guard let url, isManagedTemporaryFile(url) else {
            return
        }

        try? fileManager.removeItem(at: url)
    }

    static func cleanupExpiredFiles(
        fileManager: FileManager = .default,
        now: Date = .now
    ) throws {
        let temporaryDirectory = fileManager.temporaryDirectory
        let fileURLs = try fileManager.contentsOfDirectory(
            at: temporaryDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        for fileURL in fileURLs where isManagedTemporaryFile(fileURL) {
            let resourceValues = try fileURL.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard resourceValues.isRegularFile == true else {
                continue
            }

            let modificationDate = resourceValues.contentModificationDate ?? .distantPast
            if now.timeIntervalSince(modificationDate) > expirationInterval {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }

    static func isManagedTemporaryFile(_ url: URL, fileManager: FileManager = .default) -> Bool {
        url.deletingLastPathComponent().standardizedFileURL == fileManager.temporaryDirectory.standardizedFileURL
            && managedFilePrefixes.contains { url.lastPathComponent.hasPrefix($0) }
    }
}
