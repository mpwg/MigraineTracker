import SwiftUI

struct HomeView: View {
    let appContainer: AppContainer

    @State private var overview: HomeOverviewData = .init(latestEpisode: nil, episodeCount: 0)
    @State private var doctorHubController: DoctorHubController
    @State private var isPresentingEpisodeEditor = false
    @State private var isPresentingDoctorAddFlow = false
    @State private var isPresentingManualDoctorAddFlow = false
    @State private var isPresentingAppointmentFlow = false

    init(appContainer: AppContainer) {
        self.appContainer = appContainer
        _doctorHubController = State(initialValue: appContainer.makeDoctorHubController())
    }

    var body: some View {
        List {
            Section {
                DiaryWelcomeCard(overview: overview)

                Button {
                    isPresentingEpisodeEditor = true
                } label: {
                    Label("Neuer Eintrag", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                NavigationLink {
                    HistoryView(appContainer: appContainer)
                } label: {
                    Label("Tagebuch öffnen", systemImage: "book.closed")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            } header: {
                Text("Tagebuch")
            } footer: {
                Text("Deine Einträge bleiben lokal auf diesem Gerät und helfen dir, Muster, Auslöser und wirksame Routinen besser im Blick zu behalten.")
            }

            Section {
                Button {
                    isPresentingAppointmentFlow = true
                } label: {
                    Label("Termin hinzufügen", systemImage: "calendar.badge.plus")
                }

                if doctorHubController.upcomingAppointments.isEmpty {
                    ContentUnavailableView(
                        "Keine kommenden Termine",
                        systemImage: "calendar.badge.clock",
                        description: Text("Lege einen Termin an. Falls noch keine Ärztin oder kein Arzt vorhanden ist, startet zuerst der Arzt-Flow.")
                    )
                } else {
                    ForEach(doctorHubController.upcomingAppointments) { appointment in
                        if let doctor = doctorHubController.doctors.first(where: { $0.id == appointment.doctorID }) {
                            NavigationLink {
                                DoctorDetailView(appContainer: appContainer, doctorID: doctor.id)
                            } label: {
                                AppointmentSummaryRow(appointment: appointment, doctor: doctor)
                            }
                        }
                    }
                }
            } header: {
                Text("Termine")
            }

            Section {
                Button {
                    isPresentingDoctorAddFlow = true
                } label: {
                    Label("Arzt hinzufügen", systemImage: "cross.case.fill")
                }

                Button {
                    isPresentingManualDoctorAddFlow = true
                } label: {
                    Label("Arzt manuell hinzufügen", systemImage: "square.and.pencil")
                }

                if doctorHubController.doctors.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Ärztinnen oder Ärzte",
                        systemImage: "cross.case",
                        description: Text("Nutze die ÖGK-Liste als Startpunkt oder lege eine Ärztin bzw. einen Arzt vollständig manuell an.")
                    )
                } else {
                    ForEach(doctorHubController.doctors) { doctor in
                        NavigationLink {
                            DoctorDetailView(appContainer: appContainer, doctorID: doctor.id)
                        } label: {
                            DoctorSummaryRow(doctor: doctor)
                        }
                    }
                }
            } header: {
                Text("Meine Ärzte")
            } footer: {
                Text("Suchquelle: ÖGK Vertragspartner Fachärztinnen und Fachärzte. Fehlende Kontaktdaten können danach manuell ergänzt werden.")
            }

            Section {
                NavigationLink {
                    SettingsView(appContainer: appContainer)
                } label: {
                    Label("Einstellungen", systemImage: "gearshape")
                }

                NavigationLink {
                    ProductInformationView(mode: .standard)
                } label: {
                    Label("Datenschutz und Hinweise", systemImage: "hand.raised")
                }
            } header: {
                Text("Mehr")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Willkommen")
        .task {
            reload()
        }
        .refreshable {
            reload()
        }
        .fullScreenCover(isPresented: $isPresentingEpisodeEditor) {
            NavigationStack {
                EpisodeEditorView(appContainer: appContainer) {
                    isPresentingEpisodeEditor = false
                    reload()
                }
            }
        }
        .fullScreenCover(isPresented: $isPresentingDoctorAddFlow) {
            NavigationStack {
                DoctorAddFlowView(appContainer: appContainer, startMode: .oegkDirectory) { _ in
                    isPresentingDoctorAddFlow = false
                    reload()
                }
            }
        }
        .fullScreenCover(isPresented: $isPresentingManualDoctorAddFlow) {
            NavigationStack {
                DoctorAddFlowView(appContainer: appContainer, startMode: .manual) { _ in
                    isPresentingManualDoctorAddFlow = false
                    reload()
                }
            }
        }
        .fullScreenCover(isPresented: $isPresentingAppointmentFlow) {
            NavigationStack {
                AppointmentCreationFlowView(appContainer: appContainer) {
                    isPresentingAppointmentFlow = false
                    reload()
                }
            }
        }
    }

    private func reload() {
        overview = (try? LoadHomeOverviewUseCase(repository: appContainer.episodeRepository).execute()) ?? .init(latestEpisode: nil, episodeCount: 0)
        doctorHubController.reload()
    }
}

private struct DiaryWelcomeCard: View {
    let overview: HomeOverviewData

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(ProductBranding.displayName)
                .font(.title3.weight(.semibold))

            Text(summaryTitle)
                .font(.headline)

            Text(summaryDetail)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if overview.episodeCount > 0 {
                LabeledContent("Bisher dokumentiert", value: "\(overview.episodeCount) Eintrag\(overview.episodeCount == 1 ? "" : "e")")
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private var summaryTitle: String {
        if let latestEpisode = overview.latestEpisode {
            return "Dein letzter Eintrag: \(latestEpisode.type.rawValue)"
        }

        return "Schön, dass du dein Tagebuch startest."
    }

    private var summaryDetail: String {
        if let latestEpisode = overview.latestEpisode {
            return "Intensität \(latestEpisode.intensity)/10 · \(latestEpisode.startedAt.formatted(date: .abbreviated, time: .shortened))"
        }

        return "Mit einem neuen Eintrag hältst du Beschwerden, Symptome, Medikamente und hilfreichen Kontext in wenigen Schritten fest."
    }
}

struct DoctorSummaryRow: View {
    let doctor: DoctorRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(doctor.name)
                .font(.headline)

            if !doctor.specialty.isEmpty {
                Text(doctor.specialty)
                    .foregroundStyle(.secondary)
            }

            if !doctor.addressLine.isEmpty {
                Text(doctor.addressLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    Text("Preview nicht verfügbar")
}
