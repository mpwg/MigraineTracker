import SwiftUI

struct ProductInformationView: View {
    private let privacyURL = URL(string: "https://s3.privyr.com/privacy/privacy-policy.html?d=eyJlbWFpbCI6ImZldXJpZy5mZXVlcjdhQGljbG91ZC5jb20iLCJjb21wYW55IjoiTWF0dGhpYXMgV2FsbG5lci1H6WhyaSIsImdlbl9hdCI6IjIwMjYtMDQtMDlUMTE6MjI6MjUuOTYzWiJ9")!
    private let weatherProviderURL = WeatherAttribution.providerURL
    private let weatherLicenceURL = WeatherAttribution.licenceURL

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
                    Text("\(ProductBranding.displayName) speichert deine Angaben ausschließlich lokal auf diesem Gerät. Die App hilft dir, Migräne, Kopfschmerzen und andere Schmerzereignisse für dich und für Arztgespräche strukturiert festzuhalten.")
                    Text("Sie ersetzt keine medizinische Diagnose, keine Therapieentscheidung und keinen Notfallkontakt.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Datenschutz") {
                infoRow(
                    title: "Lokale Gesundheitsdaten",
                    detail: "Episoden, Medikamente, Notizen, Trigger, Symptome und Wetter-Snapshots werden lokal auf dem Gerät gespeichert."
                )
                infoRow(
                    title: "Optionale iCloud-Synchronisation",
                    detail: "Cloud-Sync ist freiwillig. Ohne Aktivierung bleiben die Daten ausschließlich lokal auf diesem Gerät."
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
                    title: "Standort nur für Wetter",
                    detail: "Die App fragt beim Wetterabruf nach dem ungefähren Standort. Die Koordinaten werden nicht gespeichert."
                )
                infoRow(
                    title: "Keine Health-Anbindung",
                    detail: "Apple Health und andere sensible Systemdaten sind in Version 1 nicht integriert. Termine verwaltet die App ausschließlich lokal."
                )
            }

            Section("Wetterdaten") {
                infoRow(
                    title: "Quelle",
                    detail: "Wetterdaten von Open-Meteo, basierend auf DWD ICON."
                )
                infoRow(
                    title: "Lizenz",
                    detail: "Open-Meteo stellt diese Daten unter CC BY 4.0 bereit. Eine sichtbare Attribution ist erforderlich."
                )

                Link(destination: weatherProviderURL) {
                    Label("Open-Meteo öffnen", systemImage: "link")
                }

                Link(destination: weatherLicenceURL) {
                    Label("CC BY 4.0 anzeigen", systemImage: "doc.text")
                }
            }

            Section("Medizinische Einordnung") {
                infoRow(
                    title: "Dokumentationshilfe",
                    detail: "Die App hilft dir, Migräne, Kopfschmerzen, Medikamente und mögliche Auslöser strukturiert festzuhalten."
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
                    detail: "Neuer Eintrag, Tagebuch, Medikamente, Export und hilfreicher Kontext wie Wetter."
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

                Link(destination: ProductBranding.supportURL) {
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
        .brandGroupedScreen()
    }

    private var repositoryURL: URL { ProductBranding.repositoryURL }

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
        .brandGroupedRow()
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
