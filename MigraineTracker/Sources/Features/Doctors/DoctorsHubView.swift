import SwiftUI

struct DoctorsHubView: View {
    let appContainer: AppContainer
    @State private var controller: DoctorHubController
    @State private var isPresentingNewDoctor = false

    init(appContainer: AppContainer) {
        self.appContainer = appContainer
        _controller = State(initialValue: appContainer.makeDoctorHubController())
    }

    var body: some View {
        List {
            Section {
                Button {
                    isPresentingNewDoctor = true
                } label: {
                    Label("Arzt oder Ärztin hinzufügen", systemImage: "plus.circle.fill")
                }
            }

            Section("Kommende Termine") {
                if controller.upcomingAppointments.isEmpty {
                    ContentUnavailableView(
                        "Keine kommenden Termine",
                        systemImage: "calendar.badge.clock",
                        description: Text("Lege einen Arzt an und erfasse danach den ersten Termin mit Erinnerung.")
                    )
                } else {
                    ForEach(controller.upcomingAppointments) { appointment in
                        if let doctor = controller.doctors.first(where: { $0.id == appointment.doctorID }) {
                            NavigationLink {
                                DoctorDetailView(appContainer: appContainer, doctorID: doctor.id)
                            } label: {
                                AppointmentSummaryRow(appointment: appointment, doctor: doctor)
                            }
                        }
                    }
                }
            }

            Section {
                if controller.doctors.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Ärztinnen oder Ärzte",
                        systemImage: "cross.case",
                        description: Text("Nutze den ÖGK-Suchkatalog als Startpunkt oder lege die Daten vollständig manuell an.")
                    )
                } else {
                    ForEach(controller.doctors) { doctor in
                        NavigationLink {
                            DoctorDetailView(appContainer: appContainer, doctorID: doctor.id)
                        } label: {
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
                }
            } header: {
                Text("Ärzte")
            } footer: {
                Text("Suchquelle: ÖGK Vertragspartner Fachärztinnen und Fachärzte. Fehlende Kontaktdaten können danach manuell ergänzt werden.")
            }
        }
        .navigationTitle("Ärzte & Termine")
        .fullScreenCover(isPresented: $isPresentingNewDoctor) {
            NavigationStack {
                DoctorEditorView(appContainer: appContainer, doctorID: nil) {
                    isPresentingNewDoctor = false
                    controller.reload()
                }
            }
        }
        .task {
            controller.reload()
        }
        .refreshable {
            controller.reload()
        }
    }
}

private struct AppointmentSummaryRow: View {
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
        _doctor = State(initialValue: try? appContainer.doctorRepository.load(id: doctorID))
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

                    detailRow("Quelle", doctor.source.rawValue)
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
                DoctorEditorView(appContainer: appContainer, doctorID: doctorID) {
                    isEditingDoctor = false
                    reload()
                }
            }
        }
        .fullScreenCover(isPresented: $isPresentingNewAppointment) {
            if let doctor {
                NavigationStack {
                    AppointmentEditorView(appContainer: appContainer, doctor: doctor, appointmentID: nil) {
                        isPresentingNewAppointment = false
                        reload()
                    }
                }
            }
        }
        .fullScreenCover(item: $editingAppointment) { appointment in
            if let doctor {
                NavigationStack {
                    AppointmentEditorView(appContainer: appContainer, doctor: doctor, appointmentID: appointment.id) {
                        editingAppointment = nil
                        reload()
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
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
            Text(value)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private func reload() {
        doctor = try? appContainer.doctorRepository.load(id: doctorID)
    }

    private func deleteDoctor() {
        try? appContainer.doctorRepository.softDelete(id: doctorID)
        dismiss()
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

            await MainActor.run {
                self.pendingDeletion = nil
                reload()
            }
        }
    }
}

struct DoctorEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let appContainer: AppContainer
    let doctorID: UUID?
    let onSaved: (() -> Void)?

    @State private var controller: DoctorEditorController

    init(appContainer: AppContainer, doctorID: UUID?, onSaved: (() -> Void)? = nil) {
        self.appContainer = appContainer
        self.doctorID = doctorID
        self.onSaved = onSaved
        let doctor = doctorID.flatMap { try? appContainer.doctorRepository.load(id: $0) }
        _controller = State(initialValue: appContainer.makeDoctorEditorController(doctor: doctor))
    }

    var body: some View {
        @Bindable var controller = controller

        List {
            if let validationMessage = controller.validationMessage {
                Section {
                    Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }

            Section {
                TextField("Nach Name, Fachgebiet oder Ort suchen", text: $controller.searchText)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .onChange(of: controller.searchText) {
                        controller.refreshSearch()
                    }

                Text("Quelle: \(controller.sourceAttribution.label)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("ÖGK-Suchkatalog")
            } footer: {
                Text("Die Treffer sind nach relevanten Fachgebieten gruppiert und innerhalb der Gruppen nach PLZ und Name sortiert.")
            }

            if controller.groupedSearchResults.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Keine passenden Ärztinnen oder Ärzte",
                        systemImage: "magnifyingglass",
                        description: Text("Passe den Suchbegriff an oder erfasse die Daten manuell.")
                    )
                }
            } else {
                ForEach(controller.groupedSearchResults) { section in
                    Section(section.title) {
                        ForEach(section.entries) { entry in
                            Button {
                                controller.applyDirectoryEntry(entry)
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
                            }
                            .buttonStyle(.plain)
                        }
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
                    controller.save { _ in
                        onSaved?()
                        dismiss()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle(doctorID == nil ? "Arzt anlegen" : "Arzt bearbeiten")
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
        let appointment = appointmentID.flatMap { try? appContainer.appointmentRepository.load(id: $0) }
        _controller = State(initialValue: appContainer.makeAppointmentEditorController(appointment: appointment, doctor: doctor))
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
        .navigationTitle(appointmentID == nil ? "Termin anlegen" : "Termin bearbeiten")
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
    }
}
