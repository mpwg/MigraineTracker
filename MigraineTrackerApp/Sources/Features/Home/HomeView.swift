import SwiftUI

struct HomeView: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        List {
            Section("Heute") {
                MetricRow(
                    title: "Keine Episode erfasst",
                    detail: "Starte mit einem schnellen Eintrag für Intensität, Symptome und Medikamente."
                )
            }

            Section("Schnellzugriffe") {
                Button {
                    selectedTab = .capture
                } label: {
                    Label("Episode erfassen", systemImage: "plus.circle.fill")
                }

                Button {
                    selectedTab = .history
                } label: {
                    Label("Verlauf öffnen", systemImage: "calendar")
                }

                Button {
                    selectedTab = .export
                } label: {
                    Label("PDF exportieren", systemImage: "square.and.arrow.up")
                }
            }

            Section("MVP-Fokus") {
                MetricRow(title: "Lokale Speicherung", detail: "Keine Anmeldung, kein Backend, keine Synchronisation.")
                MetricRow(title: "Wetterkontext", detail: "Wird später automatisch am Episodenzeitpunkt ergänzt.")
            }
        }
        .navigationTitle("Migraine Tracker")
    }
}

private struct MetricRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        HomeView(selectedTab: .constant(.home))
    }
}
