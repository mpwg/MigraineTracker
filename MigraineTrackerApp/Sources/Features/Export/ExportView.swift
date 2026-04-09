import SwiftData
import SwiftUI

struct ExportView: View {
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
    @State private var endDate = Date()
    @State private var exportURL: URL?
    @State private var exportErrorMessage: String?
    @Query(sort: [SortDescriptor(\Episode.startedAt, order: .reverse)]) private var episodes: [Episode]

    var body: some View {
        let summary = exportSummary

        Form {
            Section("Zeitraum") {
                DatePicker("Von", selection: $startDate, displayedComponents: .date)
                DatePicker("Bis", selection: $endDate, displayedComponents: .date)
            }

            Section("Bericht") {
                Text("Episoden im Zeitraum: \(summary.episodeCount)")
                    .font(.headline)
                if summary.episodeCount > 0 {
                    Text("Durchschnittliche Intensität: \(summary.averageIntensity.formatted(.number.precision(.fractionLength(1))))/10")
                        .foregroundStyle(.secondary)
                }
                Text("Der PDF-Export wird lokal erzeugt und über das iOS-Share-Sheet geteilt.")
                    .foregroundStyle(.secondary)
            }

            Section("Aktionen") {
                Button("PDF erstellen") {
                    createPDF()
                }
                .disabled(!canExport)
                .accessibilityHint(canExport ? "Erstellt einen lokalen PDF-Bericht für den gewählten Zeitraum." : "Wähle zuerst einen gültigen Zeitraum mit mindestens einer Episode.")

                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("PDF teilen", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityHint("Öffnet das Teilen-Menü für den bereits erzeugten PDF-Bericht.")
                }

                if let exportErrorMessage {
                    Text(exportErrorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .accessibilityLabel("Fehler: \(exportErrorMessage)")
                }
            }

            if summary.records.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Keine Episoden im Zeitraum",
                        systemImage: "square.and.arrow.up",
                        description: Text("Passe den Zeitraum an, damit ein PDF-Bericht erstellt werden kann.")
                    )
                }
            } else {
                Section("Vorschau") {
                    ForEach(summary.records.prefix(5)) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.startedAt, style: .date)
                                .font(.headline)
                            Text("\(record.type) · Intensität \(record.intensity)/10")
                                .foregroundStyle(.secondary)
                            if !record.medications.isEmpty {
                                Text(record.medications.map(\.name).joined(separator: ", "))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if let weather = record.weather, !weather.condition.isEmpty {
                                Text("Wetter: \(weather.condition)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(previewAccessibilityLabel(for: record))
                    }
                }
            }
        }
        .navigationTitle("Export")
    }

    private var canExport: Bool {
        !exportSummary.records.isEmpty && startDate <= endDate
    }

    private var exportSummary: ExportPeriodSummary {
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
        let filtered = episodes
            .filter { $0.startedAt >= startDate && $0.startedAt <= endOfDay }
            .map(EpisodeExportRecord.init)

        return ExportPeriodSummary(startDate: startDate, endDate: endDate, records: filtered)
    }

    private func createPDF() {
        exportErrorMessage = nil
        exportURL = nil

        guard startDate <= endDate else {
            exportErrorMessage = "Der Zeitraum ist ungültig."
            return
        }

        guard !exportSummary.records.isEmpty else {
            exportErrorMessage = "Für den gewählten Zeitraum gibt es keine Episoden."
            return
        }

        do {
            exportURL = try PDFExportWriter.write(summary: exportSummary)
        } catch {
            exportErrorMessage = "Der PDF-Export konnte nicht erstellt werden."
        }
    }

    private func previewAccessibilityLabel(for record: EpisodeExportRecord) -> String {
        var parts = [
            record.startedAt.formatted(date: .complete, time: .shortened),
            record.type,
            "Intensität \(record.intensity) von 10"
        ]

        if !record.medications.isEmpty {
            parts.append("Medikamente: \(record.medications.map(\.name).joined(separator: ", "))")
        }

        if let weather = record.weather, !weather.condition.isEmpty {
            parts.append("Wetter: \(weather.condition)")
        }

        return parts.joined(separator: ", ")
    }
}

#Preview {
    NavigationStack {
        ExportView()
    }
}
