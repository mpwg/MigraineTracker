import Foundation
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
    timeout: Duration = .seconds(10),
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

private final class SpyExportRepository: ExportRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var lockedSummaryRequests: [SpyDateRange] = []
    private var lockedPDFSummaries: [ExportPeriodSummary] = []

    var summaryRequests: [SpyDateRange] {
        lock.withLock { lockedSummaryRequests }
    }

    var pdfSummaries: [ExportPeriodSummary] {
        lock.withLock { lockedPDFSummaries }
    }

    nonisolated func buildSummary(startDate: Date, endDate: Date) throws -> ExportPeriodSummary {
        lock.withLock {
            lockedSummaryRequests.append(SpyDateRange(startDate: startDate, endDate: endDate))
        }

        return ExportPeriodSummary(
            startDate: startDate,
            endDate: endDate,
            records: [makeRecord(startedAt: startDate)]
        )
    }

    nonisolated func createPDF(summary: ExportPeriodSummary, mode: PDFReportMode) throws -> URL {
        lock.withLock {
            lockedPDFSummaries.append(summary)
        }
        return FileManager.default.temporaryDirectory.appendingPathComponent("report-\(UUID().uuidString).pdf")
    }

    nonisolated func createBackup() throws -> URL {
        throw DataTransferError.invalidFormat
    }

    nonisolated func previewBackupImport(from url: URL) throws -> BackupImportPreview {
        throw DataTransferError.invalidFormat
    }

    nonisolated func importBackup(from url: URL) throws -> BackupImportResult {
        throw DataTransferError.invalidFormat
    }
}
