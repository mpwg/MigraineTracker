import CoreGraphics
import CoreImage
import CoreText
import Foundation
import PDFKit
import UIKit

enum PDFExportWriter {
    static func write(summary: ExportPeriodSummary, mode: PDFReportMode = .detailed) throws -> URL {
        let fileName = "\(localized("Schmerztagebuch-Bericht"))-\(dateStamp(summary.startDate))-\(dateStamp(summary.endDate)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let layout = PDFLayout(pageRect: pageRect)

        try writeRawPDF(summary: summary, mode: mode, to: url, layout: layout)
        try finalizeDocument(at: url)

        return url
    }

    private static func writeRawPDF(summary: ExportPeriodSummary, mode: PDFReportMode, to url: URL, layout: PDFLayout) throws {
        var mediaBox = layout.pageRect
        let documentTitle = localized("Schmerztagebuch")
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
            headerTitle: localized("Schmerztagebuch"),
            headerLogo: brandLogo(),
            footerTitle: localized("App herunterladen"),
            footerLinkLabel: localized("App Store"),
            footerURL: ProductBranding.appStoreURL.absoluteString,
            footerQRCode: appStoreQRCode()
        )
        page.beginPage()
        try page.drawBodyLine(
            formatted(
                "Zeitraum: %@ bis %@",
                summary.startDate.formatted(date: .abbreviated, time: .omitted),
                summary.endDate.formatted(date: .abbreviated, time: .omitted)
            )
        )
        try page.drawBodyLine(formatted("Einträge: %lld", Int64(summary.episodeCount)))

        if summary.episodeCount > 0 {
            try page.drawBodyLine(
                formatted(
                    "Durchschnittliche Intensität: %@/10",
                    summary.averageIntensity.formatted(.number.precision(.fractionLength(1)))
                )
            )
        }

        if !summary.medicationNames.isEmpty {
            try page.drawBodyLine(
                formatted("Dokumentierte Medikamente: %@", summary.medicationNames.joined(separator: ", "))
            )
        }

        try drawExecutiveSummary(summary: summary, on: &page)

        page.addSpacing(18)
        try drawCharts(summary: summary, on: &page)

        if mode == .detailed {
            page.addSpacing(12)
            try page.drawSectionTitle(localized("Detaillierte Einträge"))

            for record in summary.records {
                try page.drawBlock(exportLines(for: record))
            }
        }

        page.endPage()
        context.closePDF()
    }

    private static func finalizeDocument(at url: URL) throws {
        guard let document = PDFDocument(url: url), document.pageCount > 0 else {
            throw PDFExportError.documentValidationFailed
        }
        let documentTitle = localized("Schmerztagebuch")

        document.documentAttributes = [
            PDFDocumentAttribute.titleAttribute: documentTitle,
            PDFDocumentAttribute.authorAttribute: ProductBranding.displayName,
            PDFDocumentAttribute.creatorAttribute: ProductBranding.displayName
        ]

        guard let data = document.dataRepresentation() else {
            throw PDFExportError.documentValidationFailed
        }

        try data.write(to: url, options: .atomic)
    }

    private static func exportLines(for record: EpisodeExportRecord) -> [String] {
        var lines: [String] = []
        lines.append(
            formatted(
                "%@ · %@ · Intensität %lld/10",
                record.startedAt.formatted(date: .abbreviated, time: .shortened),
                localizedExportValue(record.type),
                Int64(record.intensity)
            )
        )

        if let endedAt = record.endedAt {
            lines.append(formatted("Ende: %@", endedAt.formatted(date: .abbreviated, time: .shortened)))
        }

        if !record.painLocation.isEmpty {
            lines.append(formatted("Schmerzort: %@", record.painLocation))
        }

        if !record.painCharacter.isEmpty {
            lines.append(formatted("Schmerzcharakter: %@", record.painCharacter))
        }

        if record.menstruationStatus != MenstruationStatus.unknown.rawValue {
            lines.append(formatted("Menstruationsstatus: %@", localizedExportValue(record.menstruationStatus)))
        }

        if !record.symptoms.isEmpty {
            lines.append(formatted("Symptome: %@", record.symptoms.joined(separator: ", ")))
        }

        if !record.triggers.isEmpty {
            lines.append(formatted("Trigger: %@", record.triggers.joined(separator: ", ")))
        }

        if !record.functionalImpact.isEmpty {
            lines.append(formatted("Einschränkung: %@", record.functionalImpact))
        }

        if !record.medications.isEmpty {
            let medicationText = record.medications.map { medication in
                let category = localizedExportValue(medication.category)
                let dosageText = medication.dosage.isEmpty ? category : "\(category), \(medication.dosage)"
                let quantityText = medication.quantity > 1 ? formatted(", Anzahl: %lld", Int64(medication.quantity)) : ""
                let effectivenessText = medication.effectiveness == MedicationEffectiveness.partial.rawValue
                    ? ""
                    : formatted(", Wirkung: %@", localizedExportValue(medication.effectiveness))
                return "\(medication.name) (\(dosageText)\(quantityText)\(effectivenessText))"
            }
            lines.append(formatted("Medikamente: %@", medicationText.joined(separator: "; ")))
        }

        if let weather = record.weather {
            var parts: [String] = []
            if !weather.condition.isEmpty {
                parts.append(weather.condition)
            }
            if let temperature = weather.temperature {
                parts.append("\(temperature.formatted(.number.precision(.fractionLength(1)))) °C")
            }
            if let humidity = weather.humidity {
                parts.append(formatted("%@ %% Luftfeuchte", humidity.formatted(.number.precision(.fractionLength(0)))))
            }
            if let pressure = weather.pressure {
                parts.append("\(pressure.formatted(.number.precision(.fractionLength(0)))) hPa")
            }
            if let precipitation = weather.precipitation {
                parts.append(formatted("%@ mm Niederschlag", precipitation.formatted(.number.precision(.fractionLength(1)))))
            }
            if !weather.source.isEmpty {
                parts.append(formatted("Quelle: %@", weather.source))
            }

            if !parts.isEmpty {
                lines.append(formatted("Wetter: %@", parts.joined(separator: ", ")))
            }
        }

        if let health = record.healthContext {
            var parts: [String] = []
            if let sleepMinutes = health.sleepMinutes {
                parts.append(formatted("Schlaf %@ min", Int(sleepMinutes.rounded()).formatted()))
            }
            if let stepCount = health.stepCount {
                parts.append(formatted("Schritte %@", stepCount.formatted()))
            }
            if let averageHeartRate = health.averageHeartRate {
                parts.append(formatted("Herzfrequenz %@ bpm", averageHeartRate.formatted(.number.precision(.fractionLength(0)))))
            }
            if let restingHeartRate = health.restingHeartRate {
                parts.append(formatted("Ruhepuls %@ bpm", restingHeartRate.formatted(.number.precision(.fractionLength(0)))))
            }
            if let heartRateVariability = health.heartRateVariability {
                parts.append("HRV \(heartRateVariability.formatted(.number.precision(.fractionLength(0)))) ms")
            }
            if let menstrualFlow = health.menstrualFlow {
                parts.append(formatted("Menstruation %@", menstrualFlow))
            }
            if !health.symptoms.isEmpty {
                parts.append(formatted("Symptome %@", health.symptoms.joined(separator: ", ")))
            }
            parts.append(formatted("Quelle: %@", health.source))
            parts.append(formatted("Erfasst: %@", health.recordedAt.formatted(date: .abbreviated, time: .shortened)))

            lines.append("Apple Health: \(parts.joined(separator: ", "))")
        }

        if !record.notes.isEmpty {
            lines.append(formatted("Notiz: %@", record.notes))
        }

        return lines
    }

    private static func drawExecutiveSummary(summary: ExportPeriodSummary, on page: inout PDFPageContext) throws {
        page.addSpacing(12)
        try page.drawSectionTitle(localized("Kurzüberblick"))

        try page.drawBodyLine(formatted("Schmerztage im Zeitraum: %lld", Int64(painDayCount(for: summary.records))))

        if let strongestRecord = summary.records.max(by: { $0.intensity < $1.intensity }) {
            try page.drawBodyLine(
                formatted(
                    "Stärkste Episode: %@ · %lld/10",
                    strongestRecord.startedAt.formatted(date: .abbreviated, time: .shortened),
                    Int64(strongestRecord.intensity)
                )
            )
        }

        let symptoms = topValues(summary.records.flatMap(\.symptoms), limit: 5).map(\.label)
        if !symptoms.isEmpty {
            try page.drawBodyLine(formatted("Häufige Symptome: %@", symptoms.joined(separator: ", ")))
        }

        let triggers = topValues(summary.records.flatMap(\.triggers), limit: 5).map(\.label)
        if !triggers.isEmpty {
            try page.drawBodyLine(formatted("Häufige Trigger: %@", triggers.joined(separator: ", ")))
        }
    }

    private static func drawCharts(summary: ExportPeriodSummary, on page: inout PDFPageContext) throws {
        try page.drawSectionTitle(localized("Auswertung"))

        let timelineRows = summary.records
            .sorted { $0.startedAt < $1.startedAt }
            .suffix(12)
            .map { record in
                PDFChartRow(
                    label: record.startedAt.formatted(.dateTime.day().month()),
                    value: record.intensity,
                    detail: localizedExportValue(record.type)
                )
            }
        try page.drawHorizontalBarChart(title: localized("Intensität im Verlauf"), rows: timelineRows, maximumValue: 10)

        let typeRows = countRows(summary.records.map { localizedExportValue($0.type) }, limit: 6)
        try page.drawHorizontalBarChart(title: localized("Episodentypen"), rows: typeRows)

        let symptomRows = countRows(summary.records.flatMap(\.symptoms), limit: 6)
        try page.drawHorizontalBarChart(title: localized("Symptome"), rows: symptomRows)

        let triggerRows = countRows(summary.records.flatMap(\.triggers), limit: 6)
        try page.drawHorizontalBarChart(title: localized("Trigger"), rows: triggerRows)

        let medicationRows = countRows(summary.records.flatMap { $0.medications.map(\.name) }, limit: 6)
        try page.drawHorizontalBarChart(title: localized("Medikamente"), rows: medicationRows)
    }

    private static func brandLogo() -> CGImage? {
        UIImage(named: "BrandLogo")?.cgImage ?? UIImage(named: "AppIcon")?.cgImage
    }

    private static func appStoreQRCode() -> CGImage? {
        let data = Data(ProductBranding.appStoreURL.absoluteString.utf8)
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        let transform = CGAffineTransform(scaleX: 8, y: 8)
        guard let outputImage = filter.outputImage?.transformed(by: transform) else { return nil }

        return CIContext(options: [.useSoftwareRenderer: false]).createCGImage(outputImage, from: outputImage.extent)
    }

    private static func localized(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: .main)
    }

    private static func formatted(_ key: String, _ arguments: CVarArg...) -> String {
        unsafe String(format: localized(key), arguments: arguments)
    }

    private static func localizedExportValue(_ value: String) -> String {
        switch value {
        case EpisodeType.migraine.rawValue,
            EpisodeType.headache.rawValue,
            EpisodeType.unclear.rawValue,
            MedicationCategory.triptan.rawValue,
            MedicationCategory.nsar.rawValue,
            MedicationCategory.paracetamol.rawValue,
            MedicationCategory.antiemetic.rawValue,
            MedicationCategory.other.rawValue,
            MenstruationStatus.unknown.rawValue,
            MenstruationStatus.none.rawValue,
            MenstruationStatus.active.rawValue,
            MenstruationStatus.expected.rawValue,
            MedicationEffectiveness.none.rawValue,
            MedicationEffectiveness.partial.rawValue,
            MedicationEffectiveness.good.rawValue:
            return localized(value)
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

    private static func topValues(_ values: [String], limit: Int) -> [(label: String, count: Int)] {
        Dictionary(grouping: values.filter { !$0.isEmpty }, by: { $0 })
            .map { (label: $0.key, count: $0.value.count) }
            .sorted {
                if $0.count == $1.count {
                    return $0.label.localizedStandardCompare($1.label) == .orderedAscending
                }
                return $0.count > $1.count
            }
            .prefix(limit)
            .map { $0 }
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

private struct PDFChartRow {
    let label: String
    let value: Int
    let detail: String
}

private struct PDFLayout {
    let pageRect: CGRect
    let margin: CGFloat = 40
    let logoSize: CGFloat = 44
    let qrCodeSize: CGFloat = 78
    let titleFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 22, nil)
    let sectionFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 15, nil)
    let brandFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 12, nil)
    let bodyFont = CTFontCreateWithName("Helvetica" as CFString, 11, nil)
    let smallFont = CTFontCreateWithName("Helvetica" as CFString, 9, nil)
    let textColor = CGColor(gray: 0.05, alpha: 1)
    let mutedTextColor = CGColor(gray: 0.35, alpha: 1)
    let chartFillColor = CGColor(red: 0.19, green: 0.49, blue: 0.53, alpha: 1)
    let chartTrackColor = CGColor(red: 0.88, green: 0.93, blue: 0.93, alpha: 1)
    let brandFillColor = CGColor(red: 0.96, green: 0.98, blue: 0.98, alpha: 1)
    let brandStrokeColor = CGColor(red: 0.68, green: 0.77, blue: 0.77, alpha: 1)
    let separatorColor = CGColor(gray: 0.82, alpha: 1)
    let lineSpacing: CGFloat = 5
    let footerHeight: CGFloat = 108

    var contentWidth: CGFloat { pageRect.width - (margin * 2) }
    var topY: CGFloat { margin + 72 }
    var bottomY: CGFloat { pageRect.height - margin - footerHeight }
    var footerTopY: CGFloat { pageRect.height - margin - footerHeight + 10 }

    init(pageRect: CGRect) {
        self.pageRect = pageRect
    }
}

private struct PDFPageContext {
    let context: CGContext
    let layout: PDFLayout
    let headerTitle: String
    let headerLogo: CGImage?
    let footerTitle: String
    let footerLinkLabel: String
    let footerURL: String
    let footerQRCode: CGImage?
    var cursorY: CGFloat = 0

    init(
        context: CGContext,
        layout: PDFLayout,
        headerTitle: String,
        headerLogo: CGImage?,
        footerTitle: String,
        footerLinkLabel: String,
        footerURL: String,
        footerQRCode: CGImage?
    ) {
        self.context = context
        self.layout = layout
        self.headerTitle = headerTitle
        self.headerLogo = headerLogo
        self.footerTitle = footerTitle
        self.footerLinkLabel = footerLinkLabel
        self.footerURL = footerURL
        self.footerQRCode = footerQRCode
        self.cursorY = layout.topY
    }

    mutating func beginPage() {
        context.beginPDFPage(nil)
        cursorY = layout.margin
        try? drawBrandHeader(title: headerTitle, logo: headerLogo)
        cursorY = layout.topY
    }

    mutating func drawTitle(_ text: String) throws {
        try draw(text: text, font: layout.titleFont, extraSpacing: 10)
    }

    mutating func drawBrandHeader(title: String, logo: CGImage?) throws {
        let headerHeight: CGFloat = 48
        ensureSpace(headerHeight + 12)
        let headerTop = cursorY

        if let logo {
            let logoRect = CGRect(x: layout.margin, y: headerTop, width: layout.logoSize, height: layout.logoSize)
            drawImage(logo, in: logoRect)
        } else {
            drawLogoFallback(in: CGRect(x: layout.margin, y: headerTop, width: layout.logoSize, height: layout.logoSize))
        }

        let textX = layout.margin + layout.logoSize + 12
        let textWidth = layout.contentWidth - layout.logoSize - 12
        try draw(
            text: title,
            font: layout.titleFont,
            color: layout.textColor,
            rect: CGRect(x: textX, y: headerTop + 2, width: textWidth, height: height(for: title, font: layout.titleFont)),
            extraSpacing: 0
        )

        cursorY = headerTop + headerHeight
        drawSeparator()
        addSpacing(14)
    }

    mutating func drawSectionTitle(_ text: String) throws {
        try draw(text: text, font: layout.sectionFont, extraSpacing: 6)
    }

    mutating func drawBodyLine(_ text: String) throws {
        try draw(text: text, font: layout.bodyFont, extraSpacing: layout.lineSpacing)
    }

    mutating func drawAppStorePanel(title: String, body: String, linkLabel: String, url: String, qrCode: CGImage?) throws {
        let panelHeight: CGFloat = 92
        let panelRect = CGRect(x: layout.margin, y: layout.footerTopY, width: layout.contentWidth, height: panelHeight)
        drawPanelBackground(panelRect)

        let qrRect = CGRect(
            x: panelRect.maxX - layout.qrCodeSize - 12,
            y: panelRect.minY + 12,
            width: layout.qrCodeSize,
            height: layout.qrCodeSize
        )
        if let qrCode {
            drawImage(qrCode, in: qrRect)
        }

        let textX = panelRect.minX + 14
        let textWidth = qrRect.minX - textX - 14
        try draw(text: title, font: layout.brandFont, color: layout.textColor, rect: CGRect(x: textX, y: panelRect.minY + 14, width: textWidth, height: 16), extraSpacing: 0)
        if !body.isEmpty {
            try draw(text: body, font: layout.bodyFont, color: layout.textColor, rect: CGRect(x: textX, y: panelRect.minY + 34, width: textWidth, height: 18), extraSpacing: 0)
        }
        try draw(text: "\(linkLabel): \(url)", font: layout.smallFont, color: layout.mutedTextColor, rect: CGRect(x: textX, y: panelRect.minY + 48, width: textWidth, height: 30), extraSpacing: 0)
    }

    mutating func drawHorizontalBarChart(title: String, rows: [PDFChartRow], maximumValue: Int? = nil) throws {
        guard !rows.isEmpty else { return }

        let chartRows = Array(rows.prefix(8))
        let rowHeight: CGFloat = 18
        let chartHeight = 24 + (CGFloat(chartRows.count) * rowHeight) + 10
        ensureSpace(chartHeight)

        try draw(text: title, font: layout.brandFont, extraSpacing: 8)

        let maxValue = max(maximumValue ?? chartRows.map(\.value).max() ?? 1, 1)
        let labelWidth: CGFloat = 132
        let valueWidth: CGFloat = 60
        let barX = layout.margin + labelWidth
        let barWidth = layout.contentWidth - labelWidth - valueWidth - 12

        for row in chartRows {
            let rowTop = cursorY
            try draw(
                text: row.label,
                font: layout.smallFont,
                color: layout.textColor,
                rect: CGRect(x: layout.margin, y: rowTop, width: labelWidth - 8, height: rowHeight),
                extraSpacing: 0
            )

            let trackRect = CGRect(x: barX, y: rowTop + 4, width: barWidth, height: 8)
            drawRect(trackRect, color: layout.chartTrackColor)
            let filledWidth = max(2, barWidth * CGFloat(row.value) / CGFloat(maxValue))
            drawRect(CGRect(x: barX, y: rowTop + 4, width: filledWidth, height: 8), color: layout.chartFillColor)

            try draw(
                text: row.detail,
                font: layout.smallFont,
                color: layout.mutedTextColor,
                rect: CGRect(x: barX + barWidth + 8, y: rowTop, width: valueWidth, height: rowHeight),
                extraSpacing: 0
            )

            cursorY = rowTop + rowHeight
        }

        addSpacing(8)
    }

    mutating func drawBlock(_ lines: [String]) throws {
        let estimatedHeight = lines.reduce(CGFloat.zero) { partial, line in
            partial + height(for: line, font: layout.bodyFont) + layout.lineSpacing
        } + 19

        if cursorY + estimatedHeight > layout.bottomY {
            endPage()
            beginPage()
        }

        for line in lines {
            try drawBodyLine(line)
        }

        addSpacing(8)
        drawSeparator()
        addSpacing(10)
    }

    mutating func addSpacing(_ value: CGFloat) {
        cursorY += value
    }

    private mutating func draw(text: String, font: CTFont, extraSpacing: CGFloat) throws {
        let textHeight = height(for: text, font: font)
        ensureSpace(textHeight + extraSpacing)

        let frameRect = CGRect(x: layout.margin, y: cursorY, width: layout.contentWidth, height: textHeight)
        try draw(text: text, font: font, color: layout.textColor, rect: frameRect, extraSpacing: extraSpacing)
    }

    private mutating func draw(text: String, font: CTFont, color: CGColor, rect frameRect: CGRect, extraSpacing: CGFloat) throws {
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

        cursorY = frameRect.maxY + extraSpacing
    }

    private mutating func ensureSpace(_ height: CGFloat) {
        if cursorY + height > layout.bottomY {
            endPage()
            beginPage()
        }
    }

    private func drawImage(_ image: CGImage, in rect: CGRect) {
        context.saveGState()
        context.interpolationQuality = .high
        context.draw(image, in: pdfRect(fromTopLeftRect: rect))
        context.restoreGState()
    }

    private func drawLogoFallback(in rect: CGRect) {
        let pdfRect = pdfRect(fromTopLeftRect: rect)
        context.saveGState()
        context.setFillColor(layout.brandFillColor)
        context.fillEllipse(in: pdfRect)
        context.setStrokeColor(layout.brandStrokeColor)
        context.setLineWidth(1)
        context.strokeEllipse(in: pdfRect)
        context.restoreGState()
    }

    private func drawPanelBackground(_ rect: CGRect) {
        let path = unsafe CGPath(roundedRect: pdfRect(fromTopLeftRect: rect), cornerWidth: 6, cornerHeight: 6, transform: nil)
        context.saveGState()
        context.setFillColor(layout.brandFillColor)
        context.addPath(path)
        context.fillPath()
        context.setStrokeColor(layout.brandStrokeColor)
        context.addPath(path)
        context.strokePath()
        context.restoreGState()
    }

    private func drawRect(_ rect: CGRect, color: CGColor) {
        context.saveGState()
        context.setFillColor(color)
        context.fill(pdfRect(fromTopLeftRect: rect))
        context.restoreGState()
    }

    private func drawSeparator() {
        let separatorRect = pdfRect(
            fromTopLeftRect: CGRect(x: layout.margin, y: cursorY, width: layout.contentWidth, height: 1)
        )
        context.saveGState()
        context.setFillColor(layout.separatorColor)
        context.fill(separatorRect)
        context.restoreGState()
    }

    private func height(for text: String, font: CTFont) -> CGFloat {
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
            CGSize(width: layout.contentWidth, height: .greatestFiniteMagnitude),
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

    mutating func endPage() {
        try? drawAppStorePanel(
            title: footerTitle,
            body: "",
            linkLabel: footerLinkLabel,
            url: footerURL,
            qrCode: footerQRCode
        )
        context.endPDFPage()
    }
}
