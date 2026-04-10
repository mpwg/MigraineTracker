import SwiftData
import SwiftUI

struct ExportView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
    @State private var endDate = Date()
    @State private var exportURL: URL?
    @State private var exportErrorMessage: String?
    @State private var dataExportURL: URL?
    @State private var dataTransferMessage: String?
    @State private var isImportingData = false
    @Query(sort: [SortDescriptor(\Episode.startedAt, order: .reverse)]) private var episodes: [Episode]
    @Query(filter: #Predicate<MedicationDefinition> { $0.isCustom }, sort: [SortDescriptor(\MedicationDefinition.sortOrder)]) private var customMedicationDefinitions: [MedicationDefinition]

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

            Section("Daten sichern") {
                Text("JSON5-Export enthält alle Episoden sowie eigene Medikamentenvorlagen.")
                    .foregroundStyle(.secondary)

                Button("JSON5 erstellen") {
                    createDataExport()
                }
                .disabled(!hasTransferData)
                .accessibilityHint(hasTransferData ? "Erstellt eine lokale JSON5-Sicherungsdatei mit allen Episoden." : "Lege zuerst Episoden oder eigene Medikamentenvorlagen an, damit ein JSON5-Export erstellt werden kann.")

                Button("JSON5 importieren") {
                    isImportingData = true
                }
                .accessibilityHint("Importiert eine zuvor exportierte JSON5-Datei und ergänzt oder aktualisiert vorhandene Daten.")

                if let dataExportURL {
                    ShareLink(item: dataExportURL) {
                        Label("JSON5 teilen", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityHint("Öffnet das Teilen-Menü für die bereits erzeugte JSON5-Datei.")
                }

                if let dataTransferMessage {
                    Text(dataTransferMessage)
                        .font(.subheadline)
                        .foregroundStyle(dataTransferMessage.contains("Fehler") ? .red : .secondary)
                        .accessibilityLabel(dataTransferMessage)
                }
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
        .fileImporter(
            isPresented: $isImportingData,
            allowedContentTypes: [.migraineTrackerJSON5, .json, .plainText]
        ) { result in
            importData(from: result)
        }
    }

    private var canExport: Bool {
        !exportSummary.records.isEmpty && startDate <= endDate
    }

    private var hasTransferData: Bool {
        !episodes.isEmpty || !customMedicationDefinitions.isEmpty
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

    private func createDataExport() {
        dataTransferMessage = nil
        dataExportURL = nil

        guard hasTransferData else {
            dataTransferMessage = "Es sind noch keine Daten für einen JSON5-Export vorhanden."
            return
        }

        do {
            let snapshot = DataTransferSnapshot(
                episodes: episodes,
                customMedicationDefinitions: customMedicationDefinitions
            )
            dataExportURL = try snapshot.writeToTemporaryFile()
            dataTransferMessage = "JSON5-Datei wurde lokal erstellt."
        } catch {
            dataTransferMessage = "Fehler beim Erstellen der JSON5-Datei."
        }
    }

    private func importData(from result: Result<URL, Error>) {
        dataTransferMessage = nil

        do {
            let url = try result.get()
            let snapshot = try DataTransferSnapshot.load(from: url)
            try snapshot.merge(into: modelContext)
            dataTransferMessage = "JSON5-Daten wurden importiert."
        } catch CocoaError.userCancelled {
            return
        } catch {
            dataTransferMessage = "Fehler beim Import der JSON5-Datei."
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
