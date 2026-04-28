import Foundation

final class HealthContextStore: Sendable {
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

    nonisolated func load(for episodeID: UUID) -> HealthContextRecord? {
        let url = fileURL(for: episodeID)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: url), let snapshot = try? decoder.decode(HealthContextSnapshotData.self, from: data) else {
            return nil
        }

        return HealthContextRecord(snapshot: snapshot)
    }

    nonisolated private func fileURL(for episodeID: UUID) -> URL {
        directoryURL.appendingPathComponent("\(episodeID.uuidString).json")
    }
}
