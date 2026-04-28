import SwiftUI
import UniformTypeIdentifiers

struct DataExportView: View {
    @State private var controller: DataExportController

    init(dependencies: DataExportFeatureDependencies) {
        _controller = State(initialValue: dependencies.makeDataExportController())
    }

    var body: some View {
        @Bindable var controller = controller

        Form {
            Section("PDF") {
                if let exportURL = controller.exportURL {
                    ShareLink(item: exportURL) {
                        Label("PDF teilen", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button {
                        controller.createPDF()
                    } label: {
                        Label("PDF vorbereiten", systemImage: "doc.richtext")
                    }
                    .disabled(!controller.canExport || controller.isLoadingSummary || controller.isPreparingPDF)
                }

                Toggle("Alle Details", isOn: $controller.includeAllDetails)

                Text("Wenn aktiviert, enthält das PDF zusätzlich die detaillierten Einträge mit Medikamenten, Triggern, Wetterdaten, Apple-Health-Kontext und Notizen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Geteilte PDFs verlassen die geschützte App-Sandbox. Speichere oder sende sie nur an Orte, denen du vertraust.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let exportErrorMessage = controller.exportErrorMessage {
                    Text(exportErrorMessage)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.symiCoral)
                }

                if controller.isLoadingSummary || controller.isPreparingPDF {
                    HStack {
                        ProgressView()
                        Text(controller.isLoadingSummary ? "Berichtsdaten werden vorbereitet." : "PDF wird vorbereitet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Zeitraum") {
                HStack(spacing: SymiSpacing.lg) {
                    dateField(title: "Von", selection: $controller.startDate)
                    dateField(title: "Bis", selection: $controller.endDate)
                }

                Text("Standardmäßig startet der Zeitraum am ersten Tag des vorvorherigen Monats und endet inklusive heute.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Backup") {
                Text("Das Backup enthält alle Einträge, eigene Medikamentenvorlagen, Wetter-Snapshots und gespeicherten Apple-Health-Kontext, inklusive Papierkorb-Einträgen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Geteilte Backup-Dateien können außerhalb der App-Sandbox liegen und dort anderen Schutzregeln unterliegen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Backup erstellen") {
                    controller.createBackup()
                }

                Button("Backup einlesen") {
                    controller.isImportingData = true
                }

                if controller.isPreparingImportPreview || controller.isApplyingImport {
                    HStack {
                        ProgressView()
                        Text(controller.isPreparingImportPreview ? "Backup wird geprüft." : "Backup wird importiert.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let importPreview = controller.importPreview {
                    BackupImportPreviewView(preview: importPreview)

                    HStack {
                        Button("Abbrechen", role: .cancel) {
                            controller.cancelImportPreview()
                        }

                        Button("Import ausführen", role: importPreview.conflicts.isEmpty ? nil : .destructive) {
                            controller.confirmImport()
                        }
                        .disabled(controller.isApplyingImport)
                    }
                }

                if let dataExportURL = controller.dataExportURL {
                    ShareLink(item: dataExportURL) {
                        Label("Backup teilen", systemImage: "square.and.arrow.up")
                    }
                }

                if let rollbackURL = controller.importRollbackBackupURL {
                    ShareLink(item: rollbackURL) {
                        Label("Rollback-Backup teilen", systemImage: "arrow.uturn.backward.circle")
                    }
                }

                if let dataTransferMessage = controller.dataTransferMessage {
                    Text(dataTransferMessage)
                        .font(.subheadline)
                        .foregroundStyle(dataTransferMessage.contains("Fehler") ? AppTheme.symiCoral : AppTheme.symiTextSecondary)
                }
            }
        }
        .navigationTitle("Alles im Blick")
        .brandGroupedScreen()
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            controller.loadInitialSummary()
        }
        .onChange(of: controller.startDate) { _, _ in
            controller.scheduleSummaryReload()
        }
        .onChange(of: controller.endDate) { _, _ in
            controller.scheduleSummaryReload()
        }
        .onChange(of: controller.includeAllDetails) { _, _ in
            controller.schedulePDFPreparation()
        }
        .fileImporter(
            isPresented: $controller.isImportingData,
            allowedContentTypes: [.symiJSON5, .json, .plainText]
        ) { result in
            controller.importBackup(from: result)
        }
    }

    private func dateField(title: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: SymiSpacing.compact) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            DatePicker(
                title,
                selection: selection,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BackupImportPreviewView: View {
    let preview: BackupImportPreview

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.compact) {
            Text("Import-Vorschau")
                .font(.headline)

            Text(summaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let dateRange = preview.dateRange {
                Text("Zeitraum: \(dateRange.start.formatted(date: .abbreviated, time: .omitted)) bis \(dateRange.end.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !preview.conflicts.isEmpty {
                ForEach(preview.conflicts, id: \.self) { conflict in
                    Label(conflict, systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.symiCoral)
                }
            }
        }
        .padding(.vertical, SymiSpacing.xs)
    }

    private var summaryText: String {
        [
            "\(preview.newEpisodes) neu",
            "\(preview.changedEpisodes) geändert",
            "\(preview.deletedEpisodes) gelöscht",
            "\(preview.conflicts.count) Konflikte"
        ].joined(separator: " · ")
    }
}

#Preview {
    Text("Preview nicht verfügbar")
}
