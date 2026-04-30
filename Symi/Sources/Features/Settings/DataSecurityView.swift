import SwiftUI

struct DataSecurityView: View {
    let dependencies: DataExportFeatureDependencies
    @State private var showsResetInformation = false

    var body: some View {
        List {
            Section {
                NavigationLink {
                    DataBackupSettingsView(dependencies: dependencies)
                } label: {
                    Label("Backup erstellen", systemImage: "externaldrive.badge.plus")
                }

                NavigationLink {
                    DataBackupSettingsView(dependencies: dependencies)
                } label: {
                    Label("Daten exportieren", systemImage: "square.and.arrow.up")
                }

                Button(role: .destructive) {
                    showsResetInformation = true
                } label: {
                    Label("Daten zurücksetzen", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Daten & Sicherheit")
        .brandGroupedScreen()
        .alert("Daten zurücksetzen", isPresented: $showsResetInformation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Das endgültige Löschen aller Daten ist derzeit nicht direkt aus dieser Ansicht verfügbar.")
        }
    }
}
