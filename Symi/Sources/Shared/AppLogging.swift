import Foundation
import Sentry

public enum AppLogCategory: String, Codable, CaseIterable, Sendable {
    case sync
    case app
}

public enum AppLogLevel: String, Codable, CaseIterable, Sendable {
    case debug
    case info
    case warning
    case error
    case critical
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
    private let remoteReporter: AppLogRemoteReporting?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var entries: [AppLogEntry]

    public init(
        fileManager: FileManager = .default,
        baseDirectoryURL: URL? = nil,
        retentionWindow: TimeInterval = 60 * 60 * 24 * 7,
        maxEntryCount: Int = 3000,
        remoteReporter: AppLogRemoteReporting? = nil
    ) {
        self.retentionWindow = retentionWindow
        self.maxEntryCount = maxEntryCount
        self.remoteReporter = remoteReporter

        let baseURL = baseDirectoryURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directoryURL = baseURL.appendingPathComponent("Symi", isDirectory: true)
        try? ProtectedFileStorage.createProtectedDirectory(at: directoryURL, fileManager: fileManager)

        self.fileURL = directoryURL.appendingPathComponent("app-log.ndjson")
        self.snapshotDirectoryURL = directoryURL.appendingPathComponent("Snapshots", isDirectory: true)
        try? ProtectedFileStorage.createProtectedDirectory(at: snapshotDirectoryURL, fileManager: fileManager)
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
        let entry = AppLogEntry(
            category: category,
            level: level,
            operation: operation,
            message: message,
            metadata: metadata.sorted { $0.key < $1.key }.reduce(into: [:]) { partialResult, item in
                partialResult[item.key] = item.value
            }
        )
        entries.append(entry)
        pruneAndPersist()
        remoteReporter?.record(entry)
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
            try ProtectedFileStorage.applyProtection(to: exportURL, excludedFromBackup: true)
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
            entries.filter { $0.level == .error || $0.level == .critical }
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
                try ProtectedFileStorage.applyProtection(to: fileURL, fileManager: fileManager)
            }
        } catch {
            // Logging darf den App-Fluss nicht blockieren.
        }
    }
}

public protocol AppLogRemoteReporting: Sendable {
    nonisolated func record(_ entry: AppLogEntry)
}

public enum AppRemoteLogLevel: String, Equatable, Sendable {
    case debug
    case info
    case warning
    case error
    case fatal
}

public struct AppRemoteLogBreadcrumb: Equatable, Sendable {
    public nonisolated let level: AppRemoteLogLevel
    public nonisolated let category: String
    public nonisolated let message: String
    public nonisolated let data: [String: String]
}

public struct AppRemoteLogEvent: Equatable, Sendable {
    public nonisolated let level: AppRemoteLogLevel
    public nonisolated let message: String
    public nonisolated let extra: [String: String]
}

public protocol AppSentryClient: Sendable {
    nonisolated func addBreadcrumb(_ breadcrumb: AppRemoteLogBreadcrumb)
    nonisolated func captureEvent(_ event: AppRemoteLogEvent)
}

public final class AppSentryLogReporter: AppLogRemoteReporting, @unchecked Sendable {
    public nonisolated static let shared = AppSentryLogReporter(client: SentrySDKLogClient())

    private let lock = NSLock()
    private let client: AppSentryClient
    private let sanitizer: AppLogSanitizing
    nonisolated(unsafe) private var isEnabled = false

    public nonisolated init(client: AppSentryClient, sanitizer: AppLogSanitizing = AppLogSanitizer()) {
        self.client = client
        self.sanitizer = sanitizer
    }

    public nonisolated func setEnabled(_ enabled: Bool) {
        lock.withLock {
            unsafe isEnabled = enabled
        }
    }

    public nonisolated func record(_ entry: AppLogEntry) {
        guard lock.withLock({ unsafe isEnabled }) else {
            return
        }

        let sanitizedEntry = sanitizer.sanitize(entry)
        let context = Self.context(from: sanitizedEntry)
        let breadcrumb = AppRemoteLogBreadcrumb(
            level: sanitizedEntry.level.remoteLevel,
            category: sanitizedEntry.category.rawValue,
            message: sanitizedEntry.message,
            data: context
        )
        client.addBreadcrumb(breadcrumb)

        guard sanitizedEntry.level.sendsSentryEvent else {
            return
        }

        client.captureEvent(
            AppRemoteLogEvent(
                level: sanitizedEntry.level.remoteLevel,
                message: sanitizedEntry.message,
                extra: context
            )
        )
    }

    private nonisolated static func context(from entry: AppLogEntry) -> [String: String] {
        var context = entry.metadata
        context["operation"] = entry.operation
        context["category"] = entry.category.rawValue
        context["level"] = entry.level.rawValue
        return context
    }
}

public protocol AppLogSanitizing: Sendable {
    nonisolated func sanitize(_ entry: AppLogEntry) -> AppLogEntry
}

public struct AppLogSanitizer: AppLogSanitizing {
    private nonisolated static let redactedValue = "[redacted]"
    private nonisolated static let sensitiveKeyFragments = [
        "address",
        "birth",
        "coordinate",
        "diagnosis",
        "dose",
        "email",
        "health",
        "latitude",
        "location",
        "longitude",
        "medication",
        "medicine",
        "name",
        "note",
        "patient",
        "phone",
        "postal",
        "trigger",
        "weather"
    ]

    public nonisolated init() {}

    public nonisolated func sanitize(_ entry: AppLogEntry) -> AppLogEntry {
        AppLogEntry(
            id: entry.id,
            timestamp: entry.timestamp,
            category: entry.category,
            level: entry.level,
            operation: sanitizedText(entry.operation),
            message: sanitizedText(entry.message),
            metadata: entry.metadata.reduce(into: [:]) { partialResult, item in
                partialResult[sanitizedText(item.key)] = sanitizedValue(item.value, forKey: item.key)
            }
        )
    }

    private nonisolated func sanitizedValue(_ value: String, forKey key: String) -> String {
        guard !isSensitiveKey(key) else {
            return Self.redactedValue
        }

        return sanitizedText(value)
    }

    private nonisolated func isSensitiveKey(_ key: String) -> Bool {
        let normalizedKey = key.lowercased()
        return Self.sensitiveKeyFragments.contains { normalizedKey.contains($0) }
    }

    private nonisolated func sanitizedText(_ text: String) -> String {
        var sanitized = text
        sanitized = sanitized.replacing(
            #/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/#,
            with: Self.redactedValue
        )
        sanitized = sanitized.replacing(
            #/\b(?:\+?\d[\d\s().-]{6,}\d)\b/#,
            with: Self.redactedValue
        )
        sanitized = sanitized.replacing(
            #/\b(?:patient|patientin|medikament|medikation|trigger|notiz|standort|adresse|koordinate|diagnose)\b[^.,;\n]*/#.ignoresCase(),
            with: Self.redactedValue
        )
        return sanitized
    }
}

private struct SentrySDKLogClient: AppSentryClient {
    nonisolated func addBreadcrumb(_ breadcrumb: AppRemoteLogBreadcrumb) {
        let sentryBreadcrumb = Breadcrumb(level: breadcrumb.level.sentryLevel, category: breadcrumb.category)
        sentryBreadcrumb.message = breadcrumb.message
        sentryBreadcrumb.type = "log"
        sentryBreadcrumb.data = breadcrumb.data
        SentrySDK.addBreadcrumb(sentryBreadcrumb)
    }

    nonisolated func captureEvent(_ event: AppRemoteLogEvent) {
        let sentryEvent = Event(level: event.level.sentryLevel)
        sentryEvent.message = SentryMessage(formatted: event.message)
        sentryEvent.logger = "Symi.AppLog"
        sentryEvent.extra = event.extra
        SentrySDK.capture(event: sentryEvent)
    }
}

private extension AppLogLevel {
    nonisolated var remoteLevel: AppRemoteLogLevel {
        switch self {
        case .debug:
            .debug
        case .info:
            .info
        case .warning:
            .warning
        case .error:
            .error
        case .critical:
            .fatal
        }
    }

    nonisolated var sendsSentryEvent: Bool {
        self == .error || self == .critical
    }
}

private extension AppRemoteLogLevel {
    nonisolated var sentryLevel: SentryLevel {
        switch self {
        case .debug:
            .debug
        case .info:
            .info
        case .warning:
            .warning
        case .error:
            .error
        case .fatal:
            .fatal
        }
    }
}
