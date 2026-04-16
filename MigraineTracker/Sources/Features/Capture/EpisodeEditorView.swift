import SwiftUI

struct EpisodeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var controller: EpisodeEditorController

    private let onSaved: (() -> Void)?

    init(
        appContainer: AppContainer,
        episodeID: UUID? = nil,
        initialStartedAt: Date? = nil,
        onSaved: (() -> Void)? = nil
    ) {
        self.onSaved = onSaved
        _controller = State(
            initialValue: appContainer.makeEpisodeEditorController(
                episodeID: episodeID,
                initialStartedAt: initialStartedAt
            )
        )
    }

    var body: some View {
        @Bindable var controller = controller

        Form {
            if let validationMessage = controller.validationMessage {
                Section {
                    Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .accessibilityLabel("Fehler: \(validationMessage)")
                }
            }

            Section {
                Picker("Typ", selection: $controller.draft.type) {
                    ForEach(EpisodeType.allCases) { episodeType in
                        Text(episodeType.rawValue).tag(episodeType)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Intensität")
                        Spacer()
                        Text("\(controller.draft.intensity)/10")
                            .font(.headline)
                            .monospacedDigit()
                    }

                    IntensityPicker(value: Binding(
                        get: { Double(controller.draft.intensity) },
                        set: { controller.draft.intensity = Int($0) }
                    ))
                }

                DatePicker(
                    "Beginn",
                    selection: $controller.draft.startedAt,
                    in: ...Date.now,
                    displayedComponents: [.date, .hourAndMinute]
                )
            } header: {
                Text("Schneller Eintrag")
            } footer: {
                Text("Nur Typ, Intensität und Zeitpunkt sind direkt sichtbar. Alles Weitere ist optional.")
            }

            tagSection(title: "Symptome", options: controller.symptomOptions, selection: $controller.draft.selectedSymptoms)
            tagSection(title: "Trigger", options: controller.triggerOptions, selection: $controller.draft.selectedTriggers)

            Section("Notiz") {
                TextField("Kurz notieren, was auffällt", text: $controller.draft.notes, axis: .vertical)
                    .lineLimit(2 ... 5)
            }

            Section("Optionale Details") {
                DisclosureGroup("Weitere Angaben") {
                    TextField("Schmerzlokalisation", text: $controller.draft.painLocation)
                    TextField("Schmerzcharakter", text: $controller.draft.painCharacter)
                    TextField("Funktionelle Einschränkung", text: $controller.draft.functionalImpact)

                    Picker("Menstruationsstatus", selection: $controller.draft.menstruationStatus) {
                        ForEach(MenstruationStatus.allCases, id: \.self) { status in
                            Text(verbatim: status.rawValue).tag(status)
                        }
                    }

                    Toggle("Ende angeben", isOn: $controller.draft.endedAtEnabled.animation())
                    if controller.draft.endedAtEnabled {
                        DatePicker(
                            "Ende",
                            selection: $controller.draft.endedAt,
                            in: controller.draft.startedAt...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }
            }

            Section {
                WeatherStatusContent(state: controller.weatherLoadState)
            } header: {
                Text("Wetter")
            } footer: {
                Text("Das Wetter wird mit deinem ungefähren Standort über Open-Meteo auf Basis von DWD ICON geladen. Die Episode wird auch ohne Wetter gespeichert, wenn keine Freigabe vorliegt.")
            }

            Section("Medikamente") {
                TextField("Medikament nach Namen filtern", text: $controller.medicationSearchText)
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    #endif

                if controller.filteredMedicationGroups.isEmpty {
                    ContentUnavailableView(
                        "Kein Medikament gefunden",
                        systemImage: "magnifyingglass",
                        description: Text("Passe den Suchbegriff an oder füge ein eigenes Medikament hinzu.")
                    )
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(controller.filteredMedicationGroups) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(group.title)
                                    .font(.headline)

                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: 220), spacing: 12, alignment: .top)],
                                    alignment: .leading,
                                    spacing: 12
                                ) {
                                    ForEach(group.items) { definition in
                                        MedicationDefinitionRow(
                                            definition: definition,
                                            isSelected: controller.isMedicationSelected(definition),
                                            quantity: controller.quantity(for: definition),
                                            onToggle: { controller.toggleMedicationSelection(for: definition) },
                                            onDecrease: { controller.decrementMedicationQuantity(for: definition) },
                                            onIncrease: { controller.incrementMedicationQuantity(for: definition) },
                                            onEdit: definition.isCustom ? { controller.presentEditor(for: definition) } : nil,
                                            onDelete: definition.isCustom ? { controller.pendingMedicationDeletion = definition } : nil
                                        )
                                    }
                                }
                                .padding(12)
                                .background(Color.appPrimaryBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                                if let footer = group.footer {
                                    Text(footer)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                if controller.selectedMedications.isEmpty {
                    Text("Nur ergänzen, wenn du heute etwas genommen hast.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ausgewählt")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ForEach(controller.selectedMedications) { medication in
                            SelectedMedicationSummaryRow(draft: medication) {
                                controller.removeMedicationSelection(id: medication.id)
                            }
                        }
                    }
                }

                Button {
                    controller.presentEditor(for: nil)
                } label: {
                    Label("Eigenes Medikament hinzufügen", systemImage: "plus.circle")
                }
            }

            Section {
                Button(controller.mode == .create ? "Episode speichern" : "Änderungen speichern") {
                    controller.save(onSaved: onSaved) {
                        dismiss()
                    }
                }
                .disabled(controller.isSaving)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle(controller.mode == .create ? "Erfassen" : "Episode bearbeiten")
        .toolbar {
            if showsDismissButton {
                ToolbarItem(placement: dismissButtonPlacement) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
        }
        #if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        #endif
        .alert("Episode gespeichert", isPresented: $controller.saveMessageVisible) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Die Episode wurde lokal gespeichert.")
        }
        .sheet(item: $controller.customMedicationEditor) { editorState in
            NavigationStack {
                CustomMedicationEditorSheet(
                    state: editorState,
                    onCancel: { controller.customMedicationEditor = nil },
                    onSave: { draft in
                        controller.saveCustomMedication(from: draft)
                    }
                )
            }
            .presentationDetents([.medium])
        }
        .alert(
            "Eigenes Medikament löschen?",
            isPresented: Binding(
                get: { controller.pendingMedicationDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        controller.pendingMedicationDeletion = nil
                    }
                }
            ),
            presenting: controller.pendingMedicationDeletion
        ) { definition in
            Button("Löschen", role: .destructive) {
                controller.deleteCustomMedication(definition)
            }
            Button("Abbrechen", role: .cancel) {
                controller.pendingMedicationDeletion = nil
            }
        } message: { definition in
            Text("\(definition.name) wird aus SwiftData entfernt.")
        }
        .task(id: controller.draft.startedAt) {
            await controller.refreshWeather()
        }
    }

    @ViewBuilder
    private func tagSection(title: String, options: [String], selection: Binding<Set<String>>) -> some View {
        Section(title) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                ForEach(options, id: \.self) { option in
                    let isSelected = selection.wrappedValue.contains(option)

                    Button {
                        if isSelected {
                            selection.wrappedValue.remove(option)
                        } else {
                            selection.wrappedValue.insert(option)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .imageScale(.medium)
                            Text(option)
                                .font(.subheadline.weight(.medium))
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.16) : Color.appGroupedBackground)
                        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title): \(option)")
                    .accessibilityHint(isSelected ? "Entfernt die Auswahl." : "Wählt diese Option aus.")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    private var showsDismissButton: Bool {
        onSaved != nil || controller.mode == .edit
    }

    private var dismissButtonPlacement: ToolbarItemPlacement {
        #if os(macOS)
        .automatic
        #else
        .topBarLeading
        #endif
    }
}

private struct WeatherStatusContent: View {
    @Environment(\.openURL) private var openURL

    let state: WeatherLoadState

    var body: some View {
        switch state {
        case .idle:
            ContentUnavailableView(
                "Wetter wird vorbereitet",
                systemImage: "cloud.sun",
                description: Text("Beim Laden wird dein ungefährer Standort verwendet, um Wetterdaten für den Episodenzeitpunkt abzurufen.")
            )
        case .loading:
            HStack(spacing: 12) {
                ProgressView()
                Text("Wetter wird ermittelt …")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        case .loaded(let weather):
            VStack(alignment: .leading, spacing: 8) {
                detailRow("Zustand", weather.condition)
                if let temperature = weather.temperature {
                    detailRow("Temperatur", temperature.formatted(.number.precision(.fractionLength(1))) + " °C")
                }
                if let humidity = weather.humidity {
                    detailRow("Luftfeuchte", humidity.formatted(.number.precision(.fractionLength(0))) + " %")
                }
                if let pressure = weather.pressure {
                    detailRow("Luftdruck", pressure.formatted(.number.precision(.fractionLength(0))) + " hPa")
                }
                if let precipitation = weather.precipitation {
                    detailRow("Niederschlag", precipitation.formatted(.number.precision(.fractionLength(1))) + " mm")
                }
                if !weather.source.isEmpty {
                    detailRow("Quelle", weather.source)
                }
                Text(WeatherAttribution.sourceDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        case .unavailable(let message):
            VStack(alignment: .leading, spacing: 12) {
                Label(message, systemImage: "location.slash")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if showsLocationSettingsHint(for: message) {
                    Text("Du kannst die Standortfreigabe in den Einstellungen dieser App unter \"Standort\" auf \"Beim Verwenden der App\" ändern.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let settingsURL = PlatformSettingsLink.appSettingsURL {
                        Button("Einstellungen öffnen") {
                            openURL(settingsURL)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func showsLocationSettingsHint(for message: String) -> Bool {
        message.localizedCaseInsensitiveContains("standort")
            || message.localizedCaseInsensitiveContains("freigabe")
    }
}

private struct IntensityPicker: View {
    @Binding var value: Double

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(1 ... 10, id: \.self) { level in
                let isSelected = Int(value) == level

                Button {
                    value = Double(level)
                } label: {
                    Text("\(level)")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(isSelected ? Color.accentColor : Color.appGroupedBackground)
                        .foregroundStyle(isSelected ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Intensität \(level)")
                .accessibilityHint(isSelected ? "Aktuell ausgewählt." : "Setzt die Intensität auf \(level) von 10.")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

private struct MedicationDefinitionRow: View {
    let definition: MedicationDefinitionRecord
    let isSelected: Bool
    let quantity: Int
    let onToggle: () -> Void
    let onDecrease: () -> Void
    let onIncrease: () -> Void
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onToggle) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                        .foregroundStyle(isSelected ? Color.accentColor : .primary)
                        .frame(width: 28, alignment: .center)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(definition.name)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        if !definition.suggestedDosage.isEmpty {
                            Text(definition.suggestedDosage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            if isSelected {
                HStack(spacing: 10) {
                    Text("Anzahl")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button(action: onDecrease) {
                        Image(systemName: "minus.circle")
                            .imageScale(.large)
                    }
                    .buttonStyle(.plain)

                    Text("\(quantity)")
                        .font(.headline.monospacedDigit())
                        .frame(minWidth: 24)

                    Button(action: onIncrease) {
                        Image(systemName: "plus.circle")
                            .imageScale(.large)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: isSelected ? 108 : 72, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.14) : Color.appGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isSelected ? "Medikament ausgewählt. Passe die Anzahl an." : "Wählt dieses Medikament aus.")
        .contextMenu {
            if let onEdit {
                Button("Bearbeiten", systemImage: "pencil", action: onEdit)
            }

            if let onDelete {
                Button("Löschen", systemImage: "trash", role: .destructive, action: onDelete)
            }
        }
    }

    private var accessibilityLabel: String {
        if isSelected {
            return "\(definition.name), ausgewählt, Anzahl \(quantity)"
        }

        if definition.suggestedDosage.isEmpty {
            return definition.name
        }

        return "\(definition.name), \(definition.suggestedDosage)"
    }
}

private struct CustomMedicationEditorSheet: View {
    let state: CustomMedicationEditorSheetState
    let onCancel: () -> Void
    let onSave: (CustomMedicationDefinitionDraft) -> Void

    @State private var name: String
    @State private var category: MedicationCategory
    @State private var dosage: String

    init(
        state: CustomMedicationEditorSheetState,
        onCancel: @escaping () -> Void,
        onSave: @escaping (CustomMedicationDefinitionDraft) -> Void
    ) {
        self.state = state
        self.onCancel = onCancel
        self.onSave = onSave
        _name = State(initialValue: state.initialName)
        _category = State(initialValue: state.initialCategory)
        _dosage = State(initialValue: state.initialDosage)
    }

    var body: some View {
        Form {
            Section("Medikament") {
                TextField("Name", text: $name)
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    #endif

                Picker("Kategorie", selection: $category) {
                    ForEach(MedicationCategory.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }

                TextField("Dosierung", text: $dosage)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #endif
            }
        }
        .navigationTitle(state.isEditing ? "Medikament bearbeiten" : "Eigenes Medikament")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen", action: onCancel)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(state.isEditing ? "Speichern" : "Hinzufügen") {
                    onSave(
                        CustomMedicationDefinitionDraft(
                            id: state.id,
                            originalSelectionKey: state.originalSelectionKey,
                            name: name,
                            category: category,
                            dosage: dosage
                        )
                    )
                }
            }
        }
    }
}

private struct SelectedMedicationSummaryRow: View {
    let draft: MedicationSelectionDraft
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(draft.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive, action: onRemove) {
                Label("Entfernen", systemImage: "xmark.circle.fill")
                    .labelStyle(.iconOnly)
            }
            .accessibilityLabel("\(draft.name) abwählen")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var summary: String {
        if draft.dosage.isEmpty {
            return "Anzahl \(draft.quantity)"
        }

        return "\(draft.dosage) · Anzahl \(draft.quantity)"
    }
}

#Preview {
    Text("Preview nicht verfügbar")
}
