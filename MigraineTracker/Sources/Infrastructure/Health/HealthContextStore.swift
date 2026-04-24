import Foundation

final class HealthContextStore: @unchecked Sendable {
    private let directoryURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(baseURL: URL? = nil) {
        let root = baseURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        self.directoryURL = root
            .appendingPathComponent("MigraineTracker", isDirectory: true)
            .appendingPathComponent("HealthContext", isDirectory: true)
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    nonisolated func save(_ snapshot: HealthContextSnapshotData?, for episodeID: UUID) {
        let url = fileURL(for: episodeID)

        guard let snapshot else {
            try? FileManager.default.removeItem(at: url)
            return
        }

        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: .atomic)
        } catch {}
    }

    nonisolated func load(for episodeID: UUID) -> HealthContextRecord? {
        let url = fileURL(for: episodeID)
        guard let data = try? Data(contentsOf: url), let snapshot = try? decoder.decode(HealthContextSnapshotData.self, from: data) else {
            return nil
        }

        return HealthContextRecord(snapshot: snapshot)
    }

    nonisolated private func fileURL(for episodeID: UUID) -> URL {
        directoryURL.appendingPathComponent("\(episodeID.uuidString).json")
    }
}
