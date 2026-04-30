import Foundation

struct HealthContextSidecarChange: Sendable {
    let episodeID: UUID
    let snapshot: HealthContextSnapshotData?
}

final class HealthContextStore: Sendable {
    enum LoadError: LocalizedError {
        case unreadableSidecar(episodeID: UUID, underlyingError: Error)

        var errorDescription: String? {
            switch self {
            case let .unreadableSidecar(episodeID, _):
                return "Der Apple-Health-Kontext für Eintrag \(episodeID.uuidString) konnte nicht gelesen werden."
            }
        }
    }

    private let directoryURL: URL

    init(baseURL: URL? = nil) {
        let root = baseURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        self.directoryURL = root
            .appendingPathComponent("Symi", isDirectory: true)
            .appendingPathComponent("HealthContext", isDirectory: true)
    }

    nonisolated func save(_ snapshot: HealthContextSnapshotData?, for episodeID: UUID) throws {
        let url = fileURL(for: episodeID)

        guard let snapshot else {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            return
        }

        try ProtectedFileStorage.createProtectedDirectory(at: directoryURL)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
        try ProtectedFileStorage.applyProtection(to: url)
    }

    nonisolated func save(_ changes: [HealthContextSidecarChange], committing commit: () throws -> Void) throws {
        guard !changes.isEmpty else {
            try commit()
            return
        }

        let backupDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Symi-HealthContext-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: backupDirectoryURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: backupDirectoryURL)
        }

        let backups = try sidecarBackups(for: changes.map(\.episodeID), in: backupDirectoryURL)

        do {
            for change in changes {
                try save(change.snapshot, for: change.episodeID)
            }

            try commit()
        } catch {
            try? restoreSidecars(from: backups)
            throw error
        }
    }

    nonisolated func load(for episodeID: UUID) -> HealthContextRecord? {
        try? loadIfPresent(for: episodeID)
    }

    nonisolated func loadIfPresent(for episodeID: UUID) throws -> HealthContextRecord? {
        let url = fileURL(for: episodeID)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try Data(contentsOf: url)
            let snapshot = try decoder.decode(HealthContextSnapshotData.self, from: data)
            return HealthContextRecord(snapshot: snapshot)
        } catch {
            throw LoadError.unreadableSidecar(episodeID: episodeID, underlyingError: error)
        }
    }

    nonisolated private func fileURL(for episodeID: UUID) -> URL {
        directoryURL.appendingPathComponent("\(episodeID.uuidString).json")
    }

    nonisolated private func sidecarBackups(for episodeIDs: [UUID], in backupDirectoryURL: URL) throws -> [SidecarBackup] {
        try Array(Set(episodeIDs)).map { episodeID in
            let originalURL = fileURL(for: episodeID)
            let backupURL = backupDirectoryURL.appendingPathComponent("\(episodeID.uuidString).json")

            guard FileManager.default.fileExists(atPath: originalURL.path) else {
                return SidecarBackup(originalURL: originalURL, backupURL: nil)
            }

            try FileManager.default.copyItem(at: originalURL, to: backupURL)
            return SidecarBackup(originalURL: originalURL, backupURL: backupURL)
        }
    }

    nonisolated private func restoreSidecars(from backups: [SidecarBackup]) throws {
        for backup in backups {
            if FileManager.default.fileExists(atPath: backup.originalURL.path) {
                try FileManager.default.removeItem(at: backup.originalURL)
            }

            if let backupURL = backup.backupURL {
                try ProtectedFileStorage.createProtectedDirectory(at: directoryURL)
                try FileManager.default.copyItem(at: backupURL, to: backup.originalURL)
                try ProtectedFileStorage.applyProtection(to: backup.originalURL)
            }
        }
    }
}

private struct SidecarBackup {
    let originalURL: URL
    let backupURL: URL?
}
