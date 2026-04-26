import SwiftUI

struct EntryFlowCoordinatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var coordinator: EntryFlowCoordinator

    private let onSaved: (() -> Void)?

    init(
        appContainer: AppContainer,
        initialStartedAt: Date? = nil,
        onSaved: (() -> Void)? = nil
    ) {
        self.onSaved = onSaved
        _coordinator = State(
            initialValue: appContainer.makeEntryFlowCoordinator(initialStartedAt: initialStartedAt)
        )
    }

    var body: some View {
        @Bindable var coordinator = coordinator

        NavigationStack(path: $coordinator.path) {
            EntryHeadacheStepView(coordinator: coordinator)
                .navigationDestination(for: EntryFlowStep.self) { step in
                    destination(for: step)
                }
        }
        .toolbar {
            ToolbarItem(placement: dismissButtonPlacement) {
                Button("Abbrechen", action: cancel)
            }
        }
        .alert("Eintrag gespeichert", isPresented: savedBinding) {
            Button("OK", role: .cancel, action: finishAfterSave)
        } message: {
            Text("Dein Eintrag wurde lokal gespeichert.")
        }
        .alert("Eintrag konnte nicht gespeichert werden", isPresented: failedBinding) {
            Button("OK", role: .cancel) {
                coordinator.saveResult = nil
            }
        } message: {
            if case .failed(let message) = coordinator.saveResult {
                Text(message)
            }
        }
    }

    @ViewBuilder
    private func destination(for step: EntryFlowStep) -> some View {
        switch step {
        case .headache:
            EntryHeadacheStepView(coordinator: coordinator)
        case .medication:
            EntryMedicationStepView(coordinator: coordinator)
        case .triggers:
            EntryTriggersStepView(coordinator: coordinator)
        case .note:
            EntryNoteStepView(coordinator: coordinator)
        case .review:
            EntryReviewStepView(coordinator: coordinator)
        }
    }

    private var savedBinding: Binding<Bool> {
        Binding(
            get: {
                if case .saved = coordinator.saveResult {
                    return true
                }
                return false
            },
            set: { isPresented in
                if !isPresented {
                    coordinator.saveResult = nil
                }
            }
        )
    }

    private var failedBinding: Binding<Bool> {
        Binding(
            get: {
                if case .failed = coordinator.saveResult {
                    return true
                }
                return false
            },
            set: { isPresented in
                if !isPresented {
                    coordinator.saveResult = nil
                }
            }
        )
    }

    private var dismissButtonPlacement: ToolbarItemPlacement {
        #if targetEnvironment(macCatalyst)
        .topBarTrailing
        #else
        .topBarLeading
        #endif
    }

    private func cancel() {
        coordinator.cancel()
        dismiss()
    }

    private func finishAfterSave() {
        coordinator.saveResult = nil
        onSaved?()
        dismiss()
    }
}

private struct EntryHeadacheStepView: View {
    let coordinator: EntryFlowCoordinator

    @State private var selectedStartedAtPreset: EntryStartedAtPreset = .now

    var body: some View {
        @Bindable var coordinator = coordinator

        Form {
            EntryStepHeader(step: .headache, currentIndex: coordinator.currentStepIndex)

            Section {
                HeadacheIntensityCard(intensity: $coordinator.draft.intensity)
            } header: {
                Text("Intensität")
            } footer: {
                Text("Du kannst nach diesem Schritt direkt speichern oder weitere Details ergänzen.")
            }

            Section("Schmerzort") {
                MultiSelectGrid(
                    options: coordinator.painLocationOptions,
                    selection: $coordinator.draft.selectedPainLocations,
                    colorToken: NewEntryStepCatalog.metadata(for: .headache).colorToken,
                    accessibilityPrefix: "Schmerzort"
                )
            }

            Section("Zeitpunkt") {
                Picker("Zeitpunkt", selection: $selectedStartedAtPreset) {
                    ForEach(EntryStartedAtPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .pickerStyle(.inline)
                .onChange(of: selectedStartedAtPreset) { _, preset in
                    if preset != .custom {
                        coordinator.selectStartedAtPreset(preset)
                    }
                }

                DatePicker(
                    "Beginn",
                    selection: $coordinator.draft.startedAt,
                    in: ...Date.now,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .disabled(selectedStartedAtPreset != .custom)
            }

            EntryStepActions(
                isSaving: coordinator.isSaving,
                showsSkip: false,
                primaryTitle: "Weiter",
                secondaryTitle: "Nur Kopfschmerz speichern",
                onPrimary: coordinator.continueToNextStep,
                onSecondary: coordinator.saveHeadacheOnly,
                onSkip: {}
            )
        }
        .navigationTitle("Kopfschmerz")
        .brandGroupedScreen()
        .onAppear {
            coordinator.draft.type = .headache
            coordinator.draft.intensity = coordinator.draft.normalizedIntensity
        }
    }
}

private struct HeadacheIntensityCard: View {
    @Binding var intensity: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Wie stark ist es gerade?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(summary)
                        .font(.title2.weight(.bold))
                        .monospacedDigit()
                }

                Spacer()

                Text("\(normalizedIntensity)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.symiCoral)
            }

            IntensityPicker(value: Binding(
                get: { Double(normalizedIntensity) },
                set: { intensity = Int($0) }
            ))
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Intensität \(normalizedIntensity) von 10, \(intensityLabel)")
    }

    private var normalizedIntensity: Int {
        min(max(intensity, 1), 10)
    }

    private var summary: String {
        "\(normalizedIntensity)/10 · \(intensityLabel)"
    }

    private var intensityLabel: String {
        switch normalizedIntensity {
        case 1 ... 3:
            "Leicht"
        case 4 ... 6:
            "Mittel"
        case 7 ... 8:
            "Stark"
        default:
            "Sehr stark"
        }
    }
}

private struct EntryMedicationStepView: View {
    let coordinator: EntryFlowCoordinator

    var body: some View {
        @Bindable var coordinator = coordinator
        @Bindable var medicationController = coordinator.medicationController

        Form {
            EntryStepHeader(step: .medication, currentIndex: coordinator.currentStepIndex)

            Section {
                Text("Hast du etwas genommen?")
                    .font(.headline)
                Text("Übersichtlich. Schnell. Kontextbewusst.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !coordinator.draft.continuousMedicationChecks.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Dauermedikation", systemImage: "pills.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.symiPetrol)

                        Text("Bestätige deine regelmäßige Medikation für heute.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        ForEach($coordinator.draft.continuousMedicationChecks) { $check in
                            ContinuousMedicationCheckRow(check: $check)
                        }

                        Text("Du kannst dies jederzeit in den Einstellungen anpassen.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Heute genommen?")
                }
            }

            Section {
                MedicationQuickSelectionGrid(
                    controller: coordinator.medicationController,
                    hasContinuousMedication: !coordinator.draft.continuousMedicationChecks.isEmpty
                )

                DisclosureGroup("Weitere Medikamente") {
                    TextField("Medikament nach Namen filtern", text: $medicationController.searchText)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()

                    MedicationDefinitionGroupList(controller: coordinator.medicationController)

                    Button {
                        medicationController.presentEditor(for: nil)
                    } label: {
                        Label("Eigenes Medikament hinzufügen", systemImage: "plus")
                    }
                }

                SelectedMedicationsSection(controller: coordinator.medicationController)
            } header: {
                Text(coordinator.draft.continuousMedicationChecks.isEmpty ? "Zusätzlich etwas genommen?" : "Zusätzlich etwas genommen?")
            } footer: {
                Text("Dosierung ist optional und kann über Medikamentenvorlagen oder eigene Medikamente gespeichert werden.")
            }

            EntryStepActions(
                isSaving: coordinator.isSaving,
                showsSkip: true,
                primaryTitle: "Weiter",
                secondaryTitle: nil,
                onPrimary: coordinator.continueToNextStep,
                onSecondary: nil,
                onSkip: coordinator.skipCurrentStep
            )
        }
        .navigationTitle("Medikation")
        .brandGroupedScreen()
        .task {
            await coordinator.continuousMedicationController.reload(for: coordinator.draft.startedAt)
            if coordinator.draft.continuousMedicationChecks.isEmpty {
                coordinator.draft.continuousMedicationChecks = coordinator.continuousMedicationController.makeDefaultChecks()
            }
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
    }
}

private struct ContinuousMedicationCheckRow: View {
    @Binding var check: ContinuousMedicationCheckDraft

    var body: some View {
        Toggle(isOn: $check.wasTaken) {
            HStack(spacing: 12) {
                Image(systemName: "pills")
                    .foregroundStyle(AppTheme.symiPetrol)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(check.name)
                        .font(.subheadline.weight(.semibold))
                    if !check.detailText.isEmpty {
                        Text(check.detailText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .toggleStyle(.button)
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityLabel("\(check.name) heute genommen")
    }
}

private struct MedicationQuickSelectionGrid: View {
    let controller: EpisodeMedicationSelectionController
    let hasContinuousMedication: Bool

    private let options: [(String, MedicationCategory, String)] = [
        ("Ibuprofen", .nsar, "400 mg"),
        ("Triptan", .triptan, ""),
        ("Paracetamol", .paracetamol, "500 mg"),
        ("Andere", .other, "")
    ]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 10)], spacing: 10) {
            ForEach(options, id: \.0) { option in
                Button {
                    controller.toggleMedicationSelection(
                        named: option.0,
                        fallbackCategory: option.1,
                        fallbackDosage: option.2
                    )
                } label: {
                    Label(option.0, systemImage: controller.isMedicationNameSelected(option.0) ? "checkmark.circle.fill" : "circle")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(controller.isMedicationNameSelected(option.0) ? AppTheme.symiPetrol : .secondary)
            }

            Button {
                controller.resetSelections()
            } label: {
                Label(hasContinuousMedication ? "Keine weitere Medikation" : "Keine Medikation", systemImage: "slash.circle")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct EntryTriggersStepView: View {
    let coordinator: EntryFlowCoordinator

    var body: some View {
        @Bindable var coordinator = coordinator

        Form {
            EntryStepHeader(step: .triggers, currentIndex: coordinator.currentStepIndex)

            Section {
                MultiSelectGrid(
                    options: coordinator.triggerOptions,
                    selection: $coordinator.draft.selectedTriggers,
                    colorToken: NewEntryStepCatalog.metadata(for: .triggers).colorToken,
                    accessibilityPrefix: "Auslöser"
                )
            } header: {
                Text("Was könnte eine Rolle gespielt haben?")
            } footer: {
                Text("Du kannst mehrere auswählen. Wetter als Auslöser bleibt getrennt vom automatisch gespeicherten Wetterkontext.")
            }

            EntryStepActions(
                isSaving: coordinator.isSaving,
                showsSkip: true,
                primaryTitle: "Weiter",
                secondaryTitle: nil,
                onPrimary: coordinator.continueToNextStep,
                onSecondary: nil,
                onSkip: coordinator.skipCurrentStep
            )
        }
        .navigationTitle("Auslöser")
        .brandGroupedScreen()
    }
}

private struct EntryNoteStepView: View {
    let coordinator: EntryFlowCoordinator

    var body: some View {
        @Bindable var coordinator = coordinator

        Form {
            EntryStepHeader(step: .note, currentIndex: coordinator.currentStepIndex)

            Section("Notiz") {
                TextField("Kurz notieren, was auffällt", text: $coordinator.draft.notes, axis: .vertical)
                    .lineLimit(3 ... 8)
            }

            Section("Weitere Angaben") {
                TextField("Schmerzlokalisation", text: $coordinator.draft.painLocation)
                TextField("Schmerzcharakter", text: $coordinator.draft.painCharacter)
                TextField("Funktionelle Einschränkung", text: $coordinator.draft.functionalImpact)

                Picker("Menstruationsstatus", selection: $coordinator.draft.menstruationStatus) {
                    ForEach(MenstruationStatus.allCases) { status in
                        Text(status.rawValue).tag(status)
                    }
                }

                Toggle("Ende angeben", isOn: $coordinator.draft.endedAtEnabled.animation())
                if coordinator.draft.endedAtEnabled {
                    DatePicker(
                        "Ende",
                        selection: $coordinator.draft.endedAt,
                        in: coordinator.draft.startedAt...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
            }

            EntryStepActions(
                isSaving: coordinator.isSaving,
                showsSkip: true,
                primaryTitle: "Weiter",
                secondaryTitle: nil,
                onPrimary: coordinator.continueToNextStep,
                onSecondary: nil,
                onSkip: coordinator.skipCurrentStep
            )
        }
        .navigationTitle("Notiz")
        .brandGroupedScreen()
    }
}

private struct EntryReviewStepView: View {
    let coordinator: EntryFlowCoordinator

    var body: some View {
        Form {
            EntryStepHeader(step: .review, currentIndex: coordinator.currentStepIndex)

            Section("Zusammenfassung") {
                EntryReviewRow(title: "Kopfschmerz", value: "\(coordinator.draft.type.rawValue), \(coordinator.draft.intensity)/10") {
                    coordinator.edit(.headache)
                }

                EntryReviewRow(title: "Medikation", value: medicationSummary) {
                    coordinator.edit(.medication)
                }

                EntryReviewRow(title: "Auslöser", value: listSummary(coordinator.draft.selectedTriggers)) {
                    coordinator.edit(.triggers)
                }

                EntryReviewRow(title: "Notiz", value: coordinator.draft.notes.isEmpty ? "Keine Notiz" : coordinator.draft.notes) {
                    coordinator.edit(.note)
                }
            }

            Section {
                PrimaryButton(action: coordinator.saveFromReview) {
                    if coordinator.isSaving {
                        ProgressView()
                    } else {
                        Text("Eintrag speichern")
                    }
                }
                .disabled(coordinator.isSaving)
            }
        }
        .navigationTitle("Eintrag prüfen")
        .brandGroupedScreen()
    }

    private var medicationSummary: String {
        let selected = coordinator.medicationController.selectedMedications
        let continuous = coordinator.draft.continuousMedicationChecks
        guard !selected.isEmpty || !continuous.isEmpty else {
            return "Keine Medikation"
        }

        let continuousSummary = continuous.map {
            "\($0.name): \($0.wasTaken ? "genommen" : "nicht genommen")"
        }
        let acuteSummary = selected.map { medication in
            medication.quantity > 1 ? "\(medication.name) x\(medication.quantity)" : medication.name
        }

        return (continuousSummary + acuteSummary).joined(separator: ", ")
    }

    private func listSummary(_ values: Set<String>) -> String {
        guard !values.isEmpty else {
            return "Nichts ausgewählt"
        }

        return values.sorted().joined(separator: ", ")
    }
}

private struct EntryStepHeader: View {
    let step: EntryFlowStep
    let currentIndex: Int

    var body: some View {
        let metadata = NewEntryStepCatalog.metadata(for: step.catalogID)

        Section {
            HStack(spacing: 14) {
                StepIcon(metadata)

                VStack(alignment: .leading, spacing: 6) {
                    Text(metadata.title)
                        .font(.headline)
                    Text(metadata.subline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)

            ProgressIndicator(currentStep: currentIndex, colorToken: metadata.colorToken)
        }
    }
}

private struct EntryStepActions: View {
    let isSaving: Bool
    let showsSkip: Bool
    let primaryTitle: String
    let secondaryTitle: String?
    let onPrimary: () -> Void
    let onSecondary: (() -> Void)?
    let onSkip: () -> Void

    var body: some View {
        Section {
            PrimaryButton(action: onPrimary) {
                Text(primaryTitle)
            }
            .disabled(isSaving)

            if let secondaryTitle, let onSecondary {
                Button(secondaryTitle, action: onSecondary)
                    .disabled(isSaving)
            }

            if showsSkip {
                Button("Überspringen", action: onSkip)
                    .disabled(isSaving)
            }
        }
    }
}

private struct EntryReviewRow: View {
    let title: String
    let value: String
    let onEdit: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Spacer(minLength: 12)

            Button("Bearbeiten", action: onEdit)
                .font(.subheadline.weight(.semibold))
        }
    }
}

private extension EntryFlowStep {
    var catalogID: NewEntryStepID {
        switch self {
        case .headache:
            .headache
        case .medication:
            .medication
        case .triggers:
            .triggers
        case .note:
            .note
        case .review:
            .review
        }
    }
}
