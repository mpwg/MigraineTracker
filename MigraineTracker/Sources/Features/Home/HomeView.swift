import SwiftUI

struct HomeView: View {
    let appContainer: AppContainer
    @Binding var selectedTab: AppTab
    @State private var overview: HomeOverviewData = .init(latestEpisode: nil, episodeCount: 0)

    var body: some View {
        List {
            Section("Heute") {
                if let latestEpisode = overview.latestEpisode {
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
                    Label("Sync & Datenexport", systemImage: "arrow.trianglehead.2.clockwise.icloud")
                }
                .accessibilityHint("Öffnet den Bereich für Sync-Status, Cloud-Daten und Exporte.")

                NavigationLink {
                    ProductInformationView(mode: .standard)
                } label: {
                    Label("Datenschutz und Hinweise", systemImage: "hand.raised")
                }
            }

            Section("Version 1") {
                MetricRow(title: "Gespeicherte Episoden", detail: "\(overview.episodeCount)")
                MetricRow(title: "Lokale Speicherung", detail: "Lokale Primärdaten mit optionaler iCloud-Synchronisation.")
                MetricRow(title: "Wetterkontext", detail: "Wird automatisch über Open-Meteo auf Basis von DWD ICON ergänzt, wenn Standortfreigabe vorliegt.")
            }

            Section("Medizinischer Hinweis") {
                MetricRow(
                    title: "Tracking statt Diagnose",
                    detail: "Die App dokumentiert Episoden und Medikamente, gibt aber keine Diagnose und keine Therapieempfehlung."
                )
//                MetricRow(
//                    title: "Aktuell keine Systemberechtigung nötig",
 //                   detail: "Standort- und Health-Daten werden in Version 1 nicht abgefragt."
//                )
            }
        }
        .navigationTitle("Migraine Tracker")
        .task {
            overview = (try? LoadHomeOverviewUseCase(repository: appContainer.episodeRepository).execute()) ?? .init(latestEpisode: nil, episodeCount: 0)
        }
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
    Text("Preview nicht verfügbar")
}
