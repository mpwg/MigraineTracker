import SwiftUI

struct HistoryView: View {
    var body: some View {
        List {
            Section("Verlauf") {
                Text("Noch keine Episoden gespeichert.")
                Text("Die Kalender- und Detailansicht wird in den nächsten Issues aufgebaut.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Verlauf")
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
}
