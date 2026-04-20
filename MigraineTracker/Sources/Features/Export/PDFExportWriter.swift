import CoreGraphics
import CoreText
import Foundation
import PDFKit

enum PDFExportWriter {
    static func write(summary: ExportPeriodSummary) throws -> URL {
        let fileName = "Schmerztagebuch-Migraene-Co-\(dateStamp(summary.startDate))-\(dateStamp(summary.endDate)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let layout = PDFLayout(pageRect: pageRect)

        try writeRawPDF(summary: summary, to: url, layout: layout)
        try finalizeDocument(at: url)

        return url
    }

    private static func writeRawPDF(summary: ExportPeriodSummary, to url: URL, layout: PDFLayout) throws {
        var mediaBox = layout.pageRect
        let metadata = [
            kCGPDFContextCreator: ProductBranding.displayName,
            kCGPDFContextAuthor: ProductBranding.displayName,
            kCGPDFContextTitle: "\(ProductBranding.displayName) Bericht"
        ] as CFDictionary

        guard let consumer = CGDataConsumer(url: url as CFURL),
              let context = unsafe CGContext(consumer: consumer, mediaBox: &mediaBox, metadata)
        else {
            throw PDFExportError.contextCreationFailed
        }

        var page = PDFPageContext(context: context, layout: layout)
        page.beginPage()
        try page.drawTitle("\(ProductBranding.displayName) Bericht")
        try page.drawBodyLine("Zeitraum: \(summary.startDate.formatted(date: .abbreviated, time: .omitted)) bis \(summary.endDate.formatted(date: .abbreviated, time: .omitted))")
        try page.drawBodyLine("Einträge: \(summary.episodeCount)")

        if summary.episodeCount > 0 {
            try page.drawBodyLine("Durchschnittliche Intensität: \(summary.averageIntensity.formatted(.number.precision(.fractionLength(1))))/10")
        }

        if !summary.medicationNames.isEmpty {
            try page.drawBodyLine("Dokumentierte Medikamente: \(summary.medicationNames.joined(separator: ", "))")
        }

        page.addSpacing(18)
        try page.drawSectionTitle("Tagebuchübersicht")

        for record in summary.records {
            try page.drawBlock(exportLines(for: record))
        }

        page.endPage()
        context.closePDF()
    }

    private static func finalizeDocument(at url: URL) throws {
        guard let document = PDFDocument(url: url), document.pageCount > 0 else {
            throw PDFExportError.documentValidationFailed
        }

        document.documentAttributes = [
            PDFDocumentAttribute.titleAttribute: "\(ProductBranding.displayName) Bericht",
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
        lines.append("\(record.startedAt.formatted(date: .abbreviated, time: .shortened)) · \(record.type) · Intensität \(record.intensity)/10")

        if let endedAt = record.endedAt {
            lines.append("Ende: \(endedAt.formatted(date: .abbreviated, time: .shortened))")
        }

        if !record.symptoms.isEmpty {
            lines.append("Symptome: \(record.symptoms.joined(separator: ", "))")
        }

        if !record.triggers.isEmpty {
            lines.append("Trigger: \(record.triggers.joined(separator: ", "))")
        }

        if !record.functionalImpact.isEmpty {
            lines.append("Einschränkung: \(record.functionalImpact)")
        }

        if !record.medications.isEmpty {
            let medicationText = record.medications.map { medication in
                let dosageText = medication.dosage.isEmpty ? medication.category : "\(medication.category), \(medication.dosage)"
                let quantityText = medication.quantity > 1 ? ", Anzahl: \(medication.quantity)" : ""
                let effectivenessText = medication.effectiveness == MedicationEffectiveness.partial.rawValue ? "" : ", Wirkung: \(medication.effectiveness)"
                return "\(medication.name) (\(dosageText)\(quantityText)\(effectivenessText))"
            }
            lines.append("Medikamente: \(medicationText.joined(separator: "; "))")
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
                parts.append("\(humidity.formatted(.number.precision(.fractionLength(0)))) % Luftfeuchte")
            }
            if let pressure = weather.pressure {
                parts.append("\(pressure.formatted(.number.precision(.fractionLength(0)))) hPa")
            }
            if let precipitation = weather.precipitation {
                parts.append("\(precipitation.formatted(.number.precision(.fractionLength(1)))) mm Niederschlag")
            }
            if !weather.source.isEmpty {
                parts.append("Quelle: \(weather.source)")
            }

            if !parts.isEmpty {
                lines.append("Wetter: \(parts.joined(separator: ", "))")
            }
        }

        if !record.notes.isEmpty {
            lines.append("Notiz: \(record.notes)")
        }

        return lines
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

private struct PDFLayout {
    let pageRect: CGRect
    let margin: CGFloat = 40
    let titleFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 22, nil)
    let sectionFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 15, nil)
    let bodyFont = CTFontCreateWithName("Helvetica" as CFString, 11, nil)
    let textColor = CGColor(gray: 0.05, alpha: 1)
    let separatorColor = CGColor(gray: 0.82, alpha: 1)
    let lineSpacing: CGFloat = 5

    var contentWidth: CGFloat { pageRect.width - (margin * 2) }
    var topY: CGFloat { margin }
    var bottomY: CGFloat { pageRect.height - margin }
}

private struct PDFPageContext {
    let context: CGContext
    let layout: PDFLayout
    var cursorY: CGFloat = 0

    init(context: CGContext, layout: PDFLayout) {
        self.context = context
        self.layout = layout
        self.cursorY = layout.topY
    }

    mutating func beginPage() {
        context.beginPDFPage(nil)
        cursorY = layout.topY
    }

    mutating func drawTitle(_ text: String) throws {
        try draw(text: text, font: layout.titleFont, extraSpacing: 10)
    }

    mutating func drawSectionTitle(_ text: String) throws {
        try draw(text: text, font: layout.sectionFont, extraSpacing: 6)
    }

    mutating func drawBodyLine(_ text: String) throws {
        try draw(text: text, font: layout.bodyFont, extraSpacing: layout.lineSpacing)
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
        if cursorY + textHeight + extraSpacing > layout.bottomY {
            endPage()
            beginPage()
        }

        let frameRect = CGRect(x: layout.margin, y: cursorY, width: layout.contentWidth, height: textHeight)
        let attributedText = NSAttributedString(
            string: text,
            attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): layout.textColor
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
        context.endPDFPage()
    }
}
