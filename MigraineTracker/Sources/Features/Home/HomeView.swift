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
                if let latestEpisode = overview.latestEpisode {
                    MetricRow(
                        title: "Letzte Episode: \(latestEpisode.type.rawValue)",
                        detail: "Intensität \(latestEpisode.intensity)/10 · \(latestEpisode.startedAt.formatted(date: .abbreviated, time: .shortened))"
                    )
                } else {
                    MetricRow(
                        title: "Noch keine Episode erfasst",
                        detail: "Starte mit einem schnellen Eintrag für Intensität, Symptome und Medikamente."
                    )
                }

                Button {
                    isPresentingEpisodeEditor = true
                } label: {
                    Label("Episode erfassen", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Tracking")
            } footer: {
                Text("Gespeicherte Episoden: \(overview.episodeCount)")
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
                    HistoryView(appContainer: appContainer)
                } label: {
                    Label("Verlauf öffnen", systemImage: "calendar")
                }

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
                Text("Verlauf & mehr")
            }
        }
        .navigationTitle("Übersicht")
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
