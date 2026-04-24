import SwiftUI

enum DoctorAddEntryMode: Identifiable {
    case oegkDirectory
    case manual

    var id: String {
        switch self {
        case .oegkDirectory:
            "oegkDirectory"
        case .manual:
            "manual"
        }
    }
}

struct DoctorsHubView: View {
    let appContainer: AppContainer
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var controller: DoctorHubController
    @State private var selectedDoctorID: UUID?
    @State private var doctorAddMode: DoctorAddEntryMode?
    @State private var isPresentingAppointmentFlow = false

    init(appContainer: AppContainer) {
        self.appContainer = appContainer
        _controller = State(initialValue: appContainer.makeDoctorHubController())
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactContent
            } else {
                regularContent
            }
        }
        .navigationTitle("Ärzte")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    isPresentingAppointmentFlow = true
                } label: {
                    Label("Termin", systemImage: "calendar.badge.plus")
                }

                Button {
                    doctorAddMode = .oegkDirectory
                } label: {
                    Label("Arzt hinzufügen", systemImage: "cross.case.fill")
                }
            }
        }
        .task {
            await reloadAll()
        }
        .refreshable {
            await reloadAll()
        }
        .sheet(item: $doctorAddMode) { mode in
            NavigationStack {
                DoctorAddFlowView(appContainer: appContainer, startMode: mode) { doctorID in
                    doctorAddMode = nil
                    Task { await reloadDoctors(selecting: doctorID) }
                }
            }
        }
        .sheet(isPresented: $isPresentingAppointmentFlow) {
            NavigationStack {
                AppointmentCreationFlowView(appContainer: appContainer) {
                    isPresentingAppointmentFlow = false
                    Task { await reloadAppointments() }
                }
            }
        }
    }

    private var compactContent: some View {
        List {
            actionSection
            appointmentsSection
            doctorsSection(compactLinks: true)
        }
        .listStyle(.insetGrouped)
        .brandGroupedScreen()
    }

    private var regularContent: some View {
        HStack(alignment: .top, spacing: 0) {
            List(selection: $selectedDoctorID) {
                actionSection
                doctorsSection(compactLinks: false)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 300, idealWidth: 360, maxWidth: 420)
            .scrollContentBackground(.hidden)
            .background(AppTheme.appBackground)

            Divider()

            VStack(alignment: .leading, spacing: AppTheme.dashboardSpacing) {
                AdaptiveDashboardCard(title: "Kommende Termine") {
                    appointmentRows
                }

                if let selectedDoctorID {
                    DoctorDetailView(appContainer: appContainer, doctorID: selectedDoctorID)
                        .frame(maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    ContentUnavailableView(
                        "Arzt auswählen",
                        systemImage: "cross.case",
                        description: Text("Wähle links eine Ärztin oder einen Arzt aus, um Stammdaten und Termine parallel zu sehen.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .brandCard()
                }
            }
            .padding(24)
            .wideContent()
            .frame(maxHeight: .infinity, alignment: .top)
            .brandScreen()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .brandScreen()
    }

    private var actionSection: some View {
        Section {
            Button {
                doctorAddMode = .oegkDirectory
            } label: {
                Label("Arzt aus ÖGK-Liste hinzufügen", systemImage: "cross.case.fill")
            }

            Button {
                doctorAddMode = .manual
            } label: {
                Label("Arzt manuell hinzufügen", systemImage: "square.and.pencil")
            }

            Button {
                isPresentingAppointmentFlow = true
            } label: {
                Label("Termin hinzufügen", systemImage: "calendar.badge.plus")
            }
        }
    }

    private var appointmentsSection: some View {
        Section("Kommende Termine") {
            appointmentRows
        }
    }

    @ViewBuilder
    private var appointmentRows: some View {
        if controller.upcomingAppointmentItems.isEmpty {
            ContentUnavailableView(
                "Keine kommenden Termine",
                systemImage: "calendar.badge.clock",
                description: Text("Lege einen Termin an, sobald du eine Ärztin oder einen Arzt erfasst hast.")
            )
        } else {
            ForEach(controller.upcomingAppointmentItems) { item in
                NavigationLink {
                    DoctorDetailView(appContainer: appContainer, doctorID: item.doctor.id)
                } label: {
                    AppointmentSummaryRow(appointment: item.appointment, doctor: item.doctor)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func doctorsSection(compactLinks: Bool) -> some View {
        Section {
            if controller.doctors.isEmpty {
                ContentUnavailableView(
                    "Noch keine Ärztinnen oder Ärzte",
                    systemImage: "cross.case",
                    description: Text("Nutze die ÖGK-Liste als Startpunkt oder lege eine Ärztin bzw. einen Arzt vollständig manuell an.")
                )
            } else {
                ForEach(controller.doctors) { doctor in
                    if compactLinks {
                        NavigationLink {
                            DoctorDetailView(appContainer: appContainer, doctorID: doctor.id)
                        } label: {
                            DoctorSummaryRow(doctor: doctor)
                        }
                    } else {
                        Button {
                            selectedDoctorID = doctor.id
                        } label: {
                            DoctorSummaryRow(doctor: doctor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(selectedDoctorID == doctor.id ? AppTheme.selectedFill : Color.clear)
                    }
                }
            }
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

    private func reloadAll() async {
        await controller.reloadAll()
        updateSelection()
    }

    private func reloadDoctors(selecting doctorID: UUID? = nil) async {
        do {
            try await controller.reloadDoctors()
            controller.errorMessage = nil
        } catch {
            controller.errorMessage = "Ärzte und Termine konnten nicht geladen werden."
        }
        if let doctorID {
            selectedDoctorID = doctorID
        }
        updateSelection()
    }

    private func reloadAppointments() async {
        do {
            try await controller.reloadAppointments()
            controller.errorMessage = nil
        } catch {
            controller.errorMessage = "Ärzte und Termine konnten nicht geladen werden."
        }
        updateSelection()
    }

    private func updateSelection() {
        if selectedDoctorID == nil {
            selectedDoctorID = controller.doctors.first?.id
        } else if !controller.doctors.contains(where: { $0.id == selectedDoctorID }) {
            selectedDoctorID = controller.doctors.first?.id
        }
    }
}

struct AppointmentSummaryRow: View {
    let appointment: AppointmentRecord
    let doctor: DoctorRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(doctor.name)
                .font(.headline)

            Text(appointment.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                .foregroundStyle(.secondary)

            if !appointment.practiceName.isEmpty {
                Text(appointment.practiceName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                if !doctor.specialty.isEmpty {
                    Text(doctor.specialty)
                }
                Text(appointment.reminderStatus.rawValue)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .brandGroupedRow()
    }
}

struct DoctorDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let appContainer: AppContainer
    let doctorID: UUID

    @State private var doctor: DoctorRecord?
    @State private var isEditingDoctor = false
    @State private var isPresentingNewAppointment = false
    @State private var editingAppointment: AppointmentRecord?
    @State private var pendingDeletion: AppointmentRecord?

    init(appContainer: AppContainer, doctorID: UUID) {
        self.appContainer = appContainer
        self.doctorID = doctorID
        _doctor = State(initialValue: nil)
    }

    var body: some View {
        List {
            if let doctor {
                Section("Arzt") {
                    detailRow("Name", doctor.name)

                    if !doctor.specialty.isEmpty {
                        detailRow("Fachgebiet", doctor.specialty)
                    }

                    if !doctor.addressLine.isEmpty {
                        detailRow("Adresse", doctor.addressLine)
                    }

                    if !doctor.phone.isEmpty {
                        detailRow("Telefon", doctor.phone)
                    }

                    if !doctor.email.isEmpty {
                        detailRow("E-Mail", doctor.email)
                    }

                    detailRow("Quelle", AppStoreScreenshotMode.isEnabled ? "Musterverzeichnis" : doctor.source.rawValue)
                }

                if !doctor.notes.isEmpty {
                    Section("Notiz") {
                        Text(doctor.notes)
                    }
                }

                Section {
                    Button {
                        isPresentingNewAppointment = true
                    } label: {
                        Label("Termin hinzufügen", systemImage: "calendar.badge.plus")
                    }
                }

                Section("Kommende Termine") {
                    let appointments = doctor.appointments.filter { !$0.isDeleted }
                    if appointments.isEmpty {
                        ContentUnavailableView(
                            "Keine Termine",
                            systemImage: "calendar",
                            description: Text("Lege den ersten Termin mit optionaler Erinnerung an.")
                        )
                    } else {
                        ForEach(appointments) { appointment in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(appointment.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.headline)

                                if !appointment.practiceName.isEmpty {
                                    Text(appointment.practiceName)
                                        .foregroundStyle(.secondary)
                                }

                                if !appointment.addressText.isEmpty {
                                    Text(appointment.addressText)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                if !appointment.note.isEmpty {
                                    Text(appointment.note)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Text("Erinnerung: \(appointment.reminderStatus.rawValue)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                            .brandGroupedRow()
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Löschen", role: .destructive) {
                                    pendingDeletion = appointment
                                }

                                Button("Bearbeiten") {
                                    editingAppointment = appointment
                                }
                                .tint(.accentColor)
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView("Arzt nicht gefunden", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle("Arztdetail")
        .brandGroupedScreen()
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Bearbeiten") {
                    isEditingDoctor = true
                }
                .disabled(doctor == nil)

                Button("Löschen", role: .destructive) {
                    deleteDoctor()
                }
                .disabled(doctor == nil)
            }
        }
        .fullScreenCover(isPresented: $isEditingDoctor) {
            NavigationStack {
                DoctorEditorView(appContainer: appContainer, doctorID: doctorID) { _ in
                    isEditingDoctor = false
                    Task { await reload() }
                }
            }
        }
        .fullScreenCover(isPresented: $isPresentingNewAppointment) {
            if let doctor {
                NavigationStack {
                    AppointmentEditorView(appContainer: appContainer, doctor: doctor, appointmentID: nil) {
                        isPresentingNewAppointment = false
                        Task { await reload() }
                    }
                }
            }
        }
        .fullScreenCover(item: $editingAppointment) { appointment in
            if let doctor {
                NavigationStack {
                    AppointmentEditorView(appContainer: appContainer, doctor: doctor, appointmentID: appointment.id) {
                        editingAppointment = nil
                        Task { await reload() }
                    }
                }
            }
        }
        .confirmationDialog(
            "Termin löschen?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingDeletion = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) {
                deleteAppointment()
            }
            Button("Abbrechen", role: .cancel) {
                pendingDeletion = nil
            }
        } message: {
            Text("Die Erinnerung zu diesem Termin wird ebenfalls entfernt.")
        }
        .task {
            await reload()
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
            Text(value)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .brandGroupedRow()
        .accessibilityElement(children: .combine)
    }

    private func reload() async {
        let repository = appContainer.doctorRepository
        doctor = await Task.detached(priority: .userInitiated) {
            try? repository.load(id: doctorID)
        }.value
    }

    private func deleteDoctor() {
        let repository = appContainer.doctorRepository
        Task {
            try? await Task.detached(priority: .userInitiated) {
                try repository.softDelete(id: doctorID)
            }.value
            dismiss()
        }
    }

    private func deleteAppointment() {
        guard let pendingDeletion else {
            return
        }

        Task {
            try? await DeleteAppointmentUseCase(
                appointmentRepository: appContainer.appointmentRepository,
                notificationService: appContainer.notificationService
            ).execute(id: pendingDeletion.id)

            self.pendingDeletion = nil
            await reload()
        }
    }
}

struct DoctorAddFlowView: View {
    @Environment(\.dismiss) private var dismiss

    let appContainer: AppContainer
    let startMode: DoctorAddEntryMode
    let initialSearchText: String?
    let onSaved: ((UUID) -> Void)?

    @State private var mode: DoctorAddEntryMode
    @State private var selectedEntry: DoctorDirectoryRecord?

    init(
        appContainer: AppContainer,
        startMode: DoctorAddEntryMode,
        initialSearchText: String? = nil,
        onSaved: ((UUID) -> Void)? = nil
    ) {
        self.appContainer = appContainer
        self.startMode = startMode
        self.initialSearchText = initialSearchText
        self.onSaved = onSaved
        _mode = State(initialValue: startMode)
    }

    var body: some View {
        Group {
            switch mode {
            case .oegkDirectory:
                DoctorDirectoryPickerView(appContainer: appContainer, initialSearchText: initialSearchText) { entry in
                    selectedEntry = entry
                    mode = .manual
                } onManualEntry: {
                    selectedEntry = nil
                    mode = .manual
                }

            case .manual:
                DoctorEditorView(appContainer: appContainer, doctorID: nil, initialDirectoryEntry: selectedEntry) { id in
                    onSaved?(id)
                }
            }
        }
    }
}

private struct DoctorDirectoryPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let appContainer: AppContainer
    let initialSearchText: String?
    let onSelectEntry: (DoctorDirectoryRecord) -> Void
    let onManualEntry: () -> Void

    @State private var controller: DoctorEditorController

    init(
        appContainer: AppContainer,
        initialSearchText: String? = nil,
        onSelectEntry: @escaping (DoctorDirectoryRecord) -> Void,
        onManualEntry: @escaping () -> Void
    ) {
        self.appContainer = appContainer
        self.initialSearchText = initialSearchText
        self.onSelectEntry = onSelectEntry
        self.onManualEntry = onManualEntry
        let controller = appContainer.makeDoctorEditorController(doctor: nil)
        if let initialSearchText, !initialSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            controller.searchText = initialSearchText
            controller.refreshSearch()
        }
        _controller = State(initialValue: controller)
    }

    var body: some View {
        List {
            Section {
                TextField("Nach Name, Fachgebiet oder Ort suchen", text: $controller.searchText)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .onChange(of: controller.searchText) {
                        controller.scheduleSearchRefresh()
                    }

                Text("Quelle: \(controller.sourceAttribution.label)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text(AppStoreScreenshotMode.isEnabled ? "Arzt aus Musterverzeichnis hinzufügen" : "Arzt aus ÖGK-Liste hinzufügen")
            } footer: {
                Text("Die Treffer sind nach relevanten Fachgebieten gruppiert und innerhalb der Gruppen nach PLZ und Name sortiert.")
            }

            Section {
                Button {
                    onManualEntry()
                } label: {
                    Label("Arzt manuell hinzufügen", systemImage: "square.and.pencil")
                }
            }

            if controller.groupedSearchResults.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Keine passenden Ärztinnen oder Ärzte",
                        systemImage: "magnifyingglass",
                        description: Text("Passe den Suchbegriff an oder nutze die manuelle Anlage.")
                    )
                }
            } else {
                ForEach(controller.groupedSearchResults) { section in
                    Section(section.title) {
                        ForEach(section.entries) { entry in
                            Button {
                                onSelectEntry(entry)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text(entry.name)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if let postalCode = entry.postalCode, !postalCode.isEmpty {
                                            Text(postalCode)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Text(entry.addressLine)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                .padding(.vertical, 2)
                                .brandGroupedRow()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle("Arzt hinzufügen")
        .brandGroupedScreen()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Abbrechen") {
                    dismiss()
                }
            }
        }
        .navigationBarTitleDisplayMode(.large)
    }
}

struct DoctorEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let appContainer: AppContainer
    let doctorID: UUID?
    let onSaved: ((UUID) -> Void)?

    @State private var controller: DoctorEditorController

    init(
        appContainer: AppContainer,
        doctorID: UUID?,
        initialDirectoryEntry: DoctorDirectoryRecord? = nil,
        onSaved: ((UUID) -> Void)? = nil
    ) {
        self.appContainer = appContainer
        self.doctorID = doctorID
        self.onSaved = onSaved

        let controller = appContainer.makeDoctorEditorController(doctor: nil)
        if let initialDirectoryEntry {
            controller.applyDirectoryEntry(initialDirectoryEntry)
        }
        _controller = State(initialValue: controller)
    }

    var body: some View {
        @Bindable var controller = controller

        Form {
            if let validationMessage = controller.validationMessage {
                Section {
                    Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }

            if doctorID == nil, controller.draft.source == .oegkDirectory {
                Section("ÖGK-Auswahl") {
                    detailRow("Quelle", controller.draft.source.rawValue)
                    if !controller.draft.name.isEmpty {
                        detailRow("Übernommen", controller.draft.name)
                    }
                }
            }

            Section("Stammdaten") {
                TextField("Name", text: $controller.draft.name)
                TextField("Fachgebiet", text: $controller.draft.specialty)
                TextField("Straße", text: $controller.draft.street)
                TextField("PLZ", text: $controller.draft.postalCode)
                    .keyboardType(.numbersAndPunctuation)
                TextField("Ort", text: $controller.draft.city)
                TextField("Bundesland", text: $controller.draft.state)
            }

            Section("Kontakt") {
                TextField("Telefon", text: $controller.draft.phone)
                    .keyboardType(.phonePad)
                TextField("E-Mail", text: $controller.draft.email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("Notiz") {
                TextField("Optionaler Hinweis", text: $controller.draft.notes, axis: .vertical)
                    .lineLimit(2 ... 5)
            }

            Section {
                Button(doctorID == nil ? "Arzt speichern" : "Änderungen speichern") {
                    controller.save { id in
                        onSaved?(id)
                        dismiss()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle(doctorID == nil ? "Arzt anlegen" : "Arzt bearbeiten")
        .brandGroupedScreen()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Abbrechen") {
                    dismiss()
                }
            }
        }
        .task {
            guard let doctorID else {
                return
            }

            let repository = appContainer.doctorRepository
            if let doctor = await Task.detached(priority: .userInitiated, operation: {
                try? repository.load(id: doctorID)
            }).value {
                controller.applyDoctor(doctor)
            }
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
            Text(value)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .brandGroupedRow()
    }
}

struct AppointmentCreationFlowView: View {
    @Environment(\.dismiss) private var dismiss

    let appContainer: AppContainer
    let onSaved: (() -> Void)?

    @State private var doctors: [DoctorRecord]
    @State private var selectedDoctorID: UUID?
    @State private var doctorAddMode: DoctorAddEntryMode?

    init(appContainer: AppContainer, onSaved: (() -> Void)? = nil) {
        self.appContainer = appContainer
        self.onSaved = onSaved
        _doctors = State(initialValue: [])
    }

    var body: some View {
        Group {
            if let selectedDoctor {
                AppointmentEditorView(appContainer: appContainer, doctor: selectedDoctor, appointmentID: nil) {
                    onSaved?()
                }
            } else if doctors.isEmpty {
                List {
                    Section {
                        ContentUnavailableView(
                            "Für Termine brauchst du zuerst einen Arzt",
                            systemImage: "cross.case",
                            description: Text("Füge zuerst eine Ärztin oder einen Arzt aus der ÖGK-Liste hinzu oder lege den Eintrag manuell an.")
                        )
                    }

                    Section("Arzt zuerst anlegen") {
                        Button {
                            doctorAddMode = .oegkDirectory
                        } label: {
                            Label("Arzt aus ÖGK-Liste hinzufügen", systemImage: "cross.case.fill")
                        }

                        Button {
                            doctorAddMode = .manual
                        } label: {
                            Label("Arzt manuell hinzufügen", systemImage: "square.and.pencil")
                        }
                    }
                }
                .navigationTitle("Termin hinzufügen")
                .brandGroupedScreen()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Abbrechen") {
                            dismiss()
                        }
                    }
                }
            } else {
                List {
                    Section("Arzt auswählen") {
                        ForEach(doctors) { doctor in
                            Button {
                                selectedDoctorID = doctor.id
                            } label: {
                                DoctorSummaryRow(doctor: doctor)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Section {
                        Button {
                            doctorAddMode = .oegkDirectory
                        } label: {
                            Label("Arzt aus ÖGK-Liste hinzufügen", systemImage: "cross.case.fill")
                        }

                        Button {
                            doctorAddMode = .manual
                        } label: {
                            Label("Arzt manuell hinzufügen", systemImage: "square.and.pencil")
                        }
                    }
                }
                .navigationTitle("Termin hinzufügen")
                .brandGroupedScreen()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Abbrechen") {
                            dismiss()
                        }
                    }
                }
                .task {
                    if doctors.count == 1, selectedDoctorID == nil {
                        selectedDoctorID = doctors[0].id
                    }
                }
            }
        }
        .fullScreenCover(item: $doctorAddMode) { mode in
            NavigationStack {
                DoctorAddFlowView(appContainer: appContainer, startMode: mode) { doctorID in
                    Task { await reloadDoctors(selecting: doctorID) }
                    doctorAddMode = nil
                }
            }
        }
        .task {
            await reloadDoctors(selecting: selectedDoctorID)
        }
    }

    private var selectedDoctor: DoctorRecord? {
        guard let selectedDoctorID else {
            return nil
        }

        return doctors.first(where: { $0.id == selectedDoctorID })
    }

    private func reloadDoctors(selecting doctorID: UUID?) async {
        let repository = appContainer.doctorRepository
        doctors = await Task.detached(priority: .userInitiated) {
            (try? repository.fetchAll()) ?? []
        }.value
        selectedDoctorID = doctorID
    }
}

struct AppointmentEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let appContainer: AppContainer
    let doctor: DoctorRecord
    let appointmentID: UUID?
    let onSaved: (() -> Void)?

    @State private var controller: AppointmentEditorController

    init(appContainer: AppContainer, doctor: DoctorRecord, appointmentID: UUID?, onSaved: (() -> Void)? = nil) {
        self.appContainer = appContainer
        self.doctor = doctor
        self.appointmentID = appointmentID
        self.onSaved = onSaved
        _controller = State(initialValue: appContainer.makeAppointmentEditorController(appointment: nil, doctor: doctor))
    }

    var body: some View {
        @Bindable var controller = controller

        Form {
            if let validationMessage = controller.validationMessage {
                Section {
                    Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }

            Section("Termin") {
                LabeledContent("Arzt", value: doctor.name)

                DatePicker(
                    "Beginn",
                    selection: $controller.draft.scheduledAt,
                    displayedComponents: [.date, .hourAndMinute]
                )

                Toggle("Endzeit angeben", isOn: $controller.draft.endsAtEnabled)
                if controller.draft.endsAtEnabled {
                    DatePicker(
                        "Ende",
                        selection: $controller.draft.endsAt,
                        in: controller.draft.scheduledAt...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
            }

            Section("Ort") {
                TextField("Praxis / Ort", text: $controller.draft.practiceName)
                TextField("Adresse", text: $controller.draft.addressText, axis: .vertical)
                    .lineLimit(2 ... 4)
            }

            Section {
                Toggle("Erinnerung aktivieren", isOn: $controller.draft.reminderEnabled)

                if controller.draft.reminderEnabled {
                    Picker("Vorlauf", selection: $controller.draft.reminderLeadTimeMinutes) {
                        Text("24 Stunden").tag(24 * 60)
                        Text("2 Stunden").tag(2 * 60)
                        Text("30 Minuten").tag(30)
                    }
                }
            } header: {
                Text("Erinnerung")
            } footer: {
                Text("Die Erinnerung wird lokal auf dem Gerät geplant. Ohne Berechtigung bleibt der Termin trotzdem gespeichert.")
            }

            Section("Notiz") {
                TextField("Optionaler Hinweis", text: $controller.draft.note, axis: .vertical)
                    .lineLimit(2 ... 5)
            }

            Section {
                Button(appointmentID == nil ? "Termin speichern" : "Änderungen speichern") {
                    controller.save { _ in
                        onSaved?()
                        dismiss()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle(appointmentID == nil ? "Termin speichern" : "Termin bearbeiten")
        .brandGroupedScreen()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Abbrechen") {
                    dismiss()
                }
            }
        }
        .alert("Termin gespeichert", isPresented: $controller.saveMessageVisible) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Der Termin wurde lokal gespeichert.")
        }
        .task {
            guard let appointmentID else {
                return
            }

            await controller.loadAppointment(id: appointmentID)
        }
    }
}
