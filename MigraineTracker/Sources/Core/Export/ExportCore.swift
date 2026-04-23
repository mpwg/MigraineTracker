import Foundation
import Observation

protocol ExportRepository {
    func buildSummary(startDate: Date, endDate: Date) throws -> ExportPeriodSummary
    func createPDF(summary: ExportPeriodSummary, mode: PDFReportMode) throws -> URL
    func createBackup() throws -> URL
    func importBackup(from url: URL) throws
}

enum PDFReportMode: String, CaseIterable, Identifiable {
    case compact = "Kompakter Arztbericht"
    case detailed = "Detaillierter Bericht"

    var id: String { rawValue }
}

struct LoadExportPreviewUseCase {
    let repository: ExportRepository

    func execute(startDate: Date, endDate: Date) throws -> ExportPeriodSummary {
        try repository.buildSummary(startDate: startDate, endDate: endDate)
    }
}

struct CreatePDFExportUseCase {
    let repository: ExportRepository

    func execute(summary: ExportPeriodSummary, mode: PDFReportMode) throws -> URL {
        try repository.createPDF(summary: summary, mode: mode)
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
    var includeAllDetails = false
    private(set) var summary = ExportPeriodSummary(startDate: .now, endDate: .now, records: [])

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
        reloadSummary()
    }

    var canExport: Bool {
        !summary.records.isEmpty && startDate <= endDate
    }

    var pdfReportMode: PDFReportMode {
        includeAllDetails ? .detailed : .compact
    }

    func reloadSummary() {
        do {
            summary = try loadExportPreviewUseCase.execute(startDate: startDate, endDate: endDate)
        } catch {
            summary = ExportPeriodSummary(startDate: startDate, endDate: endDate, records: [])
        }

        updatePreparedPDF()
    }

    func createPDF() {
        updatePreparedPDF()
    }

    func updatePreparedPDF() {
        exportErrorMessage = nil
        exportURL = nil

        guard startDate <= endDate else {
            exportErrorMessage = "Der Zeitraum ist ungültig."
            return
        }

        guard !summary.records.isEmpty else {
            exportErrorMessage = "Für den gewählten Zeitraum gibt es keine Episoden."
            return
        }

        do {
            exportURL = try createPDFExportUseCase.execute(summary: summary, mode: pdfReportMode)
        } catch {
            exportErrorMessage = "Der PDF-Export konnte nicht erstellt werden."
        }
    }

    func createBackup() {
        dataTransferMessage = nil
        dataExportURL = nil

        do {
            dataExportURL = try createBackupUseCase.execute()
            dataTransferMessage = "JSON5-Datei wurde lokal erstellt."
        } catch {
            dataTransferMessage = "Fehler beim Erstellen der JSON5-Datei."
        }
    }

    func importBackup(from result: Result<URL, Error>) {
        dataTransferMessage = nil

        do {
            let url = try result.get()
            try importBackupUseCase.execute(url: url)
            dataTransferMessage = "JSON5-Daten wurden importiert."
            reloadSummary()
        } catch CocoaError.userCancelled {
            return
        } catch {
            dataTransferMessage = "Fehler beim Import der JSON5-Datei."
        }
    }

    private static func defaultDateRange(calendar: Calendar = .current, now: Date = .now) -> (startDate: Date, endDate: Date) {
        let startOfCurrentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let startDate = calendar.date(byAdding: .month, value: -2, to: startOfCurrentMonth) ?? now
        return (startDate, now)
    }
}
