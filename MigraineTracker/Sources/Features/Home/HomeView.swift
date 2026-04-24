import SwiftUI

struct HomeView: View {
    let appContainer: AppContainer
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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
        Group {
            if horizontalSizeClass == .compact {
                compactDashboard
            } else {
                regularDashboard
            }
        }
        .navigationTitle(ProductBranding.displayName)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    isPresentingEpisodeEditor = true
                } label: {
                    Label("Eintragen", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)

                Button {
                    isPresentingAppointmentFlow = true
                } label: {
                    Label("Termin", systemImage: "calendar.badge.plus")
                }
            }
        }
        .task {
            await reloadAll()
        }
        .refreshable {
            await reloadAll()
        }
        .fullScreenCover(isPresented: $isPresentingEpisodeEditor) {
            NavigationStack {
                EpisodeEditorView(appContainer: appContainer) {
                    isPresentingEpisodeEditor = false
                    Task { await reloadOverview() }
                }
            }
        }
        .fullScreenCover(isPresented: $isPresentingDoctorAddFlow) {
            NavigationStack {
                DoctorAddFlowView(appContainer: appContainer, startMode: .oegkDirectory) { _ in
                    isPresentingDoctorAddFlow = false
                    Task { await reloadDoctorData() }
                }
            }
        }
        .fullScreenCover(isPresented: $isPresentingManualDoctorAddFlow) {
            NavigationStack {
                DoctorAddFlowView(appContainer: appContainer, startMode: .manual) { _ in
                    isPresentingManualDoctorAddFlow = false
                    Task { await reloadDoctorData() }
                }
            }
        }
        .fullScreenCover(isPresented: $isPresentingAppointmentFlow) {
            NavigationStack {
                AppointmentCreationFlowView(appContainer: appContainer) {
                    isPresentingAppointmentFlow = false
                    Task { await reloadAppointments() }
                }
            }
        }
    }

    private var compactDashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DiaryWelcomeCard(overview: overview)

                Button {
                    isPresentingEpisodeEditor = true
                } label: {
                    Text("Eintrag erstellen")
                }
                .buttonStyle(SymiPrimaryButtonStyle())

                FeelingCheckInCard()

                AdaptiveDashboardCard(title: "Kommende Termine") {
                    appointmentContent
                }

                AdaptiveDashboardCard(title: "Vertrauen") {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Deine Daten gehören dir.", systemImage: "lock")
                            .font(.headline)
                        Text("Symi bleibt lokal nutzbar. Sync und Export passieren nur, wenn du sie aktiv nutzt.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.symiTextSecondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .brandScreen()
    }

    private var regularDashboard: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: 360), spacing: AppTheme.dashboardSpacing, alignment: .top),
                    GridItem(.flexible(minimum: 320), spacing: AppTheme.dashboardSpacing, alignment: .top)
                ],
                alignment: .leading,
                spacing: AppTheme.dashboardSpacing
            ) {
                VStack(alignment: .leading, spacing: AppTheme.dashboardSpacing) {
                    DiaryWelcomeCard(overview: overview)
                    FeelingCheckInCard()

                    AdaptiveDashboardCard(title: "Schnellaktionen") {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 180), spacing: 12)],
                            alignment: .leading,
                            spacing: 12
                        ) {
                            QuickActionTile("Eintragen", systemImage: "plus") {
                                isPresentingEpisodeEditor = true
                            }

                            QuickActionTile("Termin hinzufügen", systemImage: "calendar.badge.plus") {
                                isPresentingAppointmentFlow = true
                            }

                            QuickActionTile("Kontakt hinzufügen", systemImage: "person.crop.circle.badge.plus") {
                                isPresentingDoctorAddFlow = true
                            }

                            QuickActionTile("Manuell anlegen", systemImage: "square.and.pencil") {
                                isPresentingManualDoctorAddFlow = true
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: AppTheme.dashboardSpacing) {
                    AdaptiveDashboardCard(title: "Kommende Termine") {
                        appointmentContent
                    }

                    AdaptiveDashboardCard(title: "Vertrauen") {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Deine Daten gehören dir.", systemImage: "lock")
                                .font(.headline)
                            Text("Website und Support: symiapp.com")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.symiTextSecondary)
                        }
                    }

                    AdaptiveDashboardCard(title: "Kontakte") {
                        doctorContent
                    }
                }
            }
            .padding(24)
            .wideContent()
        }
        .brandScreen()
        .refreshable {
            await reloadAll()
        }
    }

    private var appointmentsSection: some View {
        Section {
            Button {
                isPresentingAppointmentFlow = true
            } label: {
                Label("Termin hinzufügen", systemImage: "calendar.badge.plus")
            }

            appointmentContent
        } header: {
            Text("Termine")
        }
    }

    private var doctorsSection: some View {
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

            doctorContent
        } header: {
            Text("Meine Ärzte")
        } footer: {
            Text(
                AppStoreScreenshotMode.isEnabled
                ? "Im Screenshot-Modus werden ausschließlich anonymisierte Musterärztinnen und Musterärzte angezeigt."
                : "Suchquelle: ÖGK Vertragspartner Fachärztinnen und Fachärzte. Fehlende Kontaktdaten können danach manuell ergänzt werden."
            )
        }
    }

    @ViewBuilder
    private var appointmentContent: some View {
        if doctorHubController.upcomingAppointmentItems.isEmpty {
            ContentUnavailableView(
                "Keine kommenden Termine",
                systemImage: "calendar.badge.clock",
                description: Text("Lege einen Termin an. Falls noch keine Ärztin oder kein Arzt vorhanden ist, startet zuerst der Arzt-Flow.")
            )
        } else {
            ForEach(doctorHubController.upcomingAppointmentItems) { item in
                NavigationLink {
                    DoctorDetailView(appContainer: appContainer, doctorID: item.doctor.id)
                } label: {
                    AppointmentSummaryRow(appointment: item.appointment, doctor: item.doctor)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var doctorContent: some View {
        if doctorHubController.doctors.isEmpty {
            ContentUnavailableView(
                "Noch keine Ärztinnen oder Ärzte",
                systemImage: "cross.case",
                description: Text("Nutze die ÖGK-Liste als Startpunkt oder lege eine Ärztin bzw. einen Arzt vollständig manuell an.")
            )
        } else {
            ForEach(doctorHubController.doctors.prefix(horizontalSizeClass == .compact ? 5 : 6)) { doctor in
                NavigationLink {
                    DoctorDetailView(appContainer: appContainer, doctorID: doctor.id)
                } label: {
                    DoctorSummaryRow(doctor: doctor)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func reloadAll() async {
        await reloadOverview()
        await reloadDoctorData()
    }

    private func reloadOverview() async {
        overview = (try? await LoadHomeOverviewUseCase(repository: appContainer.episodeRepository).execute()) ?? .init(latestEpisode: nil, episodeCount: 0)
    }

    private func reloadDoctorData() async {
        do {
            try await doctorHubController.reloadDoctors()
            try await doctorHubController.reloadAppointments()
            doctorHubController.errorMessage = nil
        } catch {
            doctorHubController.errorMessage = "Ärzte und Termine konnten nicht geladen werden."
        }
    }

    private func reloadAppointments() async {
        do {
            try await doctorHubController.reloadAppointments()
            doctorHubController.errorMessage = nil
        } catch {
            doctorHubController.errorMessage = "Ärzte und Termine konnten nicht geladen werden."
        }
    }
}

struct AdaptiveDashboardCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }
}

private struct QuickActionTile: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    init(_ title: String, systemImage: String, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                .padding(.horizontal, 14)
                .background(AppTheme.secondaryFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(AppTheme.symiPetrol)
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
    }
}

private struct DiaryWelcomeCard: View {
    let overview: HomeOverviewData

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(greeting)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AppTheme.foam)

                    Text(ProductBranding.marketingClaim)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.white)

                    Text(summaryDetail)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.foam.opacity(0.86))

                    if overview.episodeCount > 0 {
                        statsRow
                    }
                }

                Spacer(minLength: 12)

                VStack(spacing: 10) {
                    Image(systemName: "book.closed.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.foam)
                }
                .frame(width: 90, height: 120, alignment: .top)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.heroGradient)
        .overlay(alignment: .bottomLeading) {
            WaveAccent()
                .stroke(AppTheme.foam.opacity(0.82), lineWidth: 8)
                .frame(height: 54)
                .offset(x: -10, y: 18)
        }
        .overlay(alignment: .bottomLeading) {
            WaveAccent()
                .stroke(AppTheme.seaGlass.opacity(0.72), lineWidth: 5)
                .frame(height: 44)
                .offset(x: 6, y: 24)
        }
        .overlay(alignment: .bottomLeading) {
            WaveAccent()
                .stroke(AppTheme.coral.opacity(0.92), lineWidth: 4)
                .frame(width: 132, height: 34)
                .offset(x: -8, y: 28)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: AppTheme.shadowColor.opacity(1.2), radius: 24, y: 12)
        .accessibilityElement(children: .combine)
    }

    private var statsRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Bisher dokumentiert")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.foam.opacity(0.96))

            Spacer(minLength: 12)

            Text("\(overview.episodeCount) Eintrag\(overview.episodeCount == 1 ? "" : "e")")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.white)
                .shadow(color: AppTheme.ink.opacity(0.35), radius: 3, y: 1)
        }
    }

    private var summaryTitle: String {
        if let latestEpisode = overview.latestEpisode {
            return "Dein letzter Eintrag: \(latestEpisode.type.rawValue)"
        }

        return "Schön, dass du dein Tagebuch startest."
    }

    private var summaryDetail: String {
        if let latestEpisode = overview.latestEpisode {
            return "Letzter Eintrag: \(latestEpisode.type.rawValue), Intensität \(latestEpisode.intensity)/10 · \(latestEpisode.startedAt.formatted(date: .abbreviated, time: .shortened))"
        }

        return "In Sekunden eintragen, später Muster verstehen und den Alltag ruhiger planen."
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5 ..< 12:
            return "Guten Morgen"
        case 12 ..< 18:
            return "Guten Tag"
        default:
            return "Guten Abend"
        }
    }
}

private struct FeelingCheckInCard: View {
    @State private var currentState = 4.0

    var body: some View {
        AdaptiveDashboardCard(title: "Wie geht es dir heute?") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(Int(currentState))")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.symiPetrol)
                    Text(feelingLabel)
                        .font(.headline)
                        .foregroundStyle(AppTheme.symiTextSecondary)
                }

                Slider(value: $currentState, in: 0 ... 10, step: 1)
                    .tint(AppTheme.symiCoral)
                    .accessibilityLabel("Aktueller Zustand")
                    .accessibilityValue("\(Int(currentState)) von 10")

                Text("Eine schnelle Einschätzung reicht. Details kannst du im Eintrag ergänzen.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.symiTextSecondary)
            }
        }
    }

    private var feelingLabel: String {
        switch Int(currentState) {
        case 0 ... 2:
            return "ruhig"
        case 3 ... 5:
            return "mittel"
        case 6 ... 8:
            return "spürbar"
        default:
            return "stark"
        }
    }
}

private struct WaveAccent: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY * 0.62),
            control1: CGPoint(x: rect.width * 0.24, y: rect.maxY),
            control2: CGPoint(x: rect.width * 0.66, y: rect.minY)
        )
        return path
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
