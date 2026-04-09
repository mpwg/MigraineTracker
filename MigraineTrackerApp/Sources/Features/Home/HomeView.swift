import SwiftData
import SwiftUI

struct HomeView: View {
    @Binding var selectedTab: AppTab
    @Query(sort: [SortDescriptor(\Episode.startedAt, order: .reverse)]) private var episodes: [Episode]

    var body: some View {
        List {
            Section("Heute") {
                if let latestEpisode = episodes.first {
                    MetricRow(
                        title: "Letzte Episode: \(latestEpisode.type.rawValue)",
                        detail: "Intensität \(latestEpisode.intensity)/10 · \(latestEpisode.startedAt.formatted(date: .abbreviated, time: .shortened))"
                    )
                } else {
                    MetricRow(
                        title: "Keine Episode erfasst",
                        detail: "Starte mit einem schnellen Eintrag für Intensität, Symptome und Medikamente."
                    )
                }
            }

            Section("Schnellzugriffe") {
                Button {
                    selectedTab = .capture
                } label: {
                    Label("Episode erfassen", systemImage: "plus.circle.fill")
                }
                .accessibilityHint("Wechselt direkt zum schnellen Erfassungsformular.")

                Button {
                    selectedTab = .history
                } label: {
                    Label("Verlauf öffnen", systemImage: "calendar")
                }
                .accessibilityHint("Zeigt die gespeicherten Episoden in Liste oder Kalender.")

                Button {
                    selectedTab = .export
                } label: {
                    Label("PDF exportieren", systemImage: "square.and.arrow.up")
                }
                .accessibilityHint("Öffnet den Exportbereich für Arztberichte als PDF.")

                NavigationLink {
                    ProductInformationView(mode: .standard)
                } label: {
                    Label("Datenschutz und Hinweise", systemImage: "hand.raised")
                }
            }

            Section("MVP-Fokus") {
                MetricRow(title: "Gespeicherte Episoden", detail: "\(episodes.count)")
                MetricRow(title: "Lokale Speicherung", detail: "Keine Anmeldung, kein Backend, keine Synchronisation.")
                MetricRow(title: "Wetterkontext", detail: "Kann optional manuell pro Episode ergänzt und lokal gespeichert werden.")
            }

            Section("Medizinischer Hinweis") {
                MetricRow(
                    title: "Tracking statt Diagnose",
                    detail: "Die App dokumentiert Episoden und Medikamente, gibt aber keine Diagnose und keine Therapieempfehlung."
                )
                MetricRow(
                    title: "Aktuell keine Systemberechtigung nötig",
                    detail: "Standort oder Health-Daten werden im aktuellen MVP nicht abgefragt."
                )
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
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        HomeView(selectedTab: .constant(.home))
    }
}
