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
            Section("PDF") {
                if let exportURL = controller.exportURL {
                    ShareLink(item: exportURL) {
                        Label("PDF teilen", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Label("PDF teilen", systemImage: "square.and.arrow.up")
                        .foregroundStyle(.secondary)
                }

                Toggle("Alle Details", isOn: $controller.includeAllDetails)

                Text("Wenn aktiviert, enthält das PDF zusätzlich die detaillierten Einträge mit Medikamenten, Triggern, Wetterdaten, Apple-Health-Kontext und Notizen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let exportErrorMessage = controller.exportErrorMessage {
                    Text(exportErrorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }

            Section("Zeitraum") {
                HStack(spacing: 16) {
                    dateField(title: "Von", selection: $controller.startDate)
                    dateField(title: "Bis", selection: $controller.endDate)
                }

                Text("Standardmäßig startet der Zeitraum am ersten Tag des vorvorherigen Monats und endet inklusive heute.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Backup") {
                Text("Das Backup enthält alle Einträge sowie eigene Medikamentenvorlagen, inklusive Papierkorb-Einträgen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Backup erstellen") {
                    controller.createBackup()
                }

                Button("Backup einlesen") {
                    controller.isImportingData = true
                }

                if let dataExportURL = controller.dataExportURL {
                    ShareLink(item: dataExportURL) {
                        Label("Backup teilen", systemImage: "square.and.arrow.up")
                    }
                }

                if let dataTransferMessage = controller.dataTransferMessage {
                    Text(dataTransferMessage)
                        .font(.subheadline)
                        .foregroundStyle(dataTransferMessage.contains("Fehler") ? .red : .secondary)
                }
            }
        }
        .navigationTitle("Datenexport")
        .brandGroupedScreen()
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            Task { await controller.reloadSummary() }
        }
        .onChange(of: controller.startDate) { _, _ in
            Task { await controller.reloadSummary() }
        }
        .onChange(of: controller.endDate) { _, _ in
            Task { await controller.reloadSummary() }
        }
        .onChange(of: controller.includeAllDetails) { _, _ in
            Task { await controller.updatePreparedPDF() }
        }
        .fileImporter(
            isPresented: $controller.isImportingData,
            allowedContentTypes: [.migraineTrackerJSON5, .json, .plainText]
        ) { result in
            controller.importBackup(from: result)
        }
    }

    private func dateField(title: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
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

#Preview {
    Text("Preview nicht verfügbar")
}
