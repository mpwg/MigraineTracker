import Foundation

public enum AppLogCategory: String, Codable, CaseIterable, Sendable {
    case sync
    case app
}

public enum AppLogLevel: String, Codable, CaseIterable, Sendable {
    case debug
    case info
    case warning
    case error
}

public enum AppLogFilter: String, Codable, CaseIterable, Sendable, Identifiable {
    case all
    case errors
    case sync

    public nonisolated var id: Self { self }
}

public struct AppLogEntry: Codable, Equatable, Identifiable, Sendable {
    public nonisolated let id: UUID
    public nonisolated let timestamp: Date
    public nonisolated let category: AppLogCategory
    public nonisolated let level: AppLogLevel
    public nonisolated let operation: String
    public nonisolated let message: String
    public nonisolated let metadata: [String: String]

    public nonisolated init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        category: AppLogCategory,
        level: AppLogLevel,
        operation: String,
        message: String,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.level = level
        self.operation = operation
        self.message = message
        self.metadata = metadata
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case category
        case level
        case operation
        case message
        case metadata
    }

    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            timestamp: try container.decode(Date.self, forKey: .timestamp),
            category: try container.decode(AppLogCategory.self, forKey: .category),
            level: try container.decode(AppLogLevel.self, forKey: .level),
            operation: try container.decode(String.self, forKey: .operation),
            message: try container.decode(String.self, forKey: .message),
            metadata: try container.decode([String: String].self, forKey: .metadata)
        )
    }

    public nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(category, forKey: .category)
        try container.encode(level, forKey: .level)
        try container.encode(operation, forKey: .operation)
        try container.encode(message, forKey: .message)
        try container.encode(metadata, forKey: .metadata)
    }
}

public actor AppLogStore {
    private let retentionWindow: TimeInterval
    private let maxEntryCount: Int
    private let fileURL: URL
    private let snapshotDirectoryURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var entries: [AppLogEntry]

    public init(
        fileManager: FileManager = .default,
        baseDirectoryURL: URL? = nil,
        retentionWindow: TimeInterval = 60 * 60 * 24 * 7,
        maxEntryCount: Int = 3000
    ) {
        self.retentionWindow = retentionWindow
        self.maxEntryCount = maxEntryCount

        let baseURL = baseDirectoryURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directoryURL = baseURL.appendingPathComponent("Symi", isDirectory: true)
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        self.fileURL = directoryURL.appendingPathComponent("app-log.ndjson")
        self.snapshotDirectoryURL = directoryURL.appendingPathComponent("Snapshots", isDirectory: true)
        try? fileManager.createDirectory(at: snapshotDirectoryURL, withIntermediateDirectories: true)
        self.entries = []

        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
        self.entries = Self.prunedEntries(
            Self.loadEntries(from: fileURL, using: decoder),
            retentionWindow: retentionWindow,
            maxEntryCount: maxEntryCount
        )
        Self.persist(entries, to: fileURL, using: encoder, fileManager: fileManager)
    }

    public func log(
        level: AppLogLevel,
        category: AppLogCategory,
        operation: String,
        message: String,
        metadata: [String: String] = [:]
    ) {
        entries.append(
            AppLogEntry(
                category: category,
                level: level,
                operation: operation,
                message: message,
                metadata: metadata.sorted { $0.key < $1.key }.reduce(into: [:]) { partialResult, item in
                    partialResult[item.key] = item.value
                }
            )
        )
        pruneAndPersist()
    }

    public func recentEntries(filter: AppLogFilter = .all, limit: Int = 200) -> [AppLogEntry] {
        Array(filteredEntries(filter).sorted { $0.timestamp > $1.timestamp }.prefix(limit))
    }

    public func latestEntry(filter: AppLogFilter = .all) -> AppLogEntry? {
        filteredEntries(filter).max { $0.timestamp < $1.timestamp }
    }

    public func exportLogFileURL(filter: AppLogFilter = .all) -> URL? {
        let filtered = filteredEntries(filter).sorted { $0.timestamp < $1.timestamp }
        guard !filtered.isEmpty else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let filename = "sync-log-\(formatter.string(from: .now).replacingOccurrences(of: ":", with: "-")).ndjson"
        let exportURL = snapshotDirectoryURL.appendingPathComponent(filename)

        let lines = filtered.compactMap { entry -> String? in
            guard let data = try? encoder.encode(entry) else {
                return nil
            }

            return String(data: data, encoding: .utf8)
        }

        guard !lines.isEmpty else {
            return nil
        }

        do {
            try lines.joined(separator: "\n").appending("\n").write(to: exportURL, atomically: true, encoding: .utf8)
            return exportURL
        } catch {
            return nil
        }
    }

    public func clear() {
        entries.removeAll()
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            // Logging darf den App-Fluss nicht blockieren.
        }
    }

    private func filteredEntries(_ filter: AppLogFilter) -> [AppLogEntry] {
        switch filter {
        case .all:
            entries
        case .errors:
            entries.filter { $0.level == .error }
        case .sync:
            entries.filter { $0.category == .sync }
        }
    }

    private func pruneAndPersist() {
        entries = Self.prunedEntries(entries, retentionWindow: retentionWindow, maxEntryCount: maxEntryCount)
        Self.persist(entries, to: fileURL, using: encoder, fileManager: .default)
    }

    private static func loadEntries(from fileURL: URL, using decoder: JSONDecoder) -> [AppLogEntry] {
        guard
            let content = try? String(contentsOf: fileURL, encoding: .utf8),
            !content.isEmpty
        else {
            return []
        }

        return content
            .split(separator: "\n")
            .compactMap { line in
                guard let data = line.data(using: .utf8) else {
                    return nil
                }

                return try? decoder.decode(AppLogEntry.self, from: data)
            }
    }

    private static func prunedEntries(
        _ entries: [AppLogEntry],
        retentionWindow: TimeInterval,
        maxEntryCount: Int
    ) -> [AppLogEntry] {
        let cutoff = Date(timeIntervalSinceNow: -retentionWindow)
        var pruned = entries
            .filter { $0.timestamp >= cutoff }
            .sorted { $0.timestamp < $1.timestamp }

        if pruned.count > maxEntryCount {
            pruned = Array(pruned.suffix(maxEntryCount))
        }

        return pruned
    }

    private static func persist(
        _ entries: [AppLogEntry],
        to fileURL: URL,
        using encoder: JSONEncoder,
        fileManager: FileManager
    ) {
        let lines = entries.compactMap { entry -> String? in
            guard let data = try? encoder.encode(entry) else {
                return nil
            }

            return String(data: data, encoding: .utf8)
        }

        do {
            if lines.isEmpty {
                if fileManager.fileExists(atPath: fileURL.path) {
                    try fileManager.removeItem(at: fileURL)
                }
            } else {
                try lines.joined(separator: "\n").appending("\n").write(to: fileURL, atomically: true, encoding: .utf8)
            }
        } catch {
            // Logging darf den App-Fluss nicht blockieren.
        }
    }
}
