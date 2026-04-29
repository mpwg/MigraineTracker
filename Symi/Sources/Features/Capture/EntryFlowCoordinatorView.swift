import SwiftUI

struct EntryFlowCoordinatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var coordinator: EntryFlowCoordinator

    private let onSaved: (() -> Void)?

    init(
        dependencies: CaptureFeatureDependencies,
        initialStartedAt: Date? = nil,
        onSaved: (() -> Void)? = nil
    ) {
        self.onSaved = onSaved
        _coordinator = State(
            initialValue: dependencies.makeEntryFlowCoordinator(initialStartedAt)
        )
    }

    var body: some View {
        @Bindable var coordinator = coordinator

        NavigationStack(path: $coordinator.path) {
            EntryHeadacheStepView(
                coordinator: coordinator,
                onBack: cancel,
                onCancel: cancel
            )
            .navigationDestination(for: EntryFlowStep.self) { step in
                destination(for: step)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .tint(AppTheme.symiPetrol)
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
            EntryHeadacheStepView(
                coordinator: coordinator,
                onBack: cancel,
                onCancel: cancel
            )
        case .medication:
            EntryMedicationStepView(
                coordinator: coordinator,
                onBack: goBack,
                onCancel: cancel
            )
        case .triggers:
            EntryTriggersStepView(
                coordinator: coordinator,
                onBack: goBack,
                onCancel: cancel
            )
        case .note:
            EntryNoteStepView(
                coordinator: coordinator,
                onBack: goBack,
                onCancel: cancel
            )
        case .review:
            EntryReviewStepView(
                coordinator: coordinator,
                onBack: goBack,
                onCancel: cancel
            )
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

    private func goBack() {
        if coordinator.path.isEmpty {
            cancel()
        } else {
            coordinator.path.removeLast()
        }
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
    let onBack: () -> Void
    let onCancel: () -> Void

    @State private var selectedDayPartPreset: EntryDayPartPreset = EntryDayPartPreset(dayPart: EpisodeDayPart(date: .now))
    private let visiblePainLocations: [EntryPainLocationOption] = [
        .init(title: EntryFlowLocalized.text(de: "Stirn", en: "Forehead"), imageName: "PainLocationForehead"),
        .init(title: EntryFlowLocalized.text(de: "Schläfen", en: "Temples"), imageName: "PainLocationTemples"),
        // .init(title: "Nacken", imageName: "PainLocationNeck"),
        .init(title: EntryFlowLocalized.text(de: "Einseitig", en: "One side"), imageName: "PainLocationLeftTemple"),
        .init(title: EntryFlowLocalized.text(de: "Überall", en: "All over"), imageName: "PainLocationCrown")
    ]

    var body: some View {
        @Bindable var coordinator = coordinator

        EntryFlowScreen(
            step: .headache,
            currentIndex: coordinator.currentStepIndex,
            onBack: onBack,
            onCancel: onCancel
        ) {
            PainGaugeView(value: $coordinator.draft.intensity)

            InputFlowFieldGroup(title: EntryFlowLocalized.text(de: "Wo spürst du den Schmerz?", en: "Where do you feel the pain?")) {
                InputFlowHeadacheOptionGrid {
                    ForEach(visiblePainLocations) { location in
                        PainLocationSelectionTile(
                            option: location,
                            isSelected: coordinator.draft.selectedPainLocations.contains(location.title),
                            theme: .pain,
                            accessibilityIdentifier: "entry-location-\(location.title)"
                        ) {
                            coordinator.draft.selectedPainLocations.toggleMembership(location.title)
                        }
                    }
                }
            }

            InputFlowFieldGroup(title: EntryFlowLocalized.text(de: "Tagesbereich", en: "Time of day")) {
                InputFlowHeadacheOptionGrid {
                    ForEach(EntryDayPartPreset.allCases) { preset in
                        InputFlowSelectionTile(
                            title: preset.title,
                            systemImage: preset.symbolName,
                            isSelected: selectedDayPartPreset == preset,
                            theme: .pain,
                            accessibilityIdentifier: "entry-daypart-\(preset.rawValue)"
                        ) {
                            selectedDayPartPreset = preset
                            coordinator.selectDayPartPreset(preset)
                        }
                    }
                }
            }
        } footer: {
            EntryFlowFooter(
                isSaving: coordinator.isSaving,
                primaryTitle: EntryFlowLocalized.text(de: "Weiter", en: "Continue"),
                primarySystemImage: "arrow.right",
                primaryIdentifier: "entry-flow-next",
                secondaryTitle: EntryFlowLocalized.text(de: "Nur Kopfschmerz speichern", en: "Save headache only"),
                secondaryIdentifier: "entry-flow-save-headache-only",
                onPrimary: coordinator.continueToNextStep,
                onSecondary: coordinator.saveHeadacheOnly
            )
        }
        .onAppear {
            coordinator.draft.type = .headache
            coordinator.draft.intensity = coordinator.draft.normalizedIntensity
            selectedDayPartPreset = EntryDayPartPreset(dayPart: EpisodeDayPart(date: coordinator.draft.startedAt))
            seedDefaultPainLocationIfNeeded(coordinator: coordinator)
        }
    }

    private func seedDefaultPainLocationIfNeeded(coordinator: EntryFlowCoordinator) {
        guard !coordinator.hasSeededDefaultPainLocation else {
            return
        }

        coordinator.hasSeededDefaultPainLocation = true
        guard coordinator.draft.selectedPainLocations.isEmpty,
              coordinator.draft.painLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        coordinator.draft.selectedPainLocations = [EntryFlowLocalized.text(de: "Schläfen", en: "Temples")]
    }
}

private extension EntryDayPartPreset {
    init(dayPart: EpisodeDayPart) {
        switch dayPart {
        case .morgens:
            self = .morgens
        case .mittags:
            self = .mittags
        case .abends:
            self = .abends
        case .nacht:
            self = .nacht
        }
    }
}

private struct EntryPainLocationOption: Identifiable, Hashable {
    let title: String
    let imageName: String

    var id: String { title }
}

private struct PainLocationSelectionTile: View {
    @Environment(\.colorScheme) private var colorScheme

    let option: EntryPainLocationOption
    let isSelected: Bool
    let theme: InputFlowStepTheme
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: SymiSpacing.xs) {
                Image(option.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: SymiSize.headacheLocationImageHeight)
                    .accessibilityHidden(true)

                Text(option.title)
                    .font(SymiTypography.flowTileLabel)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.symiTextPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(SymiTypography.compactScaleFactor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, SymiSpacing.xs)
            .padding(.vertical, SymiSpacing.xs)
            .frame(maxWidth: .infinity, minHeight: SymiSize.headacheLocationTileMinHeight)
            .background(tileBackground, in: RoundedRectangle(cornerRadius: SymiRadius.flowTile, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SymiRadius.flowTile, style: .continuous)
                    .stroke(borderColor, lineWidth: isSelected ? SymiStroke.selectedHairline : SymiStroke.hairline)
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(theme.accent(for: colorScheme))
                        .background(SymiColors.elevatedCard(for: colorScheme), in: Circle())
                        .padding(.top, SymiSpacing.sm)
                        .padding(.trailing, SymiSpacing.sm)
                        .accessibilityHidden(true)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityValue(isSelected ? EntryFlowLocalized.text(de: "Ausgewählt", en: "Selected") : EntryFlowLocalized.text(de: "Nicht ausgewählt", en: "Not selected"))
        .accessibilityHint(isSelected ? EntryFlowLocalized.text(de: "Entfernt die Auswahl.", en: "Removes the selection.") : EntryFlowLocalized.text(de: "Wählt diese Option aus.", en: "Selects this option."))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var tileBackground: Color {
        isSelected ? theme.selectedFill(for: colorScheme) : SymiColors.elevatedCard(for: colorScheme)
    }

    private var borderColor: Color {
        if isSelected {
            return theme.border(for: colorScheme).opacity(SymiOpacity.selectedStroke)
        }

        return SymiColors.subtleSeparator(for: colorScheme).opacity(SymiOpacity.strongSurface)
    }
}

private struct EntryMedicationStepView: View {
    let coordinator: EntryFlowCoordinator
    let onBack: () -> Void
    let onCancel: () -> Void

    @State private var selectedDosage = "400 mg"
    @State private var selectedTakenAt = EntryFlowLocalized.text(de: "Jetzt", en: "Now")

    private let medicationOptions: [EntryMedicationOption] = [
        EntryMedicationOption(title: "Ibuprofen", symbolName: "pills", category: .nsar, defaultDosage: "400 mg"),
        EntryMedicationOption(title: "Triptan", symbolName: "capsule", category: .triptan, defaultDosage: ""),
        EntryMedicationOption(title: "Paracetamol", symbolName: "syringe", category: .paracetamol, defaultDosage: "500 mg"),
        EntryMedicationOption(title: EntryFlowLocalized.text(de: "Andere", en: "Other"), symbolName: "ellipsis", category: .other, defaultDosage: "")
    ]
    private let dosageOptions = ["200 mg", "400 mg", "600 mg", EntryFlowLocalized.text(de: "Andere", en: "Other")]
    private let takenAtOptions = [
        EntryFlowLocalized.text(de: "Jetzt", en: "Now"),
        EntryFlowLocalized.text(de: "Vor 1 Std.", en: "1 hr ago"),
        EntryFlowLocalized.text(de: "Vor 2 Std.", en: "2 hrs ago"),
        EntryFlowLocalized.text(de: "Anderer Zeitpunkt", en: "Different time")
    ]

    var body: some View {
        @Bindable var coordinator = coordinator
        @Bindable var medicationController = coordinator.medicationController

        EntryFlowScreen(
            step: .medication,
            currentIndex: coordinator.currentStepIndex,
            onBack: onBack,
            onCancel: onCancel
        ) {
            InputFlowFieldGroup(title: EntryFlowLocalized.text(de: "Welche Medikation?", en: "Which medication?")) {
                VStack(spacing: SymiSpacing.tileSpacing) {
                    InputFlowTileGrid(minimumColumnWidth: SymiSize.flowTwoColumnTileGridMinWidth) {
                        ForEach(medicationOptions) { option in
                            InputFlowSelectionTile(
                                title: option.title,
                                systemImage: option.symbolName,
                                isSelected: medicationController.isMedicationNameSelected(option.title),
                                theme: .medication,
                                accessibilityIdentifier: "entry-medication-\(option.title)"
                            ) {
                                selectMedication(option, controller: medicationController)
                            }
                        }
                    }

                    InputFlowSelectionTile(
                        title: coordinator.draft.continuousMedicationChecks.isEmpty
                            ? EntryFlowLocalized.text(de: "Keine Medikation", en: "No medication")
                            : EntryFlowLocalized.text(de: "Keine weitere Medikation", en: "No more medication"),
                        systemImage: "slash.circle",
                        isSelected: medicationController.selectedMedications.isEmpty,
                        theme: .medication,
                        accessibilityIdentifier: "entry-medication-none"
                    ) {
                        medicationController.resetSelections()
                    }
                }
            }

            InputFlowFieldGroup(title: EntryFlowLocalized.text(de: "Dosierung", en: "Dosage")) {
                InputFlowPillGrid {
                    ForEach(dosageOptions, id: \.self) { dosage in
                        InputFlowPillOption(
                            title: dosage,
                            isSelected: selectedDosage == dosage,
                            theme: .medication,
                            accessibilityIdentifier: "entry-dosage-\(dosage)"
                        ) {
                            selectedDosage = dosage
                        }
                    }
                }
            }

            InputFlowFieldGroup(title: EntryFlowLocalized.text(de: "Wann hast du es eingenommen?", en: "When did you take it?")) {
                InputFlowPillGrid {
                    ForEach(takenAtOptions, id: \.self) { option in
                        InputFlowPillOption(
                            title: option,
                            isSelected: selectedTakenAt == option,
                            theme: .medication,
                            accessibilityIdentifier: "entry-medication-time-\(option)"
                        ) {
                            selectedTakenAt = option
                        }
                    }
                }
            }

            if !coordinator.draft.continuousMedicationChecks.isEmpty {
                EntryContinuousMedicationBlock(checks: $coordinator.draft.continuousMedicationChecks)
            }
        } footer: {
            EntryFlowFooter(
                isSaving: coordinator.isSaving,
                primaryTitle: EntryFlowLocalized.text(de: "Weiter", en: "Continue"),
                primarySystemImage: "arrow.right",
                primaryIdentifier: "entry-flow-next",
                secondaryTitle: EntryFlowLocalized.text(de: "Überspringen", en: "Skip"),
                secondaryIdentifier: "entry-flow-skip",
                onPrimary: coordinator.continueToNextStep,
                onSecondary: coordinator.skipCurrentStep
            )
        }
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

    private func selectMedication(_ option: EntryMedicationOption, controller: EpisodeMedicationSelectionController) {
        if option.title == EntryFlowLocalized.text(de: "Andere", en: "Other") {
            controller.presentEditor(for: nil)
            return
        }

        let dosage = selectedDosage == EntryFlowLocalized.text(de: "Andere", en: "Other") ? option.defaultDosage : selectedDosage
        controller.toggleMedicationSelection(
            named: option.title,
            fallbackCategory: option.category,
            fallbackDosage: dosage
        )
    }
}

private struct EntryTriggersStepView: View {
    let coordinator: EntryFlowCoordinator
    let onBack: () -> Void
    let onCancel: () -> Void

    private let triggerOptions: [EntryTriggerOption] = [
        EntryTriggerOption(title: "Stress", symbolName: "brain.head.profile"),
        EntryTriggerOption(title: EntryFlowLocalized.text(de: "Wetter", en: "Weather"), symbolName: "cloud.sun"),
        EntryTriggerOption(title: EntryFlowLocalized.text(de: "Schlaf", en: "Sleep"), symbolName: "moon"),
        EntryTriggerOption(title: EntryFlowLocalized.text(de: "Ernährung", en: "Nutrition"), symbolName: "fork.knife.circle"),
        EntryTriggerOption(title: EntryFlowLocalized.text(de: "Bildschirmzeit", en: "Screen time"), symbolName: "ipad.landscape.and.iphone"),
        EntryTriggerOption(title: EntryFlowLocalized.text(de: "Zyklus", en: "Cycle"), symbolName: "drop"),
        EntryTriggerOption(title: EntryFlowLocalized.text(de: "Bewegung", en: "Movement"), symbolName: "figure.run"),
        EntryTriggerOption(title: EntryFlowLocalized.text(de: "Flüssigkeit", en: "Hydration"), symbolName: "waterbottle")
    ]

    var body: some View {
        @Bindable var coordinator = coordinator

        EntryFlowScreen(
            step: .triggers,
            currentIndex: coordinator.currentStepIndex,
            onBack: onBack,
            onCancel: onCancel
        ) {
            InputFlowFieldGroup(title: EntryFlowLocalized.text(de: "Wähle alle passenden aus.", en: "Select all that apply.")) {
                InputFlowTileGrid(minimumColumnWidth: SymiSize.flowTwoColumnTileGridMinWidth) {
                    ForEach(triggerOptions) { option in
                        InputFlowSelectionTile(
                            title: option.title,
                            systemImage: option.symbolName,
                            isSelected: coordinator.draft.selectedTriggers.contains(option.title),
                            theme: .trigger,
                            accessibilityIdentifier: "entry-trigger-\(option.title)"
                        ) {
                            coordinator.draft.selectedTriggers.toggleMembership(option.title)
                        }
                    }
                }
            }

            EntryInfoBanner(text: EntryFlowLocalized.text(de: "Du kannst mehrere auswählen.", en: "You can select multiple options."))
        } footer: {
            EntryFlowFooter(
                isSaving: coordinator.isSaving,
                primaryTitle: EntryFlowLocalized.text(de: "Weiter", en: "Continue"),
                primarySystemImage: "arrow.right",
                primaryIdentifier: "entry-flow-next",
                secondaryTitle: EntryFlowLocalized.text(de: "Überspringen", en: "Skip"),
                secondaryIdentifier: "entry-flow-skip",
                onPrimary: coordinator.continueToNextStep,
                onSecondary: coordinator.skipCurrentStep
            )
        }
    }
}

private struct EntryNoteStepView: View {
    let coordinator: EntryFlowCoordinator
    let onBack: () -> Void
    let onCancel: () -> Void

    @State private var addsToToday = true

    private let feelingOptions: [EntryFeelingOption] = [
        EntryFeelingOption(title: "Müde", symbolName: "moon.zzz"),
        EntryFeelingOption(title: "Ruhig", symbolName: "face.smiling"),
        EntryFeelingOption(title: "Angespannt", symbolName: "face.dashed"),
        EntryFeelingOption(title: "Besser", symbolName: "checkmark.circle")
    ]

    var body: some View {
        @Bindable var coordinator = coordinator

        EntryFlowScreen(
            step: .note,
            currentIndex: coordinator.currentStepIndex,
            onBack: onBack,
            onCancel: onCancel
        ) {
            EntryNoteCard(notes: $coordinator.draft.notes)

            InputFlowFieldGroup(title: "Wie fühlst du dich gerade?") {
                InputFlowTileGrid(minimumColumnWidth: SymiSize.flowCompactTileGridMinWidth) {
                    ForEach(feelingOptions) { option in
                        InputFlowSelectionTile(
                            title: option.title,
                            systemImage: option.symbolName,
                            isSelected: coordinator.draft.painCharacter == option.title,
                            theme: .note,
                            accessibilityIdentifier: "entry-feeling-\(option.title)"
                        ) {
                            coordinator.draft.painCharacter = coordinator.draft.painCharacter == option.title ? "" : option.title
                        }
                    }
                }
            }

            EntryTodayLinkCard(isOn: $addsToToday)
        } footer: {
            EntryFlowFooter(
                isSaving: coordinator.isSaving,
                primaryTitle: "Weiter",
                primarySystemImage: "arrow.right",
                primaryIdentifier: "entry-flow-next",
                secondaryTitle: "Ohne Notiz fortfahren",
                secondaryIdentifier: "entry-flow-skip",
                onPrimary: coordinator.continueToNextStep,
                onSecondary: coordinator.skipCurrentStep
            )
        }
    }
}

private struct EntryReviewStepView: View {
    let coordinator: EntryFlowCoordinator
    let onBack: () -> Void
    let onCancel: () -> Void

    var body: some View {
        EntryFlowScreen(
            step: .review,
            currentIndex: coordinator.currentStepIndex,
            onBack: onBack,
            onCancel: onCancel
        ) {
            VStack(spacing: SymiSpacing.md) {
                ReviewSummaryCard(
                    metadata: InputFlowStepCatalog.metadata(for: .headache),
                    lines: headacheSummary,
                    accessibilityIdentifier: "entry-review-headache",
                    onEdit: { coordinator.edit(.headache) }
                )

                if shouldShowMedicationSummary {
                    ReviewSummaryCard(
                        metadata: InputFlowStepCatalog.metadata(for: .medication),
                        lines: medicationSummary,
                        accessibilityIdentifier: "entry-review-medication",
                        onEdit: { coordinator.edit(.medication) }
                    )
                }

                if !coordinator.draft.selectedTriggers.isEmpty {
                    ReviewSummaryCard(
                        metadata: InputFlowStepCatalog.metadata(for: .triggers),
                        lines: triggerSummary,
                        accessibilityIdentifier: "entry-review-triggers",
                        onEdit: { coordinator.edit(.triggers) }
                    )
                }

                if shouldShowNoteSummary {
                    ReviewSummaryCard(
                        metadata: InputFlowStepCatalog.metadata(for: .note),
                        lines: noteSummary,
                        accessibilityIdentifier: "entry-review-note",
                        onEdit: { coordinator.edit(.note) }
                    )
                }
            }
            .accessibilityElement(children: .contain)

            EntryPatternHint()
        } footer: {
            EntryFlowFooter(
                isSaving: coordinator.isSaving,
                primaryTitle: "Eintrag speichern",
                primarySystemImage: "checkmark",
                primaryIdentifier: "entry-flow-save",
                secondaryTitle: "Bearbeiten",
                secondaryIdentifier: "entry-flow-edit",
                onPrimary: coordinator.saveFromReview,
                onSecondary: { coordinator.edit(.headache) }
            )
        }
        .task {
            await coordinator.refreshWeatherIfNeeded()
        }
    }

    private var headacheSummary: [String] {
        let draft = coordinator.draft
        return [
            "\(draft.normalizedIntensity)/10 · \(intensityLabel(for: draft.normalizedIntensity))",
            draft.resolvedPainLocation.isEmpty ? "Ort nicht angegeben" : "Ort: \(draft.resolvedPainLocation)",
            "Zeitpunkt: \(startedAtSummary(for: draft.startedAt))"
        ]
    }

    private var shouldShowMedicationSummary: Bool {
        !coordinator.medicationController.selectedMedications.isEmpty ||
            !coordinator.draft.continuousMedicationChecks.isEmpty
    }

    private var medicationSummary: [String] {
        let selected = coordinator.medicationController.selectedMedications
        let continuous = coordinator.draft.continuousMedicationChecks

        let continuousSummary = continuous.map {
            let detail = $0.detailText.isEmpty ? "" : " · \($0.detailText)"
            return "\($0.name)\(detail): \($0.wasTaken ? "genommen" : "nicht genommen")"
        }
        let acuteSummary = selected.map { medication in
            var parts = [medication.name]
            if !medication.dosage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                parts.append(medication.dosage)
            }
            if medication.quantity > 1 {
                parts.append("x\(medication.quantity)")
            }
            parts.append("Jetzt")
            return parts.joined(separator: " · ")
        }

        return continuousSummary + acuteSummary
    }

    private var triggerSummary: [String] {
        [coordinator.draft.selectedTriggers.sorted().joined(separator: ", ")]
    }

    private var shouldShowNoteSummary: Bool {
        !noteSummary.isEmpty
    }

    private var noteSummary: [String] {
        let draft = coordinator.draft
        var lines: [String] = []
        let notes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let feeling = draft.painCharacter.trimmingCharacters(in: .whitespacesAndNewlines)
        let impact = draft.functionalImpact.trimmingCharacters(in: .whitespacesAndNewlines)

        if !notes.isEmpty {
            lines.append(notes)
        }
        if !impact.isEmpty {
            lines.append(impact)
        }
        if !feeling.isEmpty {
            lines.append("Gefühl: \(feeling)")
        }
        if draft.menstruationStatus != .unknown {
            lines.append("Zyklusstatus aus der App: \(draft.menstruationStatus.displayName)")
        }

        return lines
    }

    private func startedAtSummary(for startedAt: Date) -> String {
        let interval = abs(startedAt.timeIntervalSinceNow)
        if interval < 10 * 60 {
            return "Jetzt"
        }

        return startedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private func intensityLabel(for intensity: Int) -> String {
        PainIntensityLevel(intensity: intensity).displayLabel
    }
}

private struct EntryFlowScreen<Content: View, Footer: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let step: EntryFlowStep
    let currentIndex: Int
    let onBack: () -> Void
    let onCancel: () -> Void
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer

    init(
        step: EntryFlowStep,
        currentIndex: Int,
        onBack: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.step = step
        self.currentIndex = currentIndex
        self.onBack = onBack
        self.onCancel = onCancel
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        ZStack {
            InputFlowBackground()
                .ignoresSafeArea()

            VStack(spacing: SymiSpacing.zero) {
                InputFlowHeader(
                    step: step.inputFlowStepID,
                    currentStep: currentIndex,
                    totalSteps: EntryFlowCoordinator.steps.count,
                    onBack: onBack,
                    onCancel: onCancel
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: SymiSpacing.flowSectionSpacing) {
                        Text(step.rawValue)
                            .font(.caption2)
                            .foregroundStyle(.clear)
                            .frame(width: SymiSize.accessibilityMarker, height: SymiSize.accessibilityMarker)
                            .accessibilityElement()
                            .accessibilityLabel("Flow-Schritt \(step.rawValue)")
                            .accessibilityIdentifier("entry-flow-step-\(step.rawValue)")

                        content
                    }
                    .padding(.horizontal, SymiSpacing.flowHorizontalPadding)
                    .padding(.top, SymiSpacing.zero)
                    .padding(.bottom, SymiSpacing.xxl)
                    .frame(maxWidth: SymiSpacing.flowMaxContentWidth, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .safeAreaInset(edge: .bottom) {
            footer
                .padding(.horizontal, SymiSpacing.flowHorizontalPadding)
                .padding(.top, SymiSpacing.flowFooterTopPadding)
                .padding(.bottom, SymiSpacing.flowFooterBottomPadding)
                .frame(maxWidth: SymiSpacing.flowMaxContentWidth)
                .frame(maxWidth: .infinity)
                .background(InputFlowBackground().opacity(SymiOpacity.footerBackground).ignoresSafeArea())
        }
        .navigationBarBackButtonHidden(true)
    }
}

private struct EntryContinuousMedicationBlock: View {
    @Binding var checks: [ContinuousMedicationCheckDraft]

    var body: some View {
        InputFlowFieldGroup(title: "Dauermedikation") {
            VStack(spacing: SymiSpacing.sm) {
                ForEach($checks) { $check in
                    Toggle(isOn: $check.wasTaken) {
                        VStack(alignment: .leading, spacing: SymiSpacing.chevronTopPadding) {
                            Text(check.name)
                                .font(.subheadline.weight(.semibold))
                            if !check.detailText.isEmpty {
                                Text(check.detailText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .toggleStyle(.switch)
                    .frame(minHeight: SymiSize.minInteractiveHeight)
                    .accessibilityLabel("\(check.name) heute genommen")
                }
            }
        }
    }
}

private struct EntryInfoBanner: View {
    @Environment(\.colorScheme) private var colorScheme

    let text: String

    var body: some View {
        Label(text, systemImage: "info.circle")
            .font(.footnote.weight(.medium))
            .foregroundStyle(NewEntryStepColorToken.blue.color)
            .padding(.horizontal, SymiSpacing.lg)
            .padding(.vertical, SymiSpacing.secondaryButtonVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                NewEntryStepColorToken.blue.softFill(for: colorScheme),
                in: RoundedRectangle(cornerRadius: SymiRadius.flowTile, style: .continuous)
            )
            .accessibilityIdentifier("entry-trigger-info")
    }
}

private struct EntryNoteCard: View {
    @Binding var notes: String

    private let limit = 500

    var body: some View {
        InputFlowCard(theme: .note, isHighlighted: true) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $notes)
                    .font(.callout)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, SymiSpacing.xxs)
                    .padding(.vertical, SymiSpacing.xxs)
                    .frame(minHeight: SymiSize.noteEditorMinHeight)
                    .onChange(of: notes) { _, newValue in
                        if newValue.count > limit {
                            notes = String(newValue.prefix(limit))
                        }
                    }
                    .accessibilityLabel("Notiz")
                    .accessibilityIdentifier("entry-note-text")

                if notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: SymiSpacing.sm) {
                        Text("Was hat geholfen?")
                        Text("Was war heute anders?")
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, SymiSpacing.sm)
                    .padding(.vertical, SymiSpacing.sm)
                    .allowsHitTesting(false)
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("\(notes.count)/\(limit)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .padding(SymiSpacing.xs)
                    }
                }
            }
        }
    }
}

private struct EntryTodayLinkCard: View {
    @Binding var isOn: Bool

    var body: some View {
        InputFlowCard(theme: .note) {
            HStack(spacing: SymiSpacing.secondaryButtonVerticalPadding) {
                VStack(alignment: .leading, spacing: SymiSpacing.compact) {
                    Text("Zu heutigem Eintrag hinzufügen")
                        .font(.subheadline.weight(.semibold))
                    Text("Diese Notiz wird mit deinem Eintrag von heute verknüpft.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: SymiSpacing.xs)

                Toggle("Zu heutigem Eintrag hinzufügen", isOn: $isOn)
                    .labelsHidden()
                    .tint(InputFlowStepTheme.note.accent)
                    .accessibilityIdentifier("entry-note-link-toggle")
            }
            .frame(maxWidth: .infinity, minHeight: SymiSize.medicationRowMinHeight, alignment: .leading)
        }
    }
}

private struct EntryFlowFooter: View {
    let isSaving: Bool
    let primaryTitle: String
    let primarySystemImage: String
    let primaryIdentifier: String
    let secondaryTitle: String?
    let secondaryIdentifier: String?
    let onPrimary: () -> Void
    let onSecondary: (() -> Void)?

    init(
        isSaving: Bool,
        primaryTitle: String,
        primarySystemImage: String,
        primaryIdentifier: String,
        secondaryTitle: String? = nil,
        secondaryIdentifier: String? = nil,
        onPrimary: @escaping () -> Void,
        onSecondary: (() -> Void)? = nil
    ) {
        self.isSaving = isSaving
        self.primaryTitle = primaryTitle
        self.primarySystemImage = primarySystemImage
        self.primaryIdentifier = primaryIdentifier
        self.secondaryTitle = secondaryTitle
        self.secondaryIdentifier = secondaryIdentifier
        self.onPrimary = onPrimary
        self.onSecondary = onSecondary
    }

    var body: some View {
        VStack(spacing: SymiSpacing.zero) {
            InputFlowPrimaryButton(
                title: primaryTitle,
                systemImage: primarySystemImage,
                isLoading: isSaving,
                isDisabled: isSaving,
                accessibilityIdentifier: primaryIdentifier,
                action: onPrimary
            )

            if let secondaryTitle, let onSecondary {
                InputFlowSecondaryAction(
                    title: secondaryTitle,
                    isDisabled: isSaving,
                    accessibilityIdentifier: secondaryIdentifier ?? "entry-flow-secondary",
                    action: onSecondary
                )
            }
        }
    }
}

private struct EntryPatternHint: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Label {
            Text("Dein Eintrag hilft dir, Muster besser zu erkennen.")
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "sparkles")
                .foregroundStyle(NewEntryStepColorToken.purple.color)
        }
        .padding(SymiSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            NewEntryStepColorToken.purple.softFill(for: colorScheme),
            in: RoundedRectangle(cornerRadius: SymiRadius.flowBanner, style: .continuous)
        )
        .accessibilityIdentifier("entry-review-pattern-hint")
    }
}

private struct EntryMedicationOption: Identifiable {
    let title: String
    let symbolName: String
    let category: MedicationCategory
    let defaultDosage: String

    var id: String { title }
}

private struct EntryTriggerOption: Identifiable {
    let title: String
    let symbolName: String

    var id: String { title }
}

private struct EntryFeelingOption: Identifiable {
    let title: String
    let symbolName: String

    var id: String { title }
}
