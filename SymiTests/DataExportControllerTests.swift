import Foundation
import os
import Testing
@testable import Symi

@MainActor
struct DataExportControllerTests {
    @Test
    func dateRangeUpdateReloadsSummaryWithSelectedDates() async throws {
        let repository = SpyExportRepository()
        let controller = DataExportController(repository: repository)
        let firstRange = makeDateRange(startDay: 1, endDay: 7)
        let secondRange = makeDateRange(startDay: 8, endDay: 14)

        controller.setDateRange(startDate: firstRange.startDate, endDate: firstRange.endDate, debounce: nil)
        try await waitUntil {
            repository.summaryRequests.count == 1 &&
                controller.summary.startDate == firstRange.startDate &&
                controller.summary.endDate == firstRange.endDate
        }

        controller.setDateRange(startDate: secondRange.startDate, endDate: secondRange.endDate, debounce: nil)
        try await waitUntil {
            repository.summaryRequests.count == 2 &&
                controller.summary.startDate == secondRange.startDate &&
                controller.summary.endDate == secondRange.endDate
        }

        #expect(repository.summaryRequests == [firstRange, secondRange])
        #expect(controller.summary.startDate == secondRange.startDate)
        #expect(controller.summary.endDate == secondRange.endDate)
    }

    @Test
    func createPDFUsesSummaryForSelectedDateRange() async throws {
        let repository = SpyExportRepository()
        let controller = DataExportController(repository: repository)
        let selectedRange = makeDateRange(startDay: 3, endDay: 10)

        controller.setDateRange(startDate: selectedRange.startDate, endDate: selectedRange.endDate, debounce: nil)
        try await waitUntil {
            repository.summaryRequests.count == 1 &&
                controller.summary.startDate == selectedRange.startDate &&
                controller.summary.endDate == selectedRange.endDate
        }

        controller.createPDF()
        try await waitUntil { repository.pdfSummaries.count == 1 }

        let pdfSummary = try #require(repository.pdfSummaries.first)
        #expect(pdfSummary.startDate == selectedRange.startDate)
        #expect(pdfSummary.endDate == selectedRange.endDate)
    }

    @Test
    func importBackupPreparesPreviewAndConfirmAppliesSelectedFile() async throws {
        let repository = SpyExportRepository()
        let controller = DataExportController(repository: repository)
        let backupURL = URL(fileURLWithPath: "/tmp/symi-backup.json5")
        let rollbackURL = URL(fileURLWithPath: "/tmp/symi-rollback.json5")
        let preview = BackupImportPreview(
            newEpisodes: 2,
            changedEpisodes: 1,
            deletedEpisodes: 0,
            newMedicationDefinitions: 1,
            changedMedicationDefinitions: 0,
            newContinuousMedications: 0,
            changedContinuousMedications: 1,
            conflicts: ["Episode ist lokal neuer als das Backup."],
            dateRange: makePreviewDateRange(),
            exportedAt: makeDateRange(startDay: 1, endDay: 1).startDate
        )
        repository.configureImport(preview: preview, rollbackURL: rollbackURL)

        controller.importBackup(from: .success(backupURL))

        try await waitUntil {
            repository.previewImportURLs == [backupURL] &&
                controller.importPreview == preview
        }

        #expect(controller.dataTransferMessage == "Import-Vorschau erstellt. Bitte prüfen und bestätigen.")

        controller.confirmImport()

        try await waitUntil {
            repository.importURLs == [backupURL] &&
                controller.importRollbackBackupURL == rollbackURL
        }

        #expect(controller.importPreview == nil)
        #expect(controller.dataTransferMessage == "JSON5-Daten wurden importiert. Vorheriger Stand wurde als Rollback-Backup gesichert.")
    }

    @Test
    func importBackupShowsNoChangesPreviewWithoutApplyingImport() async throws {
        let repository = SpyExportRepository()
        let controller = DataExportController(repository: repository)
        let backupURL = URL(fileURLWithPath: "/tmp/symi-backup.json5")
        let preview = BackupImportPreview(
            newEpisodes: 0,
            changedEpisodes: 0,
            deletedEpisodes: 0,
            newMedicationDefinitions: 0,
            changedMedicationDefinitions: 0,
            newContinuousMedications: 0,
            changedContinuousMedications: 0,
            conflicts: [],
            dateRange: nil,
            exportedAt: makeDateRange(startDay: 1, endDay: 1).startDate
        )
        repository.configureImport(preview: preview, rollbackURL: URL(fileURLWithPath: "/tmp/symi-rollback.json5"))

        controller.importBackup(from: .success(backupURL))

        try await waitUntil {
            repository.previewImportURLs == [backupURL] &&
                controller.importPreview == preview
        }

        #expect(controller.dataTransferMessage == "Dry-Run abgeschlossen: Das Backup enthält keine neuen Änderungen.")
        #expect(repository.importURLs.isEmpty)
    }
}

private struct SpyDateRange: Equatable, Sendable {
    let startDate: Date
    let endDate: Date
}

private func makeDateRange(startDay: Int, endDay: Int) -> SpyDateRange {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let startDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: startDay, hour: 9))!
    let endDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: endDay, hour: 18))!
    return SpyDateRange(startDate: startDate, endDate: endDate)
}

private func makePreviewDateRange() -> BackupImportPreview.DateRange {
    let dateRange = makeDateRange(startDay: 4, endDay: 11)
    return BackupImportPreview.DateRange(start: dateRange.startDate, end: dateRange.endDate)
}

private func makeRecord(startedAt: Date) -> EpisodeExportRecord {
    EpisodeExportRecord(
        episode: Episode(
            startedAt: startedAt,
            type: .migraine,
            intensity: 6,
            painLocation: "Stirn",
            painCharacter: "Pulsierend"
        ),
        healthContext: nil
    )
}

private func waitUntil(
    timeout: Duration = .seconds(30),
    condition: @MainActor @escaping () -> Bool
) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout

    while !(await condition()) {
        if clock.now >= deadline {
            Issue.record("Bedingung wurde nicht rechtzeitig erfüllt.")
            return
        }
        try await Task.sleep(for: .milliseconds(10))
    }
}

private struct SpyExportRepositoryState: Sendable {
    var summaryRequests: [SpyDateRange] = []
    var pdfSummaries: [ExportPeriodSummary] = []
    var previewImportURLs: [URL] = []
    var importURLs: [URL] = []
    var importPreview = BackupImportPreview(
        newEpisodes: 0,
        changedEpisodes: 0,
        deletedEpisodes: 0,
        newMedicationDefinitions: 0,
        changedMedicationDefinitions: 0,
        newContinuousMedications: 0,
        changedContinuousMedications: 0,
        conflicts: [],
        dateRange: nil,
        exportedAt: Date(timeIntervalSince1970: 0)
    )
    var rollbackURL = URL(fileURLWithPath: "/tmp/symi-rollback.json5")
}

private final class SpyExportRepository: ExportRepository {
    private let state = OSAllocatedUnfairLock(initialState: SpyExportRepositoryState())

    var summaryRequests: [SpyDateRange] {
        state.withLock { $0.summaryRequests }
    }

    var pdfSummaries: [ExportPeriodSummary] {
        state.withLock { $0.pdfSummaries }
    }

    var previewImportURLs: [URL] {
        state.withLock { $0.previewImportURLs }
    }

    var importURLs: [URL] {
        state.withLock { $0.importURLs }
    }

    func configureImport(preview: BackupImportPreview, rollbackURL: URL) {
        state.withLock {
            $0.importPreview = preview
            $0.rollbackURL = rollbackURL
        }
    }

    nonisolated func buildSummary(startDate: Date, endDate: Date) throws -> ExportPeriodSummary {
        state.withLock {
            $0.summaryRequests.append(SpyDateRange(startDate: startDate, endDate: endDate))
        }

        return ExportPeriodSummary(
            startDate: startDate,
            endDate: endDate,
            records: [makeRecord(startedAt: startDate)]
        )
    }

    nonisolated func createPDF(summary: ExportPeriodSummary, mode: PDFReportMode) throws -> URL {
        state.withLock {
            $0.pdfSummaries.append(summary)
        }
        return FileManager.default.temporaryDirectory.appendingPathComponent("report-\(UUID().uuidString).pdf")
    }

    nonisolated func createBackup() throws -> URL {
        throw DataTransferError.invalidFormat
    }

    nonisolated func previewBackupImport(from url: URL) throws -> BackupImportPreview {
        state.withLock {
            $0.previewImportURLs.append(url)
            return $0.importPreview
        }
    }

    nonisolated func importBackup(from url: URL) throws -> BackupImportResult {
        state.withLock {
            $0.importURLs.append(url)
            return BackupImportResult(preview: $0.importPreview, rollbackBackupURL: $0.rollbackURL)
        }
    }
}
