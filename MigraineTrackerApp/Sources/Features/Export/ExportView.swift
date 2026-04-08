import SwiftUI

struct ExportView: View {
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
    @State private var endDate = Date()

    var body: some View {
        Form {
            Section("Zeitraum") {
                DatePicker("Von", selection: $startDate, displayedComponents: .date)
                DatePicker("Bis", selection: $endDate, displayedComponents: .date)
            }

            Section("Bericht") {
                Text("Der PDF-Export wird lokal erzeugt und später über das iOS-Share-Sheet geteilt.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Export")
    }
}

#Preview {
    NavigationStack {
        ExportView()
    }
}
