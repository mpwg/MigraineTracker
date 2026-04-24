import SwiftUI

struct ProductInformationView: View {
    private let privacyURL = URL(string: "https://symiapp.com/privacy")!

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
                    Text("\(ProductBranding.displayName) ist dein ruhiges Migräne Tagebuch. Du hältst fest, was passiert ist, und entscheidest selbst, welche zusätzlichen Daten du einbeziehst.")
                    Text("Die App unterstützt deine Dokumentation. Sie ersetzt keine medizinische Diagnose, keine Therapieentscheidung und keinen Notfallkontakt.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Mehr gute Tage") {
                infoRow(
                    title: "In Sekunden eintragen",
                    detail: "Du dokumentierst Zeitpunkt, Intensität, hilfreiche Hinweise und persönliche Notizen ohne Formulargefühl.",
                    systemImage: "square.and.pencil"
                )
                infoRow(
                    title: "Muster verstehen",
                    detail: "Wetterdaten und freiwillig freigegebene Apple-Health-Daten ergänzen deine Einträge, damit du später mehr Kontext hast.",
                    systemImage: "cloud.sun"
                )
                infoRow(
                    title: "Arztgespräche vorbereiten",
                    detail: "PDF-Berichte helfen dir, Termine vorzubereiten. Sie werden nur erstellt und geteilt, wenn du das aktiv auslöst.",
                    systemImage: "doc.text"
                )
            }

            Section("Deine Daten") {
                infoRow(
                    title: "Deine Daten gehören dir",
                    detail: "Einträge, Medikamente, Notizen, Trigger, Symptome, Wetter-Snapshots und gelesener Apple-Health-Kontext werden auf diesem Gerät gespeichert.",
                    systemImage: "lock"
                )
                infoRow(
                    title: "iCloud ist freiwillig",
                    detail: "Die App funktioniert auch ohne iCloud. Wenn du Sync aktivierst, werden deine App-Daten über deinen eigenen iCloud-Account abgeglichen.",
                    systemImage: "icloud"
                )
                infoRow(
                    title: "Export nur mit deiner Aktion",
                    detail: "PDF-Berichte und Backups entstehen lokal. Sie verlassen die App erst, wenn du sie über iOS teilst oder speicherst.",
                    systemImage: "square.and.arrow.up"
                )
                Link(destination: privacyURL) {
                    Label("Datenschutzerklärung öffnen", systemImage: "link")
                }

                Link(destination: ProductBranding.websiteURL) {
                    Label("symiapp.com öffnen", systemImage: "link")
                }
            }

            Section("Berechtigungen") {
                infoRow(
                    title: "Standort für Wetter",
                    detail: "Für Wetterdaten fragt die App nach deinem ungefähren Standort. Die Koordinaten werden nur für den Wetteraufruf benötigt und nie gespeichert.",
                    systemImage: "location"
                )
                infoRow(
                    title: "Apple Health optional",
                    detail: "Apple Health wird nur genutzt, wenn du einzelne Informationen freigibst.",
                    systemImage: "heart.text.square"
                )
                infoRow(
                    title: "Erinnerungen bleiben lokal",
                    detail: "Terminerinnerungen werden als lokale iOS-Mitteilungen geplant. Termine bleiben auch gespeichert, wenn du Mitteilungen nicht erlaubst.",
                    systemImage: "bell"
                )
            }

            Section("Apple Health") {
                infoRow(
                    title: "Du behältst die Kontrolle",
                    detail: "Du kannst entscheiden ob und in welchem Ausmaß du deine Gesundheitsdaten an diese App freigibst. Sie werden niemals an Dritte weitergegeben.",
                    systemImage: "checklist"
                )
                infoRow(
                    title: "Was geschrieben wird",
                    detail: "Symptomdaten wie Kopfschmerz und ausgewählte Begleitsymptome können an Apple Health übertragen werden. Notizen und Medikamente bleiben in der App.",
                    systemImage: "pencil.and.list.clipboard"
                )
            }

            Section("Wetter") {
                infoRow(
                    title: "Quelle",
                    detail: "Wetterdaten kommen von Apple Weather. Beim Speichern eines Eintrags merkt sich die App einen passenden Wetter-Snapshot.",
                    systemImage: "cloud.sun"
                )
                infoRow(
                    title: "Attribution",
                    detail: LocalizedStringKey(WeatherAttribution.modifiedSourceDescription),
                    systemImage: "text.badge.checkmark"
                )

                WeatherAttributionView(showsDescription: false)
            }

            Section("Medizinischer Hinweis") {
                infoRow(
                    title: "Dokumentationshilfe",
                    detail: "Die App hilft dir, eigene Beobachtungen festzuhalten und später wiederzufinden.",
                    systemImage: "list.clipboard"
                )
                infoRow(
                    title: "Keine Diagnose, keine Therapieempfehlung",
                    detail: "Die App stellt keine Diagnose, bewertet deine Beschwerden nicht medizinisch und empfiehlt keine Behandlung.",
                    systemImage: "stethoscope"
                )
                infoRow(
                    title: "Bei Warnzeichen Hilfe holen",
                    detail: "Bei neuen, starken oder ungewohnten Symptomen, bei Unsicherheit oder im Notfall solltest du medizinische Hilfe holen.",
                    systemImage: "exclamationmark.triangle"
                )
            }
            Section("Open Source") {
                infoRow(
                    title: "Lizenz",
                    detail: "Das Projekt steht unter der GNU GPL v3.",
                    systemImage: "doc.plaintext"
                )
                infoRow(
                    title: "Feedback und Ideen",
                    detail: "Feedback und Hilfe findest du über symiapp.com.",
                    systemImage: "bubble.left.and.text.bubble.right"
                )
                infoRow(
                    title: "Beiträge",
                    detail: "Pull Requests sind willkommen.",
                    systemImage: "arrow.triangle.pull"
                )

                Link(destination: repositoryURL) {
                    Label("Projekt auf GitHub öffnen", systemImage: "link")
                }

                Link(destination: ProductBranding.supportURL) {
                    Label("Support öffnen", systemImage: "questionmark.circle")
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
    private func infoRow(title: LocalizedStringKey, detail: LocalizedStringKey, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.accent)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
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
