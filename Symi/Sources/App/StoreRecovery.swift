import Foundation
import SwiftData
import SwiftUI

nonisolated enum PersistentStoreRecoveryReason: String, Equatable, Sendable {
    case unknownModelVersion
    case migrationFailure
    case loadFailure

    var headline: String {
        switch self {
        case .unknownModelVersion:
            "Der lokale Datenspeicher stammt aus einer neueren oder unbekannten App-Version."
        case .migrationFailure:
            "Der lokale Datenspeicher konnte nicht migriert werden."
        case .loadFailure:
            "Der lokale Datenspeicher konnte nicht geöffnet werden."
        }
    }

    var explanation: String {
        switch self {
        case .unknownModelVersion:
            "Symi hat den vorhandenen Store nicht ersetzt. Du kannst die Dateien sichern und später mit einer passenden App-Version erneut öffnen."
        case .migrationFailure:
            "Symi hat die Migration gestoppt und keine Store-Dateien gelöscht. Sichere die Dateien, bevor du weitere Schritte setzt."
        case .loadFailure:
            "Symi startet in einem geschützten Wiederherstellungsmodus. Der vorhandene Store bleibt unverändert, solange du keine Löschung bestätigst."
        }
    }
}

nonisolated struct PersistentStoreRecoveryContext: Equatable, Sendable {
    let storeURL: URL
    let reason: PersistentStoreRecoveryReason
    let errorSummary: String
}

nonisolated enum PersistentStoreLoadError: Error, Equatable {
    case recoveryRequired(PersistentStoreRecoveryContext)
}

nonisolated enum PersistentStoreRecoveryFileError: LocalizedError, Equatable {
    case noStoreFilesFound

    var errorDescription: String? {
        switch self {
        case .noStoreFilesFound:
            "Es wurden keine Store-Dateien gefunden, die gesichert werden können."
        }
    }
}

nonisolated enum PersistentStoreRecoveryService {
    static let unknownModelVersionErrorCode = 134504
    static let migrationErrorCodeRange = 134100...134199

    static func recoveryContext(for error: Error, storeURL: URL) -> PersistentStoreRecoveryContext {
        PersistentStoreRecoveryContext(
            storeURL: storeURL,
            reason: recoveryReason(for: error),
            errorSummary: sanitizedSummary(for: error)
        )
    }

    static func recoveryReason(for error: Error) -> PersistentStoreRecoveryReason {
        let nsError = error as NSError
        let description = [
            String(describing: error),
            nsError.localizedDescription
        ]
        .joined(separator: " ")
        .lowercased()

        if nsError.domain == NSCocoaErrorDomain, nsError.code == unknownModelVersionErrorCode {
            return .unknownModelVersion
        }

        if description.contains("unknown model version")
            || description.contains("loadissuemodelcontainer")
            || description.contains(String(unknownModelVersionErrorCode)) {
            return .unknownModelVersion
        }

        if nsError.domain == NSCocoaErrorDomain, migrationErrorCodeRange.contains(nsError.code) {
            return .migrationFailure
        }

        if description.contains("migration") || description.contains("migrate") || description.contains("incompatible version hash") {
            return .migrationFailure
        }

        return .loadFailure
    }

    static func existingStoreFileURLs(for storeURL: URL, fileManager: FileManager = .default) -> [URL] {
        storeFileCandidates(for: storeURL).filter { fileManager.fileExists(atPath: $0.path) }
    }

    static func copyStoreFilesForSharing(
        from storeURL: URL,
        fileManager: FileManager = .default,
        now: Date = .now
    ) throws -> [URL] {
        let sourceURLs = existingStoreFileURLs(for: storeURL, fileManager: fileManager)
        guard !sourceURLs.isEmpty else {
            throw PersistentStoreRecoveryFileError.noStoreFilesFound
        }

        let targetDirectory = fileManager.temporaryDirectory
            .appending(path: "Symi-Store-Sicherung-\(fileDateString(from: now))-\(UUID().uuidString)", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)

        return try sourceURLs.map { sourceURL in
            let targetURL = targetDirectory.appending(path: sourceURL.lastPathComponent)
            if fileManager.fileExists(atPath: targetURL.path) {
                try fileManager.removeItem(at: targetURL)
            }
            try fileManager.copyItem(at: sourceURL, to: targetURL)
            return targetURL
        }
    }

    static func removeStoreFilesAfterUserConfirmation(
        at storeURL: URL,
        fileManager: FileManager = .default
    ) throws {
        for url in existingStoreFileURLs(for: storeURL, fileManager: fileManager) {
            try fileManager.removeItem(at: url)
        }
    }

    private static func sanitizedSummary(for error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.domain) \(nsError.code)"
    }

    private static func storeFileCandidates(for storeURL: URL) -> [URL] {
        let directoryURL = storeURL.deletingLastPathComponent()
        let storeFileName = storeURL.lastPathComponent

        return [
            storeURL,
            directoryURL.appending(path: "\(storeFileName)-shm"),
            directoryURL.appending(path: "\(storeFileName)-wal"),
            directoryURL.appending(path: "\(storeFileName)_SUPPORT", directoryHint: .isDirectory)
        ]
    }

    private static func fileDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: date)
    }
}

struct StoreRecoveryView: View {
    let context: PersistentStoreRecoveryContext
    let prepareStoreBackup: () throws -> [URL]
    let startEmptyStore: @MainActor () throws -> AppRuntimeEnvironment
    let didRecover: @MainActor (AppRuntimeEnvironment) -> Void

    @State private var backupFileURLs: [URL] = []
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var isPreparingBackup = false
    @State private var isStartingEmptyStore = false
    @State private var showsDestructiveConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Lokale Daten wurden nicht gelöscht", systemImage: "externaldrive.badge.exclamationmark")
                            .font(.headline)
                            .foregroundStyle(AppTheme.symiPetrol)

                        Text(context.reason.headline)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.symiTextPrimary)

                        Text(context.reason.explanation)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.symiTextSecondary)
                    }
                    .padding(.vertical, 6)
                }

                Section("Sicherung und Migration") {
                    Text("Sichere die vorhandenen Store-Dateien, bevor du Symi mit einem leeren Store startest. Ohne Löschbestätigung bleiben die Dateien an ihrem aktuellen Ort.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button {
                        prepareBackup()
                    } label: {
                        Label(isPreparingBackup ? "Sicherung wird vorbereitet" : "Store-Dateien sichern", systemImage: "externaldrive.badge.plus")
                    }
                    .disabled(isPreparingBackup || isStartingEmptyStore)

                    if !backupFileURLs.isEmpty {
                        ShareLink(items: backupFileURLs) {
                            Label("Sicherung teilen", systemImage: "square.and.arrow.up")
                        }
                    }

                    Button {
                        statusMessage = "Es wurde nichts geändert. Du kannst Symi nach einem Update erneut öffnen oder die Store-Dateien vorher sichern."
                        errorMessage = nil
                    } label: {
                        Label("Später migrieren", systemImage: "clock.arrow.circlepath")
                    }
                    .disabled(isStartingEmptyStore)
                }

                Section("Leerer Neustart") {
                    Text("Diese Option entfernt die lokalen Store-Dateien erst nach deiner Bestätigung und erstellt danach einen neuen leeren Store.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button(role: .destructive) {
                        showsDestructiveConfirmation = true
                    } label: {
                        Label(isStartingEmptyStore ? "Leerer Store wird erstellt" : "Mit leerem Store starten", systemImage: "trash")
                    }
                    .disabled(isPreparingBackup || isStartingEmptyStore)
                }

                if let statusMessage {
                    Section {
                        Text(statusMessage)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.symiTextSecondary)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.symiCoral)
                    }
                }
            }
            .navigationTitle("Daten wiederherstellen")
            .brandGroupedScreen()
            .confirmationDialog(
                "Lokale Store-Dateien löschen?",
                isPresented: $showsDestructiveConfirmation,
                titleVisibility: .visible
            ) {
                Button("Store-Dateien löschen und leer starten", role: .destructive) {
                    startWithEmptyStore()
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Diese Aktion löscht den lokalen SwiftData-Store auf diesem Gerät. Eine spätere Migration ist nur möglich, wenn du die Store-Dateien vorher gesichert hast.")
            }
        }
    }

    private func prepareBackup() {
        isPreparingBackup = true
        statusMessage = nil
        errorMessage = nil

        do {
            backupFileURLs = try prepareStoreBackup()
            statusMessage = "Die Store-Dateien wurden für die Sicherung vorbereitet."
        } catch {
            errorMessage = userFacingMessage(for: error)
        }

        isPreparingBackup = false
    }

    private func startWithEmptyStore() {
        isStartingEmptyStore = true
        statusMessage = nil
        errorMessage = nil

        do {
            let environment = try startEmptyStore()
            didRecover(environment)
        } catch {
            errorMessage = userFacingMessage(for: error)
            isStartingEmptyStore = false
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription {
            return description
        }

        let nsError = error as NSError
        return "Der Vorgang konnte nicht abgeschlossen werden. Fehlercode: \(nsError.domain) \(nsError.code)"
    }
}

#Preview {
    StoreRecoveryView(
        context: PersistentStoreRecoveryContext(
            storeURL: URL(fileURLWithPath: "/tmp/default.store"),
            reason: .unknownModelVersion,
            errorSummary: "NSCocoaErrorDomain \(PersistentStoreRecoveryService.unknownModelVersionErrorCode)"
        ),
        prepareStoreBackup: { [] },
        startEmptyStore: {
            throw PersistentStoreRecoveryFileError.noStoreFilesFound
        },
        didRecover: { _ in }
    )
}
