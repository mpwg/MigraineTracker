import Foundation
import Observation

protocol ExportRepository: Sendable {
    nonisolated func buildSummary(startDate: Date, endDate: Date) throws -> ExportPeriodSummary
    nonisolated func createPDF(summary: ExportPeriodSummary, mode: PDFReportMode) throws -> URL
    func createBackup() throws -> URL
    func importBackup(from url: URL) throws
}

enum PDFReportMode: String, CaseIterable, Identifiable, Sendable {
    case compact = "Kompakter Arztbericht"
    case detailed = "Detaillierter Bericht"

    var id: String { rawValue }
}

struct LoadExportPreviewUseCase {
    let repository: ExportRepository

    func execute(startDate: Date, endDate: Date) async throws -> ExportPeriodSummary {
        let repository = repository
        return try await Task.detached(priority: .userInitiated) {
            try repository.buildSummary(startDate: startDate, endDate: endDate)
        }.value
    }
}

struct CreatePDFExportUseCase {
    let repository: ExportRepository

    func execute(summary: ExportPeriodSummary, mode: PDFReportMode) async throws -> URL {
        let repository = repository
        return try await Task.detached(priority: .userInitiated) {
            try repository.createPDF(summary: summary, mode: mode)
        }.value
    }
}

struct CreateBackupUseCase {
    let repository: ExportRepository

    func execute() throws -> URL {
        try repository.createBackup()
    }
}

struct ImportBackupUseCase {
    let repository: ExportRepository

    func execute(url: URL) throws {
        try repository.importBackup(from: url)
    }
}

@MainActor
@Observable
final class DataExportController {
    var startDate: Date
    var endDate: Date
    var exportURL: URL?
    var exportErrorMessage: String?
    var dataExportURL: URL?
    var dataTransferMessage: String?
    var isImportingData = false
    var isLoadingSummary = false
    var isPreparingPDF = false
    var includeAllDetails = false
    private(set) var summary = ExportPeriodSummary(startDate: .now, endDate: .now, records: [])

    @ObservationIgnored private var hasLoadedInitialSummary = false
    @ObservationIgnored private var summaryReloadTask: Task<Void, Never>?
    @ObservationIgnored private var pdfPreparationTask: Task<Void, Never>?
    private let loadExportPreviewUseCase: LoadExportPreviewUseCase
    private let createPDFExportUseCase: CreatePDFExportUseCase
    private let createBackupUseCase: CreateBackupUseCase
    private let importBackupUseCase: ImportBackupUseCase

    init(repository: ExportRepository) {
        let defaultRange = Self.defaultDateRange()
        self.startDate = defaultRange.startDate
        self.endDate = defaultRange.endDate
        self.loadExportPreviewUseCase = LoadExportPreviewUseCase(repository: repository)
        self.createPDFExportUseCase = CreatePDFExportUseCase(repository: repository)
        self.createBackupUseCase = CreateBackupUseCase(repository: repository)
        self.importBackupUseCase = ImportBackupUseCase(repository: repository)
    }

    var canExport: Bool {
        !summary.records.isEmpty && startDate <= endDate
    }

    var pdfReportMode: PDFReportMode {
        includeAllDetails ? .detailed : .compact
    }

    func loadInitialSummary() {
        guard !hasLoadedInitialSummary else { return }
        hasLoadedInitialSummary = true
        scheduleSummaryReload(debounce: nil)
    }

    func scheduleSummaryReload(debounce: Duration? = .milliseconds(350)) {
        summaryReloadTask?.cancel()
        pdfPreparationTask?.cancel()
        exportURL = nil
        exportErrorMessage = nil
        isLoadingSummary = true
        isPreparingPDF = false

        let requestedStartDate = startDate
        let requestedEndDate = endDate
        summaryReloadTask = Task { [weak self] in
            if let debounce {
                do {
                    try await Task.sleep(for: debounce)
                } catch {
                    return
                }
            }

            await self?.reloadSummary(startDate: requestedStartDate, endDate: requestedEndDate)
        }
    }

    func reloadSummary() async {
        await reloadSummary(startDate: startDate, endDate: endDate)
    }

    private func reloadSummary(startDate requestedStartDate: Date, endDate requestedEndDate: Date) async {
        isLoadingSummary = true
        isPreparingPDF = false
        defer { isLoadingSummary = false }

        guard requestedStartDate <= requestedEndDate else {
            summary = ExportPeriodSummary(startDate: requestedStartDate, endDate: requestedEndDate, records: [])
            exportErrorMessage = "Der Zeitraum ist ungültig."
            return
        }

        do {
            let loadedSummary = try await loadExportPreviewUseCase.execute(
                startDate: requestedStartDate,
                endDate: requestedEndDate
            )
            guard !Task.isCancelled else { return }
            summary = loadedSummary
            exportErrorMessage = nil
            schedulePDFPreparation(delay: .milliseconds(500))
        } catch {
            guard !Task.isCancelled else { return }
            summary = ExportPeriodSummary(startDate: requestedStartDate, endDate: requestedEndDate, records: [])
            exportErrorMessage = "Die Berichtsdaten konnten nicht geladen werden."
        }
    }

    func createPDF() {
        schedulePDFPreparation(delay: nil)
    }

    func schedulePDFPreparation(delay: Duration? = .milliseconds(350)) {
        pdfPreparationTask?.cancel()
        exportURL = nil
        exportErrorMessage = nil

        let requestedSummary = summary
        let requestedMode = pdfReportMode
        let requestedStartDate = startDate
        let requestedEndDate = endDate
        pdfPreparationTask = Task { [weak self] in
            if let delay {
                do {
                    try await Task.sleep(for: delay)
                } catch {
                    return
                }
            }

            await self?.updatePreparedPDF(
                summary: requestedSummary,
                mode: requestedMode,
                startDate: requestedStartDate,
                endDate: requestedEndDate
            )
        }
    }

    func updatePreparedPDF() async {
        await updatePreparedPDF(summary: summary, mode: pdfReportMode, startDate: startDate, endDate: endDate)
    }

    private func updatePreparedPDF(
        summary requestedSummary: ExportPeriodSummary,
        mode requestedMode: PDFReportMode,
        startDate requestedStartDate: Date,
        endDate requestedEndDate: Date
    ) async {
        exportErrorMessage = nil
        exportURL = nil

        guard requestedStartDate <= requestedEndDate else {
            exportErrorMessage = "Der Zeitraum ist ungültig."
            return
        }

        guard !requestedSummary.records.isEmpty else {
            exportErrorMessage = "Für den gewählten Zeitraum gibt es keine Episoden."
            return
        }

        isPreparingPDF = true
        defer { isPreparingPDF = false }
        do {
            let preparedURL = try await createPDFExportUseCase.execute(summary: requestedSummary, mode: requestedMode)
            guard !Task.isCancelled else { return }
            exportURL = preparedURL
        } catch {
            guard !Task.isCancelled else { return }
            exportErrorMessage = "Der PDF-Export konnte nicht erstellt werden."
        }
    }

    func createBackup() {
        dataTransferMessage = nil
        dataExportURL = nil

        Task {
            do {
                dataExportURL = try createBackupUseCase.execute()
                dataTransferMessage = "JSON5-Datei wurde lokal erstellt."
            } catch {
                dataTransferMessage = "Fehler beim Erstellen der JSON5-Datei."
            }
        }
    }

    func importBackup(from result: Result<URL, Error>) {
        dataTransferMessage = nil

        Task {
            do {
                let url = try result.get()
                try importBackupUseCase.execute(url: url)
                dataTransferMessage = "JSON5-Daten wurden importiert."
                await reloadSummary()
            } catch CocoaError.userCancelled {
                return
            } catch {
                dataTransferMessage = "Fehler beim Import der JSON5-Datei."
            }
        }
    }

    private static func defaultDateRange(calendar: Calendar = .current, now: Date = .now) -> (startDate: Date, endDate: Date) {
        let startOfCurrentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let startDate = calendar.date(byAdding: .month, value: -2, to: startOfCurrentMonth) ?? now
        return (startDate, now)
    }
}
