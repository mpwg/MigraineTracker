import CoreGraphics
import CoreText
import Foundation
import ImageIO
import PDFKit
#if canImport(UIKit)
import UIKit
#endif

nonisolated enum PDFExportWriter {
    static func write(summary: ExportPeriodSummary, mode: PDFReportMode = .detailed) throws -> URL {
        let fileName = "\(localized("Symi-Bericht"))-\(dateStamp(summary.startDate))-\(dateStamp(summary.endDate)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let layout = PDFLayout(pageRect: PDFLayout.defaultPageRect)

        try TemporaryExportFileLifecycle.prepareProtectedTemporaryFile(at: url)
        try writeRawPDF(summary: summary, mode: mode, to: url, layout: layout)
        try finalizeDocument(at: url)
        try TemporaryExportFileLifecycle.finalizeProtectedTemporaryFile(at: url)

        return url
    }

    private static func writeRawPDF(summary: ExportPeriodSummary, mode: PDFReportMode, to url: URL, layout: PDFLayout) throws {
        var mediaBox = layout.pageRect
        let documentTitle = localized("Gesundheitsbericht")
        let metadata = [
            kCGPDFContextCreator: ProductBranding.displayName,
            kCGPDFContextAuthor: ProductBranding.displayName,
            kCGPDFContextTitle: documentTitle
        ] as CFDictionary

        guard let consumer = CGDataConsumer(url: url as CFURL),
              let context = unsafe CGContext(consumer: consumer, mediaBox: &mediaBox, metadata)
        else {
            throw PDFExportError.contextCreationFailed
        }

        var page = PDFPageContext(
            context: context,
            layout: layout,
            headerTitle: documentTitle,
            headerSubtitle: localized("Ein Überblick deiner Einträge für dein Arztgespräch"),
            headerPeriod: formatted(
                "Zeitraum: %@ – %@",
                summary.startDate.formatted(date: .abbreviated, time: .omitted),
                summary.endDate.formatted(date: .abbreviated, time: .omitted)
            ),
            headerCreatedAt: formatted("Erstellt am: %@", Date.now.formatted(date: .abbreviated, time: .omitted)),
            headerLogo: homeBrandLogo(),
            footerTitle: localized("Erstellt mit Symi"),
            footerBody: localized("Symi hilft, Symptome besser zu verstehen"),
            appStoreBadge: appStoreBadge(),
            footerQRCode: appStoreQRCode()
        )
        page.beginPage()
        try page.drawSummaryCard(metrics: summaryMetrics(for: summary))
        page.addSpacing(12)
        try page.drawInsightBlock(text: insightText(for: summary))
        page.addSpacing(14)
        try page.drawIntensityTimeline(records: summary.records.sorted { $0.startedAt < $1.startedAt })
        page.addSpacing(14)
        try drawPatternSummary(summary: summary, on: &page)

        page.startNewPage()
        try page.drawEntrySection(records: summary.records.sorted { $0.startedAt < $1.startedAt }, includeAllDetails: mode == .detailed)

        page.endPage()
        context.closePDF()
    }

    private static func finalizeDocument(at url: URL) throws {
        guard let document = PDFDocument(url: url), document.pageCount > 0 else {
            throw PDFExportError.documentValidationFailed
        }
        let documentTitle = localized("Gesundheitsbericht")

        document.documentAttributes = [
            PDFDocumentAttribute.titleAttribute: documentTitle,
            PDFDocumentAttribute.authorAttribute: ProductBranding.displayName,
            PDFDocumentAttribute.creatorAttribute: ProductBranding.displayName
        ]

        guard let data = document.dataRepresentation() else {
            throw PDFExportError.documentValidationFailed
        }

        try data.write(to: url, options: .atomic)
        try TemporaryExportFileLifecycle.finalizeProtectedTemporaryFile(at: url)
    }

    private static func summaryMetrics(for summary: ExportPeriodSummary) -> [PDFMetricTile] {
        let strongestRecord = summary.records.max(by: { $0.intensity < $1.intensity })
        let strongestValue = strongestRecord.map {
            "\($0.intensity)/10"
        } ?? "–"
        let medicationValue = summary.medicationNames.isEmpty ? "–" : "\(summary.medicationNames.count)"

        return [
            PDFMetricTile(icon: "◦", value: "\(painDayCount(for: summary.records))", label: localized("Schmerztage im Zeitraum")),
            PDFMetricTile(icon: "◦", value: summary.episodeCount > 0 ? summary.averageIntensity.formatted(.number.precision(.fractionLength(1))) : "–", label: localized("Durchschnittliche Intensität")),
            PDFMetricTile(icon: "◦", value: strongestValue, label: localized("Stärkste Episode")),
            PDFMetricTile(icon: "◦", value: "\(summary.episodeCount)", label: localized("Dokumentierte Einträge")),
            PDFMetricTile(icon: "◦", value: medicationValue, label: localized("Dokumentierte Medikamente"))
        ]
    }

    private static func drawPatternSummary(summary: ExportPeriodSummary, on page: inout PDFPageContext) throws {
        let symptoms = topValues(summary.records.flatMap(\.symptoms), limit: 3)
        let triggers = topValues(summary.records.flatMap(\.triggers), limit: 3)
        let medications = topValues(summary.records.flatMap { $0.medications.map(\.name) }, limit: 3)
        guard !symptoms.isEmpty || !triggers.isEmpty || !medications.isEmpty else { return }
        try page.drawPatternSummary(symptoms: symptoms, triggers: triggers, medications: medications)
    }

    private static func insightText(for summary: ExportPeriodSummary) -> String {
        let painDays = painDayCount(for: summary.records)
        if summary.episodeCount == 0 {
            return localized("Im ausgewählten Zeitraum wurden keine Einträge dokumentiert.")
        }

        let average = summary.averageIntensity.formatted(.number.precision(.fractionLength(1)))
        return formatted(
            "Im Zeitraum wurden %lld Einträge an %lld Schmerztagen dokumentiert. Die durchschnittliche Intensität lag bei %@/10.",
            Int64(summary.episodeCount),
            Int64(painDays),
            average
        )
    }

    private static func homeBrandLogo() -> CGImage? {
        loadAssetImage(named: "HomeBrandLogo")
            ?? loadBundleImage(named: "PDFBrandLogo", extension: "webp")
            ?? loadBundleImage(named: "Icon_1024", extension: "png")
    }

    private static func appStoreBadge() -> CGImage? {
        loadAssetImage(named: "DownloadOnTheAppStoreBadge")
    }

    private static func loadBundleImage(named name: String, extension fileExtension: String) -> CGImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: fileExtension),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        else {
            return nil
        }

        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func loadAssetImage(named name: String) -> CGImage? {
        #if canImport(UIKit)
        guard let image = UIImage(named: name) else { return nil }
        if let cgImage = image.cgImage {
            return cgImage
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 2
        let size = image.size == .zero ? CGSize(width: 240, height: 80) : image.size
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
        #else
        return nil
        #endif
    }

    private static func appStoreQRCode() -> CGImage? {
        loadAssetImage(named: "AppStoreQRCode")
    }

    private static func localized(_ key: String) -> String {
        key
    }

    private static func formatted(_ key: String, _ arguments: CVarArg...) -> String {
        unsafe String(format: localized(key), arguments: arguments)
    }

    fileprivate static func localizedExportValue(_ value: String) -> String {
        switch value {
        case EpisodeType.migraine.rawValue, "Migräne":
            return EpisodeType.migraine.displayName
        case EpisodeType.headache.rawValue, "Kopfschmerz":
            return EpisodeType.headache.displayName
        case EpisodeType.unclear.rawValue, "Unklar":
            return EpisodeType.unclear.displayName
        case MedicationCategory.triptan.rawValue, "Triptan":
            return MedicationCategory.triptan.displayName
        case MedicationCategory.nsar.rawValue, "nsar", "NSAR":
            return MedicationCategory.nsar.displayName
        case MedicationCategory.paracetamol.rawValue, "Paracetamol":
            return MedicationCategory.paracetamol.displayName
        case MedicationCategory.antiemetic.rawValue, "Antiemetikum":
            return MedicationCategory.antiemetic.displayName
        case MedicationCategory.other.rawValue, "Sonstiges":
            return MedicationCategory.other.displayName
        case MenstruationStatus.unknown.rawValue, "Nicht angegeben":
            return MenstruationStatus.unknown.displayName
        case MenstruationStatus.none.rawValue, "Nein":
            return MenstruationStatus.none.displayName
        case MenstruationStatus.active.rawValue, "Aktuell":
            return MenstruationStatus.active.displayName
        case MenstruationStatus.expected.rawValue, "Erwartet":
            return MenstruationStatus.expected.displayName
        case MedicationEffectiveness.none.rawValue, "Keine":
            return MedicationEffectiveness.none.displayName
        case MedicationEffectiveness.partial.rawValue, "Teilweise":
            return MedicationEffectiveness.partial.displayName
        case MedicationEffectiveness.good.rawValue, "Gut":
            return MedicationEffectiveness.good.displayName
        default:
            return value
        }
    }

    private static func painDayCount(for records: [EpisodeExportRecord]) -> Int {
        Set(records.map { Calendar.current.startOfDay(for: $0.startedAt) }).count
    }

    private static func countRows(_ values: [String], limit: Int) -> [PDFChartRow] {
        topValues(values, limit: limit).map {
            PDFChartRow(label: $0.label, value: $0.count, detail: formatted("%lldx", Int64($0.count)))
        }
    }

    private static func topValues(_ values: [String], limit: Int) -> [PDFPatternItem] {
        Dictionary(grouping: values.filter { !$0.isEmpty }, by: { $0 })
            .map { (label: $0.key, count: $0.value.count) }
            .sorted {
                if $0.count == $1.count {
                    return $0.label.localizedStandardCompare($1.label) == .orderedAscending
                }
                return $0.count > $1.count
            }
            .prefix(limit)
            .map { PDFPatternItem(label: $0.label, count: $0.count) }
    }

    private static func dateStamp(_ date: Date) -> String {
        date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
    }
}

private enum PDFExportError: Error {
    case contextCreationFailed
    case documentValidationFailed
    case drawingFailed
}

nonisolated private struct PDFChartRow {
    let label: String
    let value: Int
    let detail: String
}

nonisolated private struct PDFMetricTile {
    let icon: String
    let value: String
    let label: String
}

nonisolated private struct PDFPatternItem {
    let label: String
    let count: Int
}

nonisolated private struct PDFLayout {
    static let defaultPageWidth: CGFloat = 595
    static let defaultPageHeight: CGFloat = 842
    static let defaultPageRect = CGRect(x: 0, y: 0, width: defaultPageWidth, height: defaultPageHeight)

    let pageRect: CGRect
    let margin: CGFloat = 34
    let logoWidth: CGFloat = 70
    let logoHeight: CGFloat = 34
    let qrCodeSize: CGFloat = 38
    let appStoreBadgeWidth: CGFloat = 92
    let appStoreBadgeHeight: CGFloat = 30
    let titleFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 23, nil)
    let subtitleFont = CTFontCreateWithName("Helvetica" as CFString, 10, nil)
    let sectionFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 14, nil)
    let metricFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 20, nil)
    let metricLabelFont = CTFontCreateWithName("Helvetica" as CFString, 7.8, nil)
    let entryTimeFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 12, nil)
    let labelFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 8.5, nil)
    let bodyFont = CTFontCreateWithName("Helvetica" as CFString, 9.5, nil)
    let smallFont = CTFontCreateWithName("Helvetica" as CFString, 8, nil)
    let textColor = CGColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
    let mutedTextColor = CGColor(red: 0.42, green: 0.42, blue: 0.43, alpha: 1)
    let backgroundColor = CGColor(red: 0.965, green: 0.957, blue: 0.937, alpha: 1)
    let cardColor = CGColor(red: 1, green: 1, blue: 0.985, alpha: 1)
    let primaryColor = CGColor(red: 0.059, green: 0.239, blue: 0.243, alpha: 1)
    let sageColor = CGColor(red: 0.557, green: 0.804, blue: 0.722, alpha: 1)
    let softSageColor = CGColor(red: 0.905, green: 0.965, blue: 0.945, alpha: 1)
    let insightFillColor = CGColor(red: 0.98, green: 0.985, blue: 0.975, alpha: 1)
    let chartAreaColor = CGColor(red: 0.557, green: 0.804, blue: 0.722, alpha: 0.22)
    let separatorColor = CGColor(red: 0.82, green: 0.84, blue: 0.82, alpha: 1)
    let shadowColor = CGColor(gray: 0, alpha: 0.08)
    let footerHeight: CGFloat = 66
    let headerHeight: CGFloat = 74
    let cardRadius: CGFloat = 10
    let sectionGap: CGFloat = 10
    let lineSpacing: CGFloat = 4
    let separatorHeight: CGFloat = 0.7
    var contentWidth: CGFloat { pageRect.width - (margin * 2) }
    var topY: CGFloat { margin + headerHeight + 12 }
    var bottomY: CGFloat { pageRect.height - margin - footerHeight }
    var footerTopY: CGFloat { pageRect.height - margin - footerHeight + 10 }

    init(pageRect: CGRect) {
        self.pageRect = pageRect
    }
}

nonisolated private struct PDFPageContext {
    let context: CGContext
    let layout: PDFLayout
    let headerTitle: String
    let headerSubtitle: String
    let headerPeriod: String
    let headerCreatedAt: String
    let headerLogo: CGImage?
    let footerTitle: String
    let footerBody: String
    let appStoreBadge: CGImage?
    let footerQRCode: CGImage?
    var cursorY: CGFloat = 0

    init(
        context: CGContext,
        layout: PDFLayout,
        headerTitle: String,
        headerSubtitle: String,
        headerPeriod: String,
        headerCreatedAt: String,
        headerLogo: CGImage?,
        footerTitle: String,
        footerBody: String,
        appStoreBadge: CGImage?,
        footerQRCode: CGImage?
    ) {
        self.context = context
        self.layout = layout
        self.headerTitle = headerTitle
        self.headerSubtitle = headerSubtitle
        self.headerPeriod = headerPeriod
        self.headerCreatedAt = headerCreatedAt
        self.headerLogo = headerLogo
        self.footerTitle = footerTitle
        self.footerBody = footerBody
        self.appStoreBadge = appStoreBadge
        self.footerQRCode = footerQRCode
        self.cursorY = layout.topY
    }

    mutating func beginPage() {
        context.beginPDFPage(nil)
        drawPageBackground()
        try? drawHeader()
        cursorY = layout.topY
    }

    mutating func startNewPage() {
        endPage()
        beginPage()
    }

    mutating func drawSummaryCard(metrics: [PDFMetricTile]) throws {
        let cardHeight: CGFloat = 138
        ensureSpace(cardHeight)
        let cardRect = CGRect(x: layout.margin, y: cursorY, width: layout.contentWidth, height: cardHeight)
        drawProminentCard(cardRect)
        try draw(text: "Kurzüberblick", font: layout.sectionFont, color: layout.textColor, rect: cardRect.insetBy(dx: 16, dy: 14), preserveCursor: true)

        let tileGap: CGFloat = 10
        let tileTop = cardRect.minY + 44
        let tileHeight: CGFloat = 76
        let tileWidth = (cardRect.width - 32 - (tileGap * 4)) / 5
        for (index, metric) in metrics.enumerated() {
            let x = cardRect.minX + 16 + CGFloat(index) * (tileWidth + tileGap)
            let tileRect = CGRect(x: x, y: tileTop, width: tileWidth, height: tileHeight)
            drawMetricTile(metric, in: tileRect)
        }

        cursorY = cardRect.maxY
    }

    mutating func drawInsightBlock(text: String) throws {
        let cardHeight: CGFloat = 62
        ensureSpace(cardHeight)
        let cardRect = CGRect(x: layout.margin, y: cursorY, width: layout.contentWidth, height: cardHeight)
        drawRoundedRect(cardRect, fill: layout.insightFillColor, stroke: nil, radius: 8)
        drawCircle(CGRect(x: cardRect.minX + 16, y: cardRect.minY + 15, width: 7, height: 7), fill: layout.sageColor)
        try draw(
            text: "Einschätzung",
            font: layout.labelFont,
            color: layout.primaryColor,
            rect: CGRect(x: cardRect.minX + 30, y: cardRect.minY + 12, width: cardRect.width - 46, height: 12),
            preserveCursor: true
        )
        try draw(
            text: text,
            font: layout.bodyFont,
            color: layout.textColor,
            rect: CGRect(x: cardRect.minX + 30, y: cardRect.minY + 29, width: cardRect.width - 46, height: 22),
            preserveCursor: true
        )
        cursorY = cardRect.maxY
    }

    mutating func drawIntensityTimeline(records: [EpisodeExportRecord]) throws {
        let chartHeight: CGFloat = 190
        ensureSpace(chartHeight)
        let cardRect = CGRect(x: layout.margin, y: cursorY, width: layout.contentWidth, height: chartHeight)
        drawCard(cardRect)
        try draw(text: "Intensität im Verlauf", font: layout.sectionFont, color: layout.textColor, rect: CGRect(x: cardRect.minX + 16, y: cardRect.minY + 14, width: cardRect.width - 32, height: 18), preserveCursor: true)

        let plotRect = CGRect(x: cardRect.minX + 42, y: cardRect.minY + 48, width: cardRect.width - 66, height: 98)
        drawTimelineAxes(in: plotRect)

        let chartRecords = Array(records.suffix(18))
        if chartRecords.isEmpty {
            try draw(text: "Keine Einträge im ausgewählten Zeitraum", font: layout.bodyFont, color: layout.mutedTextColor, rect: plotRect, preserveCursor: true)
        } else {
            drawTimelinePoints(records: chartRecords, in: plotRect)
        }

        cursorY = cardRect.maxY
    }

    mutating func drawPatternSummary(symptoms: [PDFPatternItem], triggers: [PDFPatternItem], medications: [PDFPatternItem]) throws {
        let cardHeight: CGFloat = 160
        ensureSpace(cardHeight)
        let cardRect = CGRect(x: layout.margin, y: cursorY, width: layout.contentWidth, height: cardHeight)
        drawLightCard(cardRect)
        try draw(text: "Häufige Muster", font: layout.sectionFont, color: layout.textColor, rect: CGRect(x: cardRect.minX + 16, y: cardRect.minY + 12, width: cardRect.width - 32, height: 18), preserveCursor: true)

        var y = cardRect.minY + 38
        y = try drawPatternList(title: "Symptome", values: symptoms, x: cardRect.minX + 16, y: y, width: cardRect.width - 32)
        y = try drawPatternList(title: "Trigger", values: triggers, x: cardRect.minX + 16, y: y + 8, width: cardRect.width - 32)
        _ = try drawPatternList(title: "Medikamente", values: medications, x: cardRect.minX + 16, y: y + 8, width: cardRect.width - 32)
        cursorY = cardRect.maxY
    }

    mutating func drawEntrySection(records: [EpisodeExportRecord], includeAllDetails: Bool) throws {
        try drawSectionTitle("Detaillierte Einträge")
        var currentDay: Date?
        for record in records {
            let day = Calendar.current.startOfDay(for: record.startedAt)
            if currentDay != day {
                if currentDay != nil {
                    addSpacing(10)
                }
                try drawDateHeader(for: day)
                currentDay = day
            }
            try drawEntryCard(record, includeAllDetails: includeAllDetails)
            addSpacing(12)
        }
    }

    mutating func drawSectionTitle(_ text: String) throws {
        try draw(text: text, font: layout.sectionFont, color: layout.textColor, extraSpacing: 8)
    }

    mutating func drawReportFooter() throws {
        let footerRect = CGRect(
            x: layout.margin,
            y: layout.footerTopY,
            width: layout.contentWidth,
            height: layout.footerHeight - 12
        )
        drawSeparator(at: footerRect.minY)

        try draw(
            text: "Dieser Bericht dient zur Unterstützung im Arztgespräch und ersetzt keine medizinische Diagnose.",
            font: layout.smallFont,
            color: layout.mutedTextColor,
            rect: CGRect(x: footerRect.minX, y: footerRect.minY + 10, width: 210, height: 30),
            preserveCursor: true
        )

        try draw(
            text: "\(footerTitle)\n\(footerBody)",
            font: layout.smallFont,
            color: layout.mutedTextColor,
            rect: CGRect(x: footerRect.midX - 76, y: footerRect.minY + 10, width: 152, height: 30),
            preserveCursor: true
        )

        if let appStoreBadge {
            drawImage(
                appStoreBadge,
                in: CGRect(x: footerRect.maxX - 78 - layout.qrCodeSize - 10, y: footerRect.minY + 13, width: 78, height: 25)
            )
        }
        if let footerQRCode {
            drawImage(
                footerQRCode,
                in: CGRect(x: footerRect.maxX - layout.qrCodeSize, y: footerRect.minY + 6, width: layout.qrCodeSize, height: layout.qrCodeSize)
            )
        }
    }

    mutating func addSpacing(_ value: CGFloat) {
        cursorY += value
    }

    private mutating func drawHeader() throws {
        let headerTop = layout.margin
        if let headerLogo {
            drawImage(headerLogo, in: CGRect(x: layout.margin, y: headerTop, width: layout.logoWidth, height: layout.logoHeight))
        }

        let textX = layout.margin + layout.logoWidth + 14
        try draw(text: headerTitle, font: layout.titleFont, color: layout.primaryColor, rect: CGRect(x: textX, y: headerTop - 2, width: 260, height: 28), preserveCursor: true)
        try draw(text: headerSubtitle, font: layout.subtitleFont, color: layout.mutedTextColor, rect: CGRect(x: textX, y: headerTop + 30, width: 280, height: 16), preserveCursor: true)

        try draw(text: headerPeriod, font: layout.smallFont, color: layout.textColor, rect: CGRect(x: layout.pageRect.width - layout.margin - 170, y: headerTop + 2, width: 170, height: 14), preserveCursor: true)
        try draw(text: headerCreatedAt, font: layout.smallFont, color: layout.mutedTextColor, rect: CGRect(x: layout.pageRect.width - layout.margin - 170, y: headerTop + 20, width: 170, height: 14), preserveCursor: true)
        drawSeparator(at: layout.margin + layout.headerHeight)
    }

    private mutating func drawMetricTile(_ metric: PDFMetricTile, in rect: CGRect) {
        drawRoundedRect(rect, fill: layout.softSageColor, stroke: nil, radius: 8)
        try? draw(text: metric.value, font: layout.metricFont, color: layout.primaryColor, rect: CGRect(x: rect.minX + 10, y: rect.minY + 14, width: rect.width - 20, height: 24), preserveCursor: true)
        try? draw(text: metric.label, font: layout.metricLabelFont, color: layout.mutedTextColor, rect: CGRect(x: rect.minX + 10, y: rect.minY + 43, width: rect.width - 20, height: 28), preserveCursor: true)
    }

    private mutating func drawDateHeader(for date: Date) throws {
        let headerHeight: CGFloat = 24
        ensureSpace(headerHeight + 6)
        try draw(
            text: date.formatted(date: .abbreviated, time: .omitted),
            font: layout.sectionFont,
            color: layout.primaryColor,
            rect: CGRect(x: layout.margin, y: cursorY, width: layout.contentWidth, height: headerHeight),
            preserveCursor: true
        )
        cursorY += headerHeight
    }

    private mutating func drawEntryCard(_ record: EpisodeExportRecord, includeAllDetails: Bool) throws {
        let mainWidth = layout.contentWidth - 96
        let rowWidth = mainWidth - 92
        let medicationText = medicationSummary(for: record.medications)
        let rows = [
            ("Symptome", listText(record.symptoms)),
            ("Trigger", listText(record.triggers)),
            ("Medikation", medicationText),
            ("Notizen", trimmed(record.notes).isEmpty ? "–" : trimmed(record.notes))
        ]
        var rowsHeight: CGFloat = 0
        for row in rows {
            rowsHeight += max(15, height(for: row.1, font: layout.bodyFont, width: rowWidth)) + 6
        }
        if includeAllDetails {
            let additional = additionalClinicalContext(for: record)
            if !additional.isEmpty {
                rowsHeight += max(15, height(for: additional, font: layout.bodyFont, width: rowWidth)) + 6
            }
        }
        let cardHeight = max(112, rowsHeight + 48)
        ensureSpace(cardHeight)
        let cardRect = CGRect(x: layout.margin, y: cursorY, width: layout.contentWidth, height: cardHeight)
        drawCard(cardRect)

        let leftRect = CGRect(x: cardRect.minX + 14, y: cardRect.minY + 16, width: 54, height: cardHeight - 32)
        try draw(text: record.startedAt.formatted(date: .omitted, time: .shortened), font: layout.entryTimeFont, color: layout.primaryColor, rect: leftRect, preserveCursor: true)

        let mainX = cardRect.minX + 80
        let intensityText = "Intensität \(record.intensity)/10"
        try draw(text: intensityText, font: layout.labelFont, color: layout.primaryColor, rect: CGRect(x: mainX, y: cardRect.minY + 15, width: 104, height: 14), preserveCursor: true)
        drawIntensityIndicator(value: record.intensity, rect: CGRect(x: mainX + 116, y: cardRect.minY + 17, width: mainWidth - 116, height: 10))

        if let typeText = visibleType(record.type) {
            try draw(text: typeText, font: layout.smallFont, color: layout.mutedTextColor, rect: CGRect(x: mainX, y: cardRect.minY + 31, width: mainWidth, height: 12), preserveCursor: true)
        }

        var rowY = cardRect.minY + 48
        for row in rows {
            rowY = try drawEntryRow(label: row.0, value: row.1, x: mainX, y: rowY, valueWidth: rowWidth)
        }
        if includeAllDetails {
            let additional = additionalClinicalContext(for: record)
            if !additional.isEmpty {
                _ = try drawEntryRow(label: "Weitere Angaben", value: additional, x: mainX, y: rowY, valueWidth: rowWidth)
            }
        }
        cursorY = cardRect.maxY
    }

    private mutating func drawEntryRow(label: String, value: String, x: CGFloat, y: CGFloat, valueWidth: CGFloat) throws -> CGFloat {
        let rowHeight = max(15, height(for: value, font: layout.bodyFont, width: valueWidth))
        try draw(text: label, font: layout.labelFont, color: layout.mutedTextColor, rect: CGRect(x: x, y: y, width: 78, height: rowHeight), preserveCursor: true)
        try draw(text: value, font: layout.bodyFont, color: layout.textColor, rect: CGRect(x: x + 88, y: y, width: valueWidth, height: rowHeight), preserveCursor: true)
        return y + rowHeight + 6
    }

    private mutating func draw(text: String, font: CTFont, color: CGColor, extraSpacing: CGFloat) throws {
        let textHeight = height(for: text, font: font, width: layout.contentWidth)
        ensureSpace(textHeight + extraSpacing)

        let frameRect = CGRect(x: layout.margin, y: cursorY, width: layout.contentWidth, height: textHeight)
        try draw(text: text, font: font, color: color, rect: frameRect, preserveCursor: false)
        cursorY = frameRect.maxY + extraSpacing
    }

    private mutating func draw(text: String, font: CTFont, color: CGColor, rect frameRect: CGRect, preserveCursor: Bool) throws {
        let attributedText = NSAttributedString(
            string: text,
            attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): color
            ]
        )

        let framesetter = CTFramesetterCreateWithAttributedString(attributedText)
        let path = unsafe CGPath(rect: pdfRect(fromTopLeftRect: frameRect), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: attributedText.length), path, nil)

        context.saveGState()
        context.textMatrix = .identity
        CTFrameDraw(frame, context)
        context.restoreGState()

        if !preserveCursor {
            cursorY = frameRect.maxY
        }
    }

    private mutating func ensureSpace(_ height: CGFloat) {
        if cursorY + height > layout.bottomY {
            endPage()
            beginPage()
        }
    }

    private func drawPageBackground() {
        drawRect(layout.pageRect, color: layout.backgroundColor)
    }

    private func drawCard(_ rect: CGRect) {
        drawShadow(rect, radius: layout.cardRadius)
        drawRoundedRect(rect, fill: layout.cardColor, stroke: nil, radius: layout.cardRadius)
    }

    private func drawProminentCard(_ rect: CGRect) {
        drawShadow(rect, radius: layout.cardRadius)
        drawRoundedRect(rect, fill: layout.cardColor, stroke: nil, radius: layout.cardRadius)
    }

    private func drawLightCard(_ rect: CGRect) {
        drawRoundedRect(rect, fill: layout.cardColor, stroke: nil, radius: layout.cardRadius)
    }

    private mutating func drawTimelineAxes(in rect: CGRect) {
        for index in 0...2 {
            let value = index * 5
            let y = rect.maxY - (CGFloat(value) / 10 * rect.height)
            drawRect(CGRect(x: rect.minX, y: y, width: rect.width, height: 0.6), color: CGColor(gray: 0.86, alpha: 1))
            try? draw(text: "\(value)", font: layout.smallFont, color: layout.mutedTextColor, rect: CGRect(x: rect.minX - 24, y: y - 5, width: 18, height: 10), preserveCursor: true)
        }
    }

    private mutating func drawTimelinePoints(records: [EpisodeExportRecord], in rect: CGRect) {
        guard !records.isEmpty else { return }
        var points: [CGPoint] = []
        let maxIntensity = records.map(\.intensity).max() ?? 0
        for (index, record) in records.enumerated() {
            let x = records.count == 1 ? rect.midX : rect.minX + (CGFloat(index) / CGFloat(records.count - 1) * rect.width)
            let y = rect.maxY - (CGFloat(record.intensity) / 10 * rect.height)
            points.append(CGPoint(x: x, y: y))
        }

        if points.count > 1 {
            let areaPath = CGMutablePath()
            areaPath.move(to: pdfPoint(fromTopLeft: CGPoint(x: points[0].x, y: rect.maxY)))
            for point in points {
                areaPath.addLine(to: pdfPoint(fromTopLeft: point))
            }
            areaPath.addLine(to: pdfPoint(fromTopLeft: CGPoint(x: points[points.count - 1].x, y: rect.maxY)))
            areaPath.closeSubpath()
            context.saveGState()
            context.setFillColor(layout.chartAreaColor)
            context.addPath(areaPath)
            context.fillPath()
            context.restoreGState()

            let path = CGMutablePath()
            path.move(to: pdfPoint(fromTopLeft: points[0]))
            for point in points.dropFirst() {
                path.addLine(to: pdfPoint(fromTopLeft: point))
            }
            context.saveGState()
            context.setStrokeColor(layout.primaryColor)
            context.setLineWidth(3.2)
            context.setLineJoin(.round)
            context.setLineCap(.round)
            context.addPath(path)
            context.strokePath()
            context.restoreGState()
        }

        for (index, point) in points.enumerated() {
            let isMaximum = records[index].intensity == maxIntensity
            let isLast = index == records.count - 1
            let outerSize: CGFloat = isMaximum ? 15 : (isLast ? 13 : 11)
            let innerSize: CGFloat = isMaximum ? 8 : (isLast ? 7 : 6)
            drawCircle(CGRect(x: point.x - (outerSize / 2), y: point.y - (outerSize / 2), width: outerSize, height: outerSize), fill: layout.primaryColor)
            drawCircle(CGRect(x: point.x - (innerSize / 2), y: point.y - (innerSize / 2), width: innerSize, height: innerSize), fill: isLast ? layout.cardColor : layout.sageColor)
            try? draw(text: "\(records[index].intensity)", font: layout.smallFont, color: layout.primaryColor, rect: CGRect(x: point.x - 8, y: point.y - 20, width: 16, height: 10), preserveCursor: true)
            if isMaximum {
                try? draw(text: "Max", font: layout.smallFont, color: layout.primaryColor, rect: CGRect(x: point.x + 7, y: point.y - 18, width: 24, height: 10), preserveCursor: true)
            } else if isLast {
                try? draw(text: "Aktuell", font: layout.smallFont, color: layout.primaryColor, rect: CGRect(x: point.x + 7, y: point.y - 18, width: 34, height: 10), preserveCursor: true)
            }
            if index == 0 || index == records.count - 1 || index % 4 == 0 {
                try? draw(text: records[index].startedAt.formatted(.dateTime.day().month()), font: layout.smallFont, color: layout.mutedTextColor, rect: CGRect(x: point.x - 18, y: rect.maxY + 9, width: 36, height: 12), preserveCursor: true)
            }
        }
    }

    private mutating func drawPatternList(title: String, values: [PDFPatternItem], x: CGFloat, y: CGFloat, width: CGFloat) throws -> CGFloat {
        try draw(text: title, font: layout.smallFont, color: layout.mutedTextColor, rect: CGRect(x: x, y: y, width: width, height: 11), preserveCursor: true)
        let bulletText = values.isEmpty
            ? "–"
            : values.map { "• \($0.label) (\($0.count)x)" }.joined(separator: "\n")
        let bulletHeight = max(12, height(for: bulletText, font: layout.bodyFont, width: width))
        try draw(text: bulletText, font: layout.bodyFont, color: layout.textColor, rect: CGRect(x: x, y: y + 14, width: width, height: bulletHeight), preserveCursor: true)
        return y + 15 + bulletHeight
    }

    private func drawIntensityIndicator(value: Int, rect: CGRect) {
        drawRoundedRect(rect, fill: CGColor(gray: 0.82, alpha: 1), stroke: nil, radius: 5)
        let fillWidth = rect.width * CGFloat(max(0, min(value, 10))) / 10
        drawRoundedRect(CGRect(x: rect.minX, y: rect.minY, width: fillWidth, height: rect.height), fill: layout.primaryColor, stroke: nil, radius: 5)
    }

    private func drawImage(_ image: CGImage, in rect: CGRect) {
        context.saveGState()
        context.interpolationQuality = .high
        context.draw(image, in: pdfRect(fromTopLeftRect: rect))
        context.restoreGState()
    }

    private func drawCircle(_ rect: CGRect, fill: CGColor) {
        context.saveGState()
        context.setFillColor(fill)
        context.fillEllipse(in: pdfRect(fromTopLeftRect: rect))
        context.restoreGState()
    }

    private func drawRect(_ rect: CGRect, color: CGColor) {
        context.saveGState()
        context.setFillColor(color)
        context.fill(pdfRect(fromTopLeftRect: rect))
        context.restoreGState()
    }

    private func drawRoundedRect(_ rect: CGRect, fill: CGColor, stroke: CGColor?, radius: CGFloat) {
        drawRoundedRect(rect, fill: fill, stroke: stroke, radius: radius, lineWidth: layout.separatorHeight)
    }

    private func drawRoundedRect(_ rect: CGRect, fill: CGColor, stroke: CGColor?, radius: CGFloat, lineWidth: CGFloat) {
        let path = unsafe CGPath(roundedRect: pdfRect(fromTopLeftRect: rect), cornerWidth: radius, cornerHeight: radius, transform: nil)
        context.saveGState()
        context.setFillColor(fill)
        context.addPath(path)
        context.fillPath()
        if let stroke {
            context.setStrokeColor(stroke)
            context.setLineWidth(lineWidth)
            context.addPath(path)
            context.strokePath()
        }
        context.restoreGState()
    }

    private func drawShadow(_ rect: CGRect, radius: CGFloat) {
        let path = unsafe CGPath(roundedRect: pdfRect(fromTopLeftRect: rect), cornerWidth: radius, cornerHeight: radius, transform: nil)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -1), blur: 7, color: layout.shadowColor)
        context.setFillColor(layout.cardColor)
        context.addPath(path)
        context.fillPath()
        context.restoreGState()
    }

    private func drawSeparator() {
        drawSeparator(at: cursorY)
    }

    private func drawSeparator(at y: CGFloat) {
        let separatorRect = pdfRect(
            fromTopLeftRect: CGRect(
                x: layout.margin,
                y: y,
                width: layout.contentWidth,
                height: layout.separatorHeight
            )
        )
        context.saveGState()
        context.setFillColor(layout.separatorColor)
        context.fill(separatorRect)
        context.restoreGState()
    }

    private func height(for text: String, font: CTFont, width: CGFloat) -> CGFloat {
        let attributedText = NSAttributedString(
            string: text,
            attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font
            ]
        )
        let framesetter = CTFramesetterCreateWithAttributedString(attributedText)
        let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRange(location: 0, length: attributedText.length),
            nil,
            CGSize(width: width, height: .greatestFiniteMagnitude),
            nil
        )

        return ceil(max(suggestedSize.height, CTFontGetSize(font)))
    }

    private func pdfRect(fromTopLeftRect rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX,
            y: layout.pageRect.height - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    private func pdfPoint(fromTopLeft point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: layout.pageRect.height - point.y)
    }

    private func listText(_ values: [String]) -> String {
        values.isEmpty ? "–" : values.joined(separator: ", ")
    }

    private func medicationSummary(for medications: [EpisodeExportRecord.MedicationLine]) -> String {
        guard !medications.isEmpty else { return "–" }
        return medications.map { medication in
            var details: [String] = []
            let category = PDFExportWriter.localizedExportValue(medication.category)
            if !category.isEmpty {
                details.append(category)
            }
            let dosage = trimmed(medication.dosage)
            if !dosage.isEmpty {
                details.append(dosage)
            }
            if medication.quantity > 1 {
                details.append("Anzahl: \(medication.quantity)")
            }
            let effectiveness = PDFExportWriter.localizedExportValue(medication.effectiveness)
            if !effectiveness.isEmpty && effectiveness != MedicationEffectiveness.partial.displayName {
                details.append("Wirkung: \(effectiveness)")
            }
            return details.isEmpty ? medication.name : "\(medication.name) (\(details.joined(separator: ", ")))"
        }.joined(separator: "; ")
    }

    private func visibleType(_ rawType: String) -> String? {
        let type = PDFExportWriter.localizedExportValue(rawType)
        guard !type.isEmpty, type != EpisodeType.unclear.displayName else { return nil }
        return type
    }

    private func additionalClinicalContext(for record: EpisodeExportRecord) -> String {
        var parts: [String] = []
        let painLocation = trimmed(record.painLocation)
        if !painLocation.isEmpty {
            parts.append("Schmerzort: \(painLocation)")
        }
        let painCharacter = trimmed(record.painCharacter)
        if !painCharacter.isEmpty {
            parts.append("Schmerzcharakter: \(painCharacter)")
        }
        let functionalImpact = trimmed(record.functionalImpact)
        if !functionalImpact.isEmpty {
            parts.append("Einschränkung: \(functionalImpact)")
        }
        if record.menstruationStatus != MenstruationStatus.unknown.displayName {
            parts.append("Menstruationsstatus: \(PDFExportWriter.localizedExportValue(record.menstruationStatus))")
        }
        return parts.joined(separator: " · ")
    }

    mutating func endPage() {
        try? drawReportFooter()
        context.endPDFPage()
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
