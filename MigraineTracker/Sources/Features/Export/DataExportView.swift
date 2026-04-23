import SwiftUI
import UniformTypeIdentifiers

struct DataExportView: View {
    @State private var controller: DataExportController

    init(appContainer: AppContainer) {
        _controller = State(initialValue: appContainer.makeDataExportController())
    }

    var body: some View {
        @Bindable var controller = controller

        Form {
            Section("Zeitraum") {
                DatePicker("Von", selection: $controller.startDate, displayedComponents: .date)
                DatePicker("Bis", selection: $controller.endDate, displayedComponents: .date)
            }

            Section("Bericht") {
                Text("Einträge im Zeitraum: \(controller.summary.episodeCount)")
                    .font(.headline)
                if controller.summary.episodeCount > 0 {
                    Text("Durchschnittliche Intensität: \(controller.summary.averageIntensity.formatted(.number.precision(.fractionLength(1))))/10")
                        .foregroundStyle(.secondary)
                }
                Text("Der PDF-Bericht von \(ProductBranding.displayName) wird lokal erzeugt und kann systemweit geteilt werden.")
                    .foregroundStyle(.secondary)
            }

            Section("Daten sichern") {
                Text("JSON5-Export enthält alle Einträge sowie eigene Medikamentenvorlagen, inklusive Papierkorb-Einträgen.")
                    .foregroundStyle(.secondary)

                Button("JSON5 erstellen") {
                    controller.createBackup()
                }

                Button("JSON5 importieren") {
                    controller.isImportingData = true
                }

                if let dataExportURL = controller.dataExportURL {
                    ShareLink(item: dataExportURL) {
                        Label("JSON5 teilen", systemImage: "square.and.arrow.up")
                    }
                }

                if let dataTransferMessage = controller.dataTransferMessage {
                    Text(dataTransferMessage)
                        .font(.subheadline)
                        .foregroundStyle(dataTransferMessage.contains("Fehler") ? .red : .secondary)
                }
            }

            Section("PDF") {
                Button("PDF erstellen") {
                    controller.createPDF()
                }
                .disabled(!controller.canExport)

                if let exportURL = controller.exportURL {
                    ShareLink(item: exportURL) {
                        Label("PDF teilen", systemImage: "square.and.arrow.up")
                    }
                }

                if let exportErrorMessage = controller.exportErrorMessage {
                    Text(exportErrorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }

            if controller.summary.records.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Keine Einträge im Zeitraum",
                        systemImage: "square.and.arrow.up",
                        description: Text("Passe den Zeitraum an, damit ein Bericht aus deinem Tagebuch erstellt werden kann.")
                    )
                }
            } else {
                Section("Vorschau") {
                    ForEach(controller.summary.records.prefix(8)) { record in
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
                        .brandGroupedRow()
                    }
                }
            }
        }
        .navigationTitle("Datenexport")
        .brandGroupedScreen()
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            controller.reloadSummary()
        }
        .onChange(of: controller.startDate) { _, _ in
            controller.reloadSummary()
        }
        .onChange(of: controller.endDate) { _, _ in
            controller.reloadSummary()
        }
        .fileImporter(
            isPresented: $controller.isImportingData,
            allowedContentTypes: [.migraineTrackerJSON5, .json, .plainText]
        ) { result in
            controller.importBackup(from: result)
        }
    }
}

#Preview {
    Text("Preview nicht verfügbar")
}
