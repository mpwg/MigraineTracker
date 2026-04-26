import SwiftUI
import UIKit

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
        @Bindable var medicationController = controller.medicationController

        Form {
            if let validationMessage = controller.validationMessage {
                EpisodeValidationMessageSection(message: validationMessage)
            }

            EpisodeScaleSection(draft: $controller.draft)
            EpisodeTimingSection(draft: $controller.draft)
            EpisodeTagSection(
                title: "Was spürst du?",
                options: controller.symptomOptions,
                selection: $controller.draft.selectedSymptoms,
                colorToken: NewEntryStepCatalog.metadata(for: .headache).colorToken
            )
            EpisodeTagSection(
                title: "Was könnte mitspielen?",
                options: controller.triggerOptions,
                selection: $controller.draft.selectedTriggers,
                colorToken: NewEntryStepCatalog.metadata(for: .triggers).colorToken
            )
            EpisodeNotesSection(draft: $controller.draft)
            EpisodeOptionalDetailsSection(draft: $controller.draft)
            EpisodeWeatherSection(state: controller.weatherLoadState)
            EpisodeMedicationSection(controller: controller.medicationController)
            EpisodeSaveSection(mode: controller.mode, isSaving: controller.isSaving, onSave: save)
        }
        .navigationTitle(controller.mode == .create ? "Eintragen" : "Eintrag bearbeiten")
        .brandGroupedScreen()
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
        .alert("Eintrag gespeichert", isPresented: $controller.saveMessageVisible) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Dein Eintrag wurde lokal gespeichert.")
        }
        .sheet(item: $medicationController.customMedicationEditor) { editorState in
            NavigationStack {
                CustomMedicationEditorSheet(
                    state: editorState,
                    onCancel: { medicationController.customMedicationEditor = nil },
                    onSave: { draft in
                        Task {
                            await medicationController.saveCustomMedication(from: draft)
                        }
                    }
                )
            }
            .presentationDetents([.medium])
        }
        .alert(
            "Eigenes Medikament löschen?",
            isPresented: Binding(
                get: { medicationController.pendingMedicationDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        medicationController.pendingMedicationDeletion = nil
                    }
                }
            ),
            presenting: medicationController.pendingMedicationDeletion
        ) { definition in
            Button("Löschen", role: .destructive) {
                Task {
                    await medicationController.deleteCustomMedication(definition)
                }
            }
            Button("Abbrechen", role: .cancel) {
                medicationController.pendingMedicationDeletion = nil
            }
        } message: { definition in
            Text("\(definition.name) wird aus SwiftData entfernt.")
        }
        .task(id: controller.draft.startedAt) {
            await controller.refreshWeather()
        }
    }

    private func save() {
        controller.save(onSaved: onSaved) {
            dismiss()
        }
    }

    private var showsDismissButton: Bool {
        onSaved != nil || controller.mode == .edit
    }

    private var dismissButtonPlacement: ToolbarItemPlacement {
        #if targetEnvironment(macCatalyst)
        .topBarTrailing
        #else
        .topBarLeading
        #endif
    }
}

private struct FormAlignedRowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.brandGroupedRow()
    }
}

private extension View {
    func formAlignedRow() -> some View {
        modifier(FormAlignedRowModifier())
    }
}

private struct EpisodeValidationMessageSection: View {
    let message: String

    var body: some View {
        Section {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(AppTheme.symiCoral)
                .accessibilityLabel("Hinweis: \(message)")
                .formAlignedRow()
        }
    }
}

private struct EpisodeScaleSection: View {
    @Binding var draft: EpisodeDraft

    var body: some View {
        Section {
            Picker("Typ", selection: $draft.type) {
                ForEach(EpisodeType.allCases) { episodeType in
                    Text(episodeType.rawValue).tag(episodeType)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Intensität")
                    Spacer()
                    Text("\(draft.intensity)/10")
                        .font(.headline)
                        .monospacedDigit()
                }

                IntensityPicker(value: Binding(
                    get: { Double(draft.intensity) },
                    set: { draft.intensity = Int($0) }
                ))
            }
            .formAlignedRow()
        } header: {
            Text("Skala")
        } footer: {
            Text("Wenige Angaben reichen. Alles Weitere bleibt optional.")
        }
    }
}

private struct EpisodeTimingSection: View {
    @Binding var draft: EpisodeDraft

    var body: some View {
        Section("Tagesbereich") {
            DatePicker(
                "Beginn",
                selection: $draft.startedAt,
                in: ...Date.now,
                displayedComponents: [.date, .hourAndMinute]
            )
            .formAlignedRow()
        }
    }
}

private struct EpisodeTagSection: View {
    let title: String
    let options: [String]
    @Binding var selection: Set<String>
    let colorToken: NewEntryStepColorToken

    var body: some View {
        Section(title) {
            MultiSelectGrid(
                options: options,
                selection: $selection,
                colorToken: colorToken,
                accessibilityPrefix: title
            )
            .formAlignedRow()
        }
    }
}

private struct EpisodeNotesSection: View {
    @Binding var draft: EpisodeDraft

    var body: some View {
        Section("Notiz") {
            TextField("Kurz notieren, was auffällt", text: $draft.notes, axis: .vertical)
                .lineLimit(2 ... 5)
                .formAlignedRow()
        }
    }
}

private struct EpisodeOptionalDetailsSection: View {
    @Binding var draft: EpisodeDraft

    var body: some View {
        Section("Optionale Details") {
            DisclosureGroup("Weitere Angaben") {
                TextField("Schmerzlokalisation", text: $draft.painLocation)
                TextField("Schmerzcharakter", text: $draft.painCharacter)
                TextField("Funktionelle Einschränkung", text: $draft.functionalImpact)

                Picker("Menstruationsstatus", selection: $draft.menstruationStatus) {
                    ForEach(MenstruationStatus.allCases) { status in
                        Text(status.rawValue).tag(status)
                    }
                }

                Toggle("Ende angeben", isOn: $draft.endedAtEnabled.animation())
                if draft.endedAtEnabled {
                    DatePicker(
                        "Ende",
                        selection: $draft.endedAt,
                        in: draft.startedAt...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
            }
        }
    }
}

private struct EpisodeWeatherSection: View {
    let state: WeatherLoadState

    var body: some View {
        Section {
            WeatherStatusContent(state: state)
                .formAlignedRow()
        } header: {
            Text("Wetter")
        } footer: {
            Text("Das Wetter wird mit deinem ungefähren Standort über Apple Weather geladen. Der Eintrag wird auch ohne Wetter gespeichert, wenn keine Freigabe vorliegt.")
        }
    }
}

private struct EpisodeMedicationSection: View {
    let controller: EpisodeMedicationSelectionController

    var body: some View {
        @Bindable var controller = controller

        Section("Medikamente") {
            TextField("Medikament nach Namen filtern", text: $controller.searchText)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()

            MedicationDefinitionGroupList(controller: controller)
            SelectedMedicationsSection(controller: controller)

            Button {
                controller.presentEditor(for: nil)
            } label: {
                Label("Eigenes Medikament hinzufügen", systemImage: "plus")
            }
            .formAlignedRow()
        }
    }
}

private struct MedicationDefinitionGroupList: View {
    let controller: EpisodeMedicationSelectionController

    var body: some View {
        if controller.filteredMedicationGroups.isEmpty {
            ContentUnavailableView(
                "Kein Medikament gefunden",
                systemImage: "magnifyingglass",
                description: Text("Passe den Suchbegriff an oder füge ein eigenes Medikament hinzu.")
            )
        } else {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(controller.filteredMedicationGroups) { group in
                    MedicationDefinitionGroupView(group: group, controller: controller)
                }
            }
            .padding(.vertical, 4)
            .formAlignedRow()
        }
    }
}

private struct MedicationDefinitionGroupView: View {
    let group: EpisodeEditorMedicationGroup
    let controller: EpisodeMedicationSelectionController

    var body: some View {
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
            .brandCard()

            if let footer = group.footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SelectedMedicationsSection: View {
    let controller: EpisodeMedicationSelectionController

    var body: some View {
        if controller.selectedMedications.isEmpty {
            Text("Nur ergänzen, wenn du heute etwas genommen hast.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .formAlignedRow()
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
            .formAlignedRow()
        }
    }
}

private struct EpisodeSaveSection: View {
    let mode: EpisodeEditorMode
    let isSaving: Bool
    let onSave: () -> Void

    var body: some View {
        Section {
            PrimaryButton(action: onSave) {
                Text(mode == .create ? "Eintrag speichern" : "Änderungen speichern")
            }
                .disabled(isSaving)
                .formAlignedRow()
        }
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
                WeatherAttributionView()
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

                    Button("Einstellungen öffnen") {
                        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
                            return
                        }
                        openURL(settingsURL)
                    }
                    .buttonStyle(SymiSecondaryButtonStyle())
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Slider(value: $value, in: 0 ... 10, step: 1)
                .tint(AppTheme.symiCoral)
                .accessibilityLabel("Intensität")
                .accessibilityValue("\(Int(value)) von 10")

            HStack {
                Text("ruhig")
                Spacer()
                Text("stark")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.symiTextSecondary)
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
                        .foregroundStyle(isSelected ? AppTheme.ocean : .primary)
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
        .background(isSelected ? AppTheme.selectedFill : AppTheme.secondaryFill)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? AppTheme.ocean.opacity(0.24) : Color.white.opacity(0.45), lineWidth: 1)
        }
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
        .brandGroupedScreen()
        .navigationBarTitleDisplayMode(.inline)
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
        .background(AppTheme.secondaryFill)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
        }
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
