import SwiftUI

struct ProductInformationView: View {
    private let privacyURL = URL(string: "https://s3.privyr.com/privacy/privacy-policy.html?d=eyJlbWFpbCI6ImZldXJpZy5mZXVlcjdhQGljbG91ZC5jb20iLCJjb21wYW55IjoiTWF0dGhpYXMgV2FsbG5lci1H6WhyaSIsImdlbl9hdCI6IjIwMjYtMDQtMDlUMTE6MjI6MjUuOTYzWiJ9")!
    private let repositoryURL = URL(string: "https://github.com/mpwg/MigraineTracker")!
    private let issuesURL = URL(string: "https://github.com/mpwg/MigraineTracker/issues")!

    enum Mode {
        case standard
        case onboarding
    }

    let mode: Mode
    var acknowledge: (() -> Void)? = nil

    var body: some View {
        List {
            if mode == .onboarding {
                Section("Bevor du startest") {
                    Text("Migraine Tracker speichert deine Angaben ausschließlich lokal auf diesem Gerät. Die App dient der Dokumentation für dich und für Arztgespräche.")
                    Text("Sie ersetzt keine medizinische Diagnose, keine Therapieentscheidung und keinen Notfallkontakt.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Datenschutz") {
                infoRow(
                    title: "Lokale Gesundheitsdaten",
                    detail: "Episoden, Medikamente, Notizen, Trigger, Symptome und optionale Wetterangaben bleiben auf dem Gerät."
                )
                infoRow(
                    title: "Kein Account, kein Backend",
                    detail: "Es gibt keine Anmeldung, keine Cloud-Synchronisation und keine Server-Speicherung."
                )
                infoRow(
                    title: "PDF-Export nur auf deinen Befehl",
                    detail: "Ein Bericht wird erst lokal erzeugt, wenn du ihn exportierst und bewusst teilst."
                )

                Link(destination: privacyURL) {
                    Label("Datenschutzerklärung öffnen", systemImage: "link")
                }
            }

            Section("Berechtigungen") {
                infoRow(
                    title: "Derzeit keine Standortfreigabe",
                    detail: "Wetterdaten werden im aktuellen Stand nur manuell eingegeben. Deshalb fragt die App keine Standortberechtigung an."
                )
                infoRow(
                    title: "Keine Health- oder Kalender-Anbindung",
                    detail: "Apple Health, Arzttermine und andere Systemdaten sind in Version 1 nicht integriert."
                )
            }

            Section("Medizinische Einordnung") {
                infoRow(
                    title: "Dokumentationshilfe",
                    detail: "Die App hilft dir, Migräneepisoden, Medikamente und Auslöser strukturiert festzuhalten."
                )
                infoRow(
                    title: "Keine Diagnose, keine Therapieempfehlung",
                    detail: "Inhalte in der App sind keine ärztliche Einschätzung und keine Behandlungsempfehlung."
                )
                infoRow(
                    title: "Bei akuten Beschwerden medizinisch abklären",
                    detail: "Bei Unsicherheit, starken neuen Symptomen oder Notfällen ist medizinische Hilfe erforderlich."
                )
            }

            Section("Version 1") {
                infoRow(
                    title: "Aktueller Umfang",
                    detail: "Episode anlegen, Medikamente erfassen, Verlauf ansehen und PDF exportieren."
                )
                infoRow(
                    title: "Plattform und Sprache",
                    detail: "Version 1 ist auf iPhone und Deutsch ausgelegt."
                )
                infoRow(
                    title: "Weiterentwicklung",
                    detail: "Dies ist Version 1. Weitere Punkte können später folgen."
                )
            }

            Section("Open Source") {
                infoRow(
                    title: "Lizenz",
                    detail: "Das Projekt steht unter der GNU GPL v3."
                )
                infoRow(
                    title: "Feedback und Ideen",
                    detail: "Weitere Punkte können gerne als GitHub-Issue eingemeldet werden."
                )
                infoRow(
                    title: "Beiträge",
                    detail: "Pull Requests sind willkommen."
                )

                Link(destination: repositoryURL) {
                    Label("Projekt auf GitHub öffnen", systemImage: "link")
                }

                Link(destination: issuesURL) {
                    Label("GitHub-Issues öffnen", systemImage: "exclamationmark.bubble")
                }
            }

            if mode == .onboarding {
                Section {
                    Button("Verstanden") {
                        acknowledge?()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle("Datenschutz und Hinweise")
    }

    @ViewBuilder
    private func infoRow(title: String, detail: String) -> some View {
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

#Preview("Standard") {
    NavigationStack {
        ProductInformationView(mode: .standard)
    }
}

#Preview("Onboarding") {
    NavigationStack {
        ProductInformationView(mode: .onboarding)
    }
}
