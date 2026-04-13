import SwiftData
import SwiftUI

struct EpisodeEditorView: View {
    private enum EditorMode {
        case create
        case edit
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\MedicationDefinition.sortOrder), SortDescriptor(\MedicationDefinition.name)]) private var storedMedicationDefinitions: [MedicationDefinition]

    private let mode: EditorMode
    private let episode: Episode?
    private let onSaved: (() -> Void)?

    @State private var type: EpisodeType
    @State private var intensity: Double
    @State private var startedAt: Date
    @State private var endedAtEnabled: Bool
    @State private var endedAt: Date
    @State private var painLocation: String
    @State private var painCharacter: String
    @State private var notes: String
    @State private var functionalImpact: String
    @State private var menstruationStatus: MenstruationStatus
    @State private var selectedSymptoms: Set<String>
    @State private var selectedTriggers: Set<String>
    @State private var medications: [MedicationSelection]
    @State private var weatherEnabled: Bool
    @State private var weatherCondition: String
    @State private var weatherTemperature: String
    @State private var weatherHumidity: String
    @State private var weatherPressure: String
    @State private var weatherSource: String
    @State private var medicationSearchText = ""
    @State private var customMedicationEditor: CustomMedicationEditorState?
    @State private var pendingMedicationDeletion: MedicationDefinition?
    @State private var saveMessageVisible = false
    @State private var validationMessage: String?

    private let symptomOptions = [
        "Übelkeit",
        "Lichtempfindlichkeit",
        "Geräuschempfindlichkeit",
        "Aura",
        "Kiefer-/Aufbissschmerz",
        "Pochen, Pulsieren"
    ]
    private let triggerOptions = ["Stress", "Schlafmangel", "Alkohol", "Menstruation", "Bildschirmzeit"]
    private let weatherConditionOptions = ["Wetterumschwung/Wind"]
    private let customGroupID = "custom-medications"
    private let customGroupTitle = "Eigene Medikamente"
    private let customGroupFooter = "Eigene Medikamente werden lokal in SwiftData gespeichert und bleiben in deiner persönlichen Auswahlliste verfügbar."

    init(episode: Episode? = nil, initialStartedAt: Date? = nil, onSaved: (() -> Void)? = nil) {
        self.episode = episode
        self.onSaved = onSaved
        self.mode = episode == nil ? .create : .edit

        _type = State(initialValue: episode?.type ?? .unclear)
        _intensity = State(initialValue: Double(episode?.intensity ?? 5))
        _startedAt = State(initialValue: episode?.startedAt ?? initialStartedAt ?? .now)
        _endedAtEnabled = State(initialValue: episode?.endedAt != nil)
        _endedAt = State(initialValue: episode?.endedAt ?? initialStartedAt ?? .now)
        _painLocation = State(initialValue: episode?.painLocation ?? "")
        _painCharacter = State(initialValue: episode?.painCharacter ?? "")
        _notes = State(initialValue: episode?.notes ?? "")
        _functionalImpact = State(initialValue: episode?.functionalImpact ?? "")
        _menstruationStatus = State(initialValue: episode?.menstruationStatus ?? .unknown)
        _selectedSymptoms = State(initialValue: Set(episode?.symptoms ?? []))
        _selectedTriggers = State(initialValue: Set(episode?.triggers ?? []))
        _medications = State(initialValue: episode?.medications.map(MedicationSelection.init) ?? [])
        _weatherEnabled = State(initialValue: episode?.weatherSnapshot != nil)
        _weatherCondition = State(initialValue: episode?.weatherSnapshot?.condition ?? "")
        _weatherTemperature = State(initialValue: EpisodeEditorView.stringValue(for: episode?.weatherSnapshot?.temperature, fractionDigits: 1))
        _weatherHumidity = State(initialValue: EpisodeEditorView.stringValue(for: episode?.weatherSnapshot?.humidity, fractionDigits: 0))
        _weatherPressure = State(initialValue: EpisodeEditorView.stringValue(for: episode?.weatherSnapshot?.pressure, fractionDigits: 0))
        _weatherSource = State(initialValue: episode?.weatherSnapshot?.source ?? "")
    }

    var body: some View {
        Form {
            if let validationMessage {
                Section {
                    Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .accessibilityLabel("Fehler: \(validationMessage)")
                }
            }

            Section {
                Picker("Typ", selection: $type) {
                    ForEach(EpisodeType.allCases) { episodeType in
                        Text(episodeType.rawValue).tag(episodeType)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Intensität")
                        Spacer()
                        Text("\(Int(intensity))/10")
                            .font(.headline)
                            .monospacedDigit()
                    }

                    IntensityPicker(value: $intensity)
                }

                DatePicker("Beginn", selection: $startedAt, displayedComponents: [.date, .hourAndMinute])
            } header: {
                Text("Schneller Eintrag")
            } footer: {
                Text("Nur Typ, Intensität und Zeitpunkt sind direkt sichtbar. Alles Weitere ist optional.")
            }

            tagSection(title: "Symptome", options: symptomOptions, selection: $selectedSymptoms)
            tagSection(title: "Trigger", options: triggerOptions, selection: $selectedTriggers)

            Section("Notiz") {
                TextField("Kurz notieren, was auffällt", text: $notes, axis: .vertical)
                    .lineLimit(2 ... 5)
            }

            Section("Optionale Details") {
                DisclosureGroup("Weitere Angaben") {
                    TextField("Schmerzlokalisation", text: $painLocation)
                    TextField("Schmerzcharakter", text: $painCharacter)
                    TextField("Funktionelle Einschränkung", text: $functionalImpact)

                    Picker("Menstruationsstatus", selection: $menstruationStatus) {
                        ForEach(MenstruationStatus.allCases) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }

                    Toggle("Ende angeben", isOn: $endedAtEnabled.animation())
                    if endedAtEnabled {
                        DatePicker("Ende", selection: $endedAt, in: startedAt..., displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }

            Section {
                Toggle("Wetterdaten manuell ergänzen", isOn: $weatherEnabled.animation())

                if weatherEnabled {
                    weatherConditionSection

                    TextField("Wetterlage, z. B. sonnig oder Regen", text: $weatherCondition)
                    TextField("Temperatur in °C", text: $weatherTemperature)
                        .keyboardType(.decimalPad)
                    TextField("Luftfeuchte in %", text: $weatherHumidity)
                        .keyboardType(.decimalPad)
                    TextField("Luftdruck in hPa", text: $weatherPressure)
                        .keyboardType(.decimalPad)
                    TextField("Quelle, z. B. manuell", text: $weatherSource)
                }
            } header: {
                Text("Wetter")
            } footer: {
                Text("Optional. Es wird keine Wetter-Schnittstelle verwendet, nur deine manuelle Eingabe lokal gespeichert.")
            }

            Section("Medikamente") {
                TextField("Medikament nach Namen filtern", text: $medicationSearchText)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                if filteredMedicationGroups.isEmpty {
                    ContentUnavailableView(
                        "Kein Medikament gefunden",
                        systemImage: "magnifyingglass",
                        description: Text("Passe den Suchbegriff an oder füge ein eigenes Medikament hinzu.")
                    )
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(filteredMedicationGroups) { group in
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
                                            isSelected: isMedicationSelected(definition),
                                            quantity: quantity(for: definition),
                                            onToggle: { toggleMedicationSelection(for: definition) },
                                            onDecrease: { decrementMedicationQuantity(for: definition) },
                                            onIncrease: { incrementMedicationQuantity(for: definition) },
                                            onEdit: definition.isCustom ? { presentEditor(for: definition) } : nil,
                                            onDelete: definition.isCustom ? { pendingMedicationDeletion = definition } : nil
                                        )
                                    }
                                }
                                .padding(12)
                                .background(Color(.systemBackground))
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

                if selectedMedications.isEmpty {
                    Text("Nur ergänzen, wenn du heute etwas genommen hast.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ausgewählt")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ForEach(selectedMedications) { medication in
                            SelectedMedicationSummaryRow(draft: medication) {
                                removeMedicationSelection(id: medication.id)
                            }
                        }
                    }
                }

                Button {
                    presentEditor(for: nil)
                } label: {
                    Label("Eigenes Medikament hinzufügen", systemImage: "plus.circle")
                }
            }

            Section {
                Button(mode == .create ? "Episode speichern" : "Änderungen speichern") {
                    saveEpisode()
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle(mode == .create ? "Erfassen" : "Episode bearbeiten")
        .toolbar {
            if showsDismissButton {
                ToolbarItem(placement: dismissButtonPlacement) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .alert("Episode gespeichert", isPresented: $saveMessageVisible) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Die Episode wurde lokal in SwiftData gespeichert.")
        }
        .sheet(item: $customMedicationEditor) { editorState in
            NavigationStack {
                CustomMedicationEditorSheet(
                    state: editorState,
                    onCancel: { customMedicationEditor = nil },
                    onSave: { draft in
                        saveCustomMedication(from: draft)
                    }
                )
            }
            .presentationDetents([.medium])
        }
        .alert(
            "Eigenes Medikament löschen?",
            isPresented: Binding(
                get: { pendingMedicationDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingMedicationDeletion = nil
                    }
                }
            ),
            presenting: pendingMedicationDeletion
        ) { definition in
            Button("Löschen", role: .destructive) {
                deleteCustomMedication(definition)
            }
            Button("Abbrechen", role: .cancel) {
                pendingMedicationDeletion = nil
            }
        } message: { definition in
            Text("\(definition.name) wird aus SwiftData entfernt.")
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
                        .background(isSelected ? Color.accentColor.opacity(0.16) : Color(.secondarySystemGroupedBackground))
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

    private var weatherConditionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Schnellauswahl")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                ForEach(weatherConditionOptions, id: \.self) { option in
                    let isSelected = weatherCondition == option

                    Button {
                        weatherCondition = isSelected ? "" : option
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
                        .background(isSelected ? Color.accentColor.opacity(0.16) : Color(.secondarySystemGroupedBackground))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Wetter: \(option)")
                    .accessibilityHint(isSelected ? "Entfernt die Auswahl." : "Wählt diese Wetterlage aus.")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    private var showsDismissButton: Bool {
        onSaved != nil || episode != nil
    }

    private var dismissButtonPlacement: ToolbarItemPlacement {
        #if targetEnvironment(macCatalyst)
        .topBarTrailing
        #else
        .topBarLeading
        #endif
    }

    private func saveEpisode() {
        validationMessage = nil

        if endedAtEnabled, endedAt < startedAt {
            validationMessage = "Das Ende darf nicht vor dem Beginn liegen."
            return
        }

        let parsedWeather: ValidatedWeatherSnapshot?

        do {
            parsedWeather = try validatedWeatherSnapshot()
        } catch {
            validationMessage = error.localizedDescription
            return
        }

        let target = episode ?? Episode(startedAt: startedAt, intensity: Int(intensity))

        target.markUpdated()
        target.type = type
        target.startedAt = startedAt
        target.endedAt = endedAtEnabled ? endedAt : nil
        target.intensity = Int(intensity)
        target.painLocation = painLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        target.painCharacter = painCharacter.trimmingCharacters(in: .whitespacesAndNewlines)
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        target.functionalImpact = functionalImpact.trimmingCharacters(in: .whitespacesAndNewlines)
        target.menstruationStatus = menstruationStatus
        target.symptoms = Array(selectedSymptoms).sorted()
        target.triggers = Array(selectedTriggers).sorted()

        for medication in target.medications {
            modelContext.delete(medication)
        }

        if let existingWeatherSnapshot = target.weatherSnapshot {
            modelContext.delete(existingWeatherSnapshot)
            target.weatherSnapshot = nil
        }

        if episode == nil {
            modelContext.insert(target)
        }

        for draft in selectedMedications {
            let entry = MedicationEntry(
                name: draft.name,
                category: draft.category,
                dosage: draft.dosage,
                quantity: draft.quantity,
                takenAt: startedAt,
                effectiveness: .partial,
                episode: target
            )
            target.medications.append(entry)
        }

        if let parsedWeather {
            let snapshot = WeatherSnapshot(
                recordedAt: startedAt,
                temperature: parsedWeather.temperature,
                condition: parsedWeather.condition,
                humidity: parsedWeather.humidity,
                pressure: parsedWeather.pressure,
                source: parsedWeather.source,
                episode: target
            )
            target.weatherSnapshot = snapshot
        }

        do {
            try modelContext.save()
            validationMessage = nil

            if mode == .create, onSaved == nil {
                resetForm()
                saveMessageVisible = true
            } else {
                onSaved?()
                dismiss()
            }
        } catch {
            validationMessage = "Speichern fehlgeschlagen. Bitte versuche es erneut."
        }
    }

    private func resetForm() {
        type = .unclear
        intensity = 5
        startedAt = .now
        endedAtEnabled = false
        endedAt = .now
        painLocation = ""
        painCharacter = ""
        notes = ""
        functionalImpact = ""
        menstruationStatus = .unknown
        selectedSymptoms = []
        selectedTriggers = []
        medications = []
        weatherEnabled = false
        weatherCondition = ""
        weatherTemperature = ""
        weatherHumidity = ""
        weatherPressure = ""
        weatherSource = ""
        medicationSearchText = ""
        customMedicationEditor = nil
        pendingMedicationDeletion = nil
        validationMessage = nil
    }

    private var filteredMedicationGroups: [MedicationDefinitionGroup] {
        let query = medicationSearchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return allMedicationGroups
        }

        return allMedicationGroups.compactMap { group in
            let items = group.items.filter { $0.name.localizedCaseInsensitiveContains(query) }

            guard !items.isEmpty else {
                return nil
            }

            return MedicationDefinitionGroup(
                id: group.id,
                title: group.title,
                footer: group.footer,
                items: items
            )
        }
    }

    private var allMedicationGroups: [MedicationDefinitionGroup] {
        let knownKeys = Set(medicationDefinitions.map(\.selectionKey))
        let persistedGroups = Dictionary(grouping: medicationDefinitions) { $0.groupID }
        let sortedGroupIDs = persistedGroups.keys.sorted { lhs, rhs in
            let leftOrder = persistedGroups[lhs]?.map(\.sortOrder).min() ?? .max
            let rightOrder = persistedGroups[rhs]?.map(\.sortOrder).min() ?? .max
            return leftOrder < rightOrder
        }

        var groups = sortedGroupIDs.compactMap { groupID -> MedicationDefinitionGroup? in
            guard let items = persistedGroups[groupID], let first = items.first else {
                return nil
            }

            return MedicationDefinitionGroup(
                id: groupID,
                title: first.groupTitle,
                footer: first.groupFooter,
                items: items.sorted { $0.sortOrder < $1.sortOrder }
            )
        }

        let orphanSelections = medications.compactMap { selection -> MedicationDefinition? in
            guard !knownKeys.contains(selection.selectionKey) else {
                return nil
            }

            return MedicationDefinition(
                catalogKey: "selection:\(selection.selectionKey)",
                groupID: customGroupID,
                groupTitle: customGroupTitle,
                groupFooter: customGroupFooter,
                name: selection.name,
                category: selection.category,
                suggestedDosage: selection.dosage,
                sortOrder: Int.max - 1,
                isCustom: true
            )
        }

        if !orphanSelections.isEmpty {
            groups.removeAll { $0.id == customGroupID }
            let customItems = (persistedGroups[customGroupID] ?? []) + orphanSelections
            let deduped = Dictionary(uniqueKeysWithValues: customItems.map { ($0.selectionKey, $0) }).values
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            groups.append(
                MedicationDefinitionGroup(
                    id: customGroupID,
                    title: customGroupTitle,
                    footer: customGroupFooter,
                    items: deduped
                )
            )
        }

        return groups
    }

    private var selectedMedications: [MedicationSelection] {
        medications
            .filter(\.isSelected)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func isMedicationSelected(_ definition: MedicationDefinition) -> Bool {
        medications.contains { $0.selectionKey == definition.selectionKey && $0.isSelected }
    }

    private func quantity(for definition: MedicationDefinition) -> Int {
        medications.first(where: { $0.selectionKey == definition.selectionKey })?.quantity ?? 1
    }

    private func toggleMedicationSelection(for definition: MedicationDefinition) {
        if let index = medications.firstIndex(where: { $0.selectionKey == definition.selectionKey }) {
            medications[index].isSelected.toggle()
            medications[index].quantity = max(1, medications[index].quantity)
        } else {
            medications.append(MedicationSelection(definition: definition))
        }
    }

    private func incrementMedicationQuantity(for definition: MedicationDefinition) {
        if let index = medications.firstIndex(where: { $0.selectionKey == definition.selectionKey }) {
            medications[index].quantity += 1
            medications[index].isSelected = true
        } else {
            medications.append(MedicationSelection(definition: definition))
        }
    }

    private func decrementMedicationQuantity(for definition: MedicationDefinition) {
        guard let index = medications.firstIndex(where: { $0.selectionKey == definition.selectionKey }) else {
            return
        }

        medications[index].quantity = max(1, medications[index].quantity - 1)
        medications[index].isSelected = true
    }

    private func removeMedicationSelection(id: UUID) {
        guard let index = medications.firstIndex(where: { $0.id == id }) else {
            return
        }

        medications[index].isSelected = false
        medications[index].quantity = 1
    }

    private func presentEditor(for definition: MedicationDefinition?) {
        customMedicationEditor = CustomMedicationEditorState(definition: definition)
    }

    private func saveCustomMedication(from draft: CustomMedicationDraft) {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDosage = draft.dosage.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            validationMessage = "Bitte gib einen Namen für das eigene Medikament ein."
            return
        }

        if let existing = medicationDefinitions.first(where: {
            $0.catalogKey != draft.id &&
            $0.name.compare(trimmedName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) {
            toggleMedicationSelection(for: existing)
            customMedicationEditor = nil
            validationMessage = nil
            return
        }

        let existingSelectionKey = draft.originalSelectionKey
        let definition: MedicationDefinition

        if let existingDefinition = medicationDefinitions.first(where: { $0.catalogKey == draft.id }) {
            definition = existingDefinition
            definition.markUpdated()
            definition.name = trimmedName
            definition.category = draft.category
            definition.suggestedDosage = trimmedDosage
        } else {
            let nextSortOrder = (medicationDefinitions.map(\.sortOrder).max() ?? 0) + 1
            definition = MedicationDefinition(
                catalogKey: "custom:\(UUID().uuidString)",
                groupID: customGroupID,
                groupTitle: customGroupTitle,
                groupFooter: customGroupFooter,
                name: trimmedName,
                category: draft.category,
                suggestedDosage: trimmedDosage,
                sortOrder: nextSortOrder,
                isCustom: true
            )
            modelContext.insert(definition)
        }

        do {
            try modelContext.save()
            customMedicationEditor = nil
            validationMessage = nil

            if let existingSelectionKey {
                updateMedicationSelection(
                    from: existingSelectionKey,
                    to: definition
                )
            } else {
                toggleMedicationSelection(for: definition)
            }
        } catch {
            validationMessage = "Eigenes Medikament konnte nicht gespeichert werden."
        }
    }

    private func updateMedicationSelection(from oldSelectionKey: String, to definition: MedicationDefinition) {
        guard let index = medications.firstIndex(where: { $0.selectionKey == oldSelectionKey }) else {
            return
        }

        medications[index].selectionKey = definition.selectionKey
        medications[index].name = definition.name
        medications[index].category = definition.category
        medications[index].dosage = definition.suggestedDosage
        medications[index].isSelected = true
    }

    private func deleteCustomMedication(_ definition: MedicationDefinition) {
        medications.removeAll { $0.selectionKey == definition.selectionKey }
        definition.markDeleted()

        do {
            try modelContext.save()
            pendingMedicationDeletion = nil
            validationMessage = nil
        } catch {
            validationMessage = "Eigenes Medikament konnte nicht gelöscht werden."
        }
    }

    private func validatedWeatherSnapshot() throws -> ValidatedWeatherSnapshot? {
        guard weatherEnabled else {
            return nil
        }

        return try WeatherInputValidator.validate(
            isEnabled: weatherEnabled,
            condition: weatherCondition,
            temperatureText: weatherTemperature,
            humidityText: weatherHumidity,
            pressureText: weatherPressure,
            source: weatherSource
        )
    }

    private static func stringValue(for value: Double?, fractionDigits: Int) -> String {
        guard let value else {
            return ""
        }

        return value.formatted(.number.precision(.fractionLength(fractionDigits)))
    }

    private var medicationDefinitions: [MedicationDefinition] {
        storedMedicationDefinitions.filter { !$0.isDeleted }
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
                        .background(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
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

private struct MedicationDefinitionGroup: Identifiable {
    let id: String
    let title: String
    let footer: String?
    let items: [MedicationDefinition]
}

private struct MedicationSelection: Identifiable {
    let id: UUID
    var selectionKey: String
    var name: String
    var category: MedicationCategory
    var dosage: String
    var quantity: Int
    var isSelected: Bool

    init(entry: MedicationEntry) {
        self.id = entry.id
        self.name = entry.name
        self.category = entry.category
        self.dosage = entry.dosage
        self.quantity = max(1, entry.quantity)
        self.isSelected = true
        self.selectionKey = MedicationSelection.makeSelectionKey(
            name: entry.name,
            category: entry.category,
            dosage: entry.dosage
        )
    }

    init(definition: MedicationDefinition) {
        self.id = UUID()
        self.name = definition.name
        self.category = definition.category
        self.dosage = definition.suggestedDosage
        self.quantity = 1
        self.isSelected = true
        self.selectionKey = definition.selectionKey
    }

    private static func makeSelectionKey(name: String, category: MedicationCategory, dosage: String) -> String {
        [
            name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            category.rawValue,
            dosage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        ].joined(separator: "|")
    }
}

private struct MedicationDefinitionRow: View {
    let definition: MedicationDefinition
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
        .background(isSelected ? Color.accentColor.opacity(0.14) : Color(.secondarySystemGroupedBackground))
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

private struct CustomMedicationEditorState: Identifiable {
    let id: String
    let originalSelectionKey: String?
    let initialName: String
    let initialCategory: MedicationCategory
    let initialDosage: String

    init(definition: MedicationDefinition?) {
        id = definition?.catalogKey ?? UUID().uuidString
        originalSelectionKey = definition?.selectionKey
        initialName = definition?.name ?? ""
        initialCategory = definition?.category ?? .other
        initialDosage = definition?.suggestedDosage ?? ""
    }

    var isEditing: Bool {
        originalSelectionKey != nil
    }
}

private struct CustomMedicationDraft {
    let id: String
    let originalSelectionKey: String?
    let name: String
    let category: MedicationCategory
    let dosage: String
}

private struct CustomMedicationEditorSheet: View {
    let state: CustomMedicationEditorState
    let onCancel: () -> Void
    let onSave: (CustomMedicationDraft) -> Void

    @State private var name: String
    @State private var category: MedicationCategory
    @State private var dosage: String

    init(
        state: CustomMedicationEditorState,
        onCancel: @escaping () -> Void,
        onSave: @escaping (CustomMedicationDraft) -> Void
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
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                Picker("Kategorie", selection: $category) {
                    ForEach(MedicationCategory.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }

                TextField("Dosierung", text: $dosage)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .navigationTitle(state.isEditing ? "Medikament bearbeiten" : "Eigenes Medikament")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen", action: onCancel)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(state.isEditing ? "Speichern" : "Hinzufügen") {
                    onSave(
                        CustomMedicationDraft(
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
    let draft: MedicationSelection
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
        .background(Color(.secondarySystemGroupedBackground))
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
    NavigationStack {
        EpisodeEditorView()
    }
}
