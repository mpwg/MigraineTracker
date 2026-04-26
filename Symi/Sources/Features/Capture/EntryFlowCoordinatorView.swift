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

    @State private var selectedStartedAtPreset: EntryStartedAtPreset = .now

    private let visiblePainLocations = ["Stirn", "Schläfen", "Nacken", "Einseitig"]

    var body: some View {
        @Bindable var coordinator = coordinator

        EntryFlowScreen(
            step: .headache,
            currentIndex: coordinator.currentStepIndex,
            onBack: onBack,
            onCancel: onCancel
        ) {
            HeadacheIntensityCard(intensity: $coordinator.draft.intensity)

            EntryFieldGroup(title: "Wo spürst du den Schmerz?") {
                EntryTileGrid(minimumColumnWidth: 68) {
                    ForEach(visiblePainLocations, id: \.self) { location in
                        EntryOptionTile(
                            title: location,
                            systemImage: painLocationSymbol(for: location),
                            isSelected: coordinator.draft.selectedPainLocations.contains(location),
                            colorToken: .coral,
                            accessibilityIdentifier: "entry-location-\(location)"
                        ) {
                            toggle(location, in: &coordinator.draft.selectedPainLocations)
                        }
                    }
                }
            }

            EntryFieldGroup(title: "Wann tritt es auf?") {
                EntryChipRow {
                    ForEach(EntryStartedAtPreset.allCases) { preset in
                        EntrySelectionChip(
                            title: preset.title,
                            isSelected: selectedStartedAtPreset == preset,
                            colorToken: .coral,
                            accessibilityIdentifier: "entry-started-at-\(preset.rawValue)"
                        ) {
                            selectedStartedAtPreset = preset
                            if preset != .custom {
                                coordinator.selectStartedAtPreset(preset)
                            }
                        }
                    }
                }

                if selectedStartedAtPreset == .custom {
                    DatePicker(
                        "Beginn",
                        selection: $coordinator.draft.startedAt,
                        in: ...Date.now,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .accessibilityIdentifier("entry-started-at-custom-picker")
                }
            }
        } footer: {
            EntryFlowFooter(
                isSaving: coordinator.isSaving,
                primaryTitle: "Weiter",
                primarySystemImage: "arrow.right",
                primaryIdentifier: "entry-flow-next",
                secondaryTitle: "Nur Kopfschmerz speichern",
                secondaryIdentifier: "entry-flow-save-headache-only",
                onPrimary: coordinator.continueToNextStep,
                onSecondary: coordinator.saveHeadacheOnly
            )
        }
        .onAppear {
            coordinator.draft.type = .headache
            coordinator.draft.intensity = coordinator.draft.normalizedIntensity
        }
    }

    private func painLocationSymbol(for location: String) -> String {
        switch location {
        case "Stirn":
            "head.profile"
        case "Schläfen":
            "person.crop.circle.badge.exclamationmark"
        case "Nacken":
            "person.crop.circle"
        case "Einseitig":
            "face.dashed"
        default:
            "circle"
        }
    }

    private func toggle(_ option: String, in selection: inout Set<String>) {
        if selection.contains(option) {
            selection.remove(option)
        } else {
            selection.insert(option)
        }
    }
}

private struct EntryMedicationStepView: View {
    let coordinator: EntryFlowCoordinator
    let onBack: () -> Void
    let onCancel: () -> Void

    @State private var selectedDosage = "400 mg"
    @State private var selectedTakenAt = "Jetzt"

    private let medicationOptions: [EntryMedicationOption] = [
        EntryMedicationOption(title: "Ibuprofen", symbolName: "pills", category: .nsar, defaultDosage: "400 mg"),
        EntryMedicationOption(title: "Triptan", symbolName: "capsule", category: .triptan, defaultDosage: ""),
        EntryMedicationOption(title: "Paracetamol", symbolName: "syringe", category: .paracetamol, defaultDosage: "500 mg"),
        EntryMedicationOption(title: "Andere", symbolName: "ellipsis", category: .other, defaultDosage: "")
    ]
    private let dosageOptions = ["200 mg", "400 mg", "600 mg", "Andere"]
    private let takenAtOptions = ["Jetzt", "Vor 1 Std.", "Vor 2 Std.", "Anderer Zeitpunkt"]

    var body: some View {
        @Bindable var coordinator = coordinator
        @Bindable var medicationController = coordinator.medicationController

        EntryFlowScreen(
            step: .medication,
            currentIndex: coordinator.currentStepIndex,
            onBack: onBack,
            onCancel: onCancel
        ) {
            Text("Welche Medikation?")
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)

            EntryTileGrid(minimumColumnWidth: 132) {
                ForEach(medicationOptions) { option in
                    EntryOptionTile(
                        title: option.title,
                        systemImage: option.symbolName,
                        isSelected: medicationController.isMedicationNameSelected(option.title),
                        colorToken: .sageTeal,
                        accessibilityIdentifier: "entry-medication-\(option.title)"
                    ) {
                        selectMedication(option, controller: medicationController)
                    }
                }
            }

            EntryOptionTile(
                title: coordinator.draft.continuousMedicationChecks.isEmpty ? "Keine Medikation" : "Keine weitere Medikation",
                systemImage: "slash.circle",
                isSelected: medicationController.selectedMedications.isEmpty,
                colorToken: .sageTeal,
                accessibilityIdentifier: "entry-medication-none"
            ) {
                medicationController.resetSelections()
            }

            EntryFieldGroup(title: "Dosierung") {
                EntryChipRow {
                    ForEach(dosageOptions, id: \.self) { dosage in
                        EntrySelectionChip(
                            title: dosage,
                            isSelected: selectedDosage == dosage,
                            colorToken: .sageTeal,
                            accessibilityIdentifier: "entry-dosage-\(dosage)"
                        ) {
                            selectedDosage = dosage
                        }
                    }
                }
            }

            EntryFieldGroup(title: "Wann hast du es eingenommen?") {
                EntryChipRow {
                    ForEach(takenAtOptions, id: \.self) { option in
                        EntrySelectionChip(
                            title: option,
                            isSelected: selectedTakenAt == option,
                            colorToken: .sageTeal,
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
                primaryTitle: "Weiter",
                primarySystemImage: "arrow.right",
                primaryIdentifier: "entry-flow-next",
                secondaryTitle: "Überspringen",
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
        if option.title == "Andere" {
            controller.presentEditor(for: nil)
            return
        }

        let dosage = selectedDosage == "Andere" ? option.defaultDosage : selectedDosage
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
        EntryTriggerOption(title: "Wetter", symbolName: "cloud.sun"),
        EntryTriggerOption(title: "Schlaf", symbolName: "moon"),
        EntryTriggerOption(title: "Ernährung", symbolName: "apple.logo"),
        EntryTriggerOption(title: "Bildschirmzeit", symbolName: "iphone"),
        EntryTriggerOption(title: "Zyklus", symbolName: "drop"),
        EntryTriggerOption(title: "Bewegung", symbolName: "figure.run"),
        EntryTriggerOption(title: "Flüssigkeit", symbolName: "waterbottle")
    ]

    var body: some View {
        @Bindable var coordinator = coordinator

        EntryFlowScreen(
            step: .triggers,
            currentIndex: coordinator.currentStepIndex,
            onBack: onBack,
            onCancel: onCancel
        ) {
            Text("Wähle alle passenden aus.")
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)

            EntryTileGrid(minimumColumnWidth: 132) {
                ForEach(triggerOptions) { option in
                    EntryOptionTile(
                        title: option.title,
                        systemImage: option.symbolName,
                        isSelected: coordinator.draft.selectedTriggers.contains(option.title),
                        colorToken: .blue,
                        accessibilityIdentifier: "entry-trigger-\(option.title)"
                    ) {
                        toggle(option.title, in: &coordinator.draft.selectedTriggers)
                    }
                }
            }

            EntryInfoBanner(text: "Du kannst mehrere auswählen.")
        } footer: {
            EntryFlowFooter(
                isSaving: coordinator.isSaving,
                primaryTitle: "Weiter",
                primarySystemImage: "arrow.right",
                primaryIdentifier: "entry-flow-next",
                secondaryTitle: "Überspringen",
                secondaryIdentifier: "entry-flow-skip",
                onPrimary: coordinator.continueToNextStep,
                onSecondary: coordinator.skipCurrentStep
            )
        }
    }

    private func toggle(_ option: String, in selection: inout Set<String>) {
        if selection.contains(option) {
            selection.remove(option)
        } else {
            selection.insert(option)
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

            EntryFieldGroup(title: "Wie fühlst du dich gerade?") {
                EntryTileGrid(minimumColumnWidth: 72) {
                    ForEach(feelingOptions) { option in
                        EntryMoodTile(
                            option: option,
                            isSelected: coordinator.draft.painCharacter == option.title,
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
            VStack(spacing: 0) {
                EntryReviewSummarySection(
                    step: .headache,
                    lines: headacheSummary,
                    onEdit: { coordinator.edit(.headache) }
                )

                if shouldShowMedicationSummary {
                    Divider()
                    EntryReviewSummarySection(
                        step: .medication,
                        lines: medicationSummary,
                        onEdit: { coordinator.edit(.medication) }
                    )
                }

                if !coordinator.draft.selectedTriggers.isEmpty {
                    Divider()
                    EntryReviewSummarySection(
                        step: .triggers,
                        lines: triggerSummary,
                        onEdit: { coordinator.edit(.triggers) }
                    )
                }

                if shouldShowNoteSummary {
                    Divider()
                    EntryReviewSummarySection(
                        step: .note,
                        lines: noteSummary,
                        onEdit: { coordinator.edit(.note) }
                    )
                }
            }
            .background(entryCardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
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
            lines.append("Regel: \(draft.menstruationStatus.rawValue)")
        }

        return lines
    }

    private var entryCardBackground: some ShapeStyle {
        Color(uiColor: .secondarySystemGroupedBackground)
    }

    private func startedAtSummary(for startedAt: Date) -> String {
        let interval = abs(startedAt.timeIntervalSinceNow)
        if interval < 10 * 60 {
            return "Jetzt"
        }

        return startedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private func intensityLabel(for intensity: Int) -> String {
        switch intensity {
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
            EntryFlowBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                EntryFlowTopBar(onBack: onBack, onCancel: onCancel)

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text(step.rawValue)
                            .font(.caption2)
                            .foregroundStyle(.clear)
                            .frame(width: 1, height: 1)
                            .accessibilityElement()
                            .accessibilityLabel("Flow-Schritt \(step.rawValue)")
                            .accessibilityIdentifier("entry-flow-step-\(step.rawValue)")

                        EntryStepHero(step: step, currentIndex: currentIndex)
                        content
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 420, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .safeAreaInset(edge: .bottom) {
            footer
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .frame(maxWidth: 420)
                .frame(maxWidth: .infinity)
                .background(.regularMaterial)
        }
        .navigationBarBackButtonHidden(true)
    }
}

private struct EntryFlowTopBar: View {
    let onBack: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(.thinMaterial, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    }
            }
            .accessibilityLabel("Zurück")
            .accessibilityIdentifier("entry-flow-back")

            Spacer()

            Button("Abbrechen", action: onCancel)
                .font(.callout.weight(.medium))
                .foregroundStyle(AppTheme.symiPetrol)
                .frame(minHeight: 44)
                .accessibilityIdentifier("entry-flow-cancel")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 2)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
    }
}

private struct EntryStepHero: View {
    let step: EntryFlowStep
    let currentIndex: Int

    var body: some View {
        let metadata = NewEntryStepCatalog.metadata(for: step.catalogID)

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 18) {
                EntryProgressTrack(
                    currentStep: currentIndex,
                    totalSteps: EntryFlowCoordinator.steps.count,
                    colorToken: metadata.colorToken
                )

                Text("von \(EntryFlowCoordinator.steps.count)")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Schritt \(currentIndex) von \(EntryFlowCoordinator.steps.count)")

            Text(metadata.title)
                .font(.title.weight(.bold))
                .foregroundStyle(metadata.colorToken.color)
                .fixedSize(horizontal: false, vertical: true)

            Text(metadata.subline)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct EntryProgressTrack: View {
    @Environment(\.colorScheme) private var colorScheme

    let currentStep: Int
    let totalSteps: Int
    let colorToken: NewEntryStepColorToken

    var body: some View {
        GeometryReader { proxy in
            let indicatorSize: CGFloat = 24
            let progressWidth = max(proxy.size.width - indicatorSize, 1)
            let xOffset = CGFloat(clampedCurrentStep - 1) / CGFloat(max(totalSteps - 1, 1)) * progressWidth

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.18))
                    .frame(height: 4)
                    .offset(y: 10)

                Capsule()
                    .fill(colorToken.color(for: colorScheme))
                    .frame(width: xOffset + indicatorSize / 2, height: 4)
                    .offset(y: 10)

                Text("\(clampedCurrentStep)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(width: indicatorSize, height: indicatorSize)
                    .background(colorToken.color(for: colorScheme), in: Circle())
                    .offset(x: xOffset)
            }
        }
        .frame(height: 24)
    }

    private var clampedCurrentStep: Int {
        min(max(currentStep, 1), max(totalSteps, 1))
    }
}

private struct HeadacheIntensityCard: View {
    @Environment(\.colorScheme) private var colorScheme

    @Binding var intensity: Int

    var body: some View {
        VStack(spacing: 18) {
            ZStack(alignment: .center) {
                EntryGaugeArc()
                    .stroke(
                        LinearGradient(
                            colors: [
                                NewEntryStepColorToken.sageTeal.color,
                                Color(red: 0.96, green: 0.79, blue: 0.48),
                                NewEntryStepColorToken.coral.color
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 13, lineCap: .round)
                    )
                    .frame(width: 212, height: 142)
                    .accessibilityHidden(true)

                VStack(spacing: 4) {
                    Text("\(normalizedIntensity)")
                        .font(.system(size: 58, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.symiPetrol)
                        .minimumScaleFactor(0.75)

                    Text("/10")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text(intensityLabel)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(NewEntryStepColorToken.coral.color)
                        .padding(.top, 8)
                }
                .padding(.top, 20)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 8) {
                Slider(
                    value: Binding(
                        get: { Double(normalizedIntensity) },
                        set: { intensity = Int($0) }
                    ),
                    in: 1 ... 10,
                    step: 1
                )
                .tint(NewEntryStepColorToken.coral.color)
                .accessibilityLabel("Kopfschmerzstärke \(normalizedIntensity) von 10, \(intensityLabel.lowercased())")
                .accessibilityIdentifier("entry-intensity-slider")

                HStack {
                    Text("0")
                    Spacer()
                    Text("10")
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(entryCardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(NewEntryStepColorToken.coral.border(for: colorScheme), lineWidth: 1)
        }
        .accessibilityIdentifier("entry-intensity-card")
    }

    private var entryCardBackground: some ShapeStyle {
        Color(uiColor: .secondarySystemGroupedBackground)
    }

    private var normalizedIntensity: Int {
        min(max(intensity, 1), 10)
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

private struct EntryGaugeArc: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width / 2, rect.height) - 8
        let center = CGPoint(x: rect.midX, y: rect.maxY - 8)
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(200),
            endAngle: .degrees(340),
            clockwise: false
        )
        return path
    }
}

private struct EntryFieldGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)

            content
        }
    }
}

private struct EntryTileGrid<Content: View>: View {
    let minimumColumnWidth: CGFloat
    @ViewBuilder let content: Content

    init(minimumColumnWidth: CGFloat, @ViewBuilder content: () -> Content) {
        self.minimumColumnWidth = minimumColumnWidth
        self.content = content()
    }

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: minimumColumnWidth), spacing: 10, alignment: .top)
            ],
            alignment: .leading,
            spacing: 10
        ) {
            content
        }
    }
}

private struct EntryOptionTile: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let systemImage: String
    let isSelected: Bool
    let colorToken: NewEntryStepColorToken
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(isSelected ? colorToken.color(for: colorScheme) : .secondary)
                    .frame(height: 26)

                Text(title)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 82)
            .background(tileBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? colorToken.border(for: colorScheme) : Color.primary.opacity(0.09), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Ausgewählt" : "Nicht ausgewählt")
        .accessibilityHint(isSelected ? "Entfernt die Auswahl." : "Wählt diese Option aus.")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var tileBackground: Color {
        if isSelected {
            return colorToken.selectedFill(for: colorScheme)
        }

        return Color(uiColor: .secondarySystemGroupedBackground)
    }
}

private struct EntryChipRow<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 70), spacing: 8, alignment: .top)
            ],
            alignment: .leading,
            spacing: 8
        ) {
            content
        }
    }
}

private struct EntrySelectionChip: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let isSelected: Bool
    let colorToken: NewEntryStepColorToken
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .foregroundStyle(isSelected ? colorToken.color(for: colorScheme) : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(isSelected ? colorToken.selectedFill(for: colorScheme) : Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSelected ? colorToken.border(for: colorScheme) : Color.primary.opacity(0.08), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Ausgewählt" : "Nicht ausgewählt")
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct EntryContinuousMedicationBlock: View {
    @Binding var checks: [ContinuousMedicationCheckDraft]

    var body: some View {
        EntryFieldGroup(title: "Dauermedikation") {
            VStack(spacing: 10) {
                ForEach($checks) { $check in
                    Toggle(isOn: $check.wasTaken) {
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
                    .toggleStyle(.switch)
                    .frame(minHeight: 44)
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
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NewEntryStepColorToken.blue.softFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityIdentifier("entry-trigger-info")
    }
}

private struct EntryNoteCard: View {
    @Environment(\.colorScheme) private var colorScheme

    @Binding var notes: String

    private let limit = 500

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $notes)
                .font(.callout)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(minHeight: 230)
                .onChange(of: notes) { _, newValue in
                    if newValue.count > limit {
                        notes = String(newValue.prefix(limit))
                    }
                }
                .accessibilityLabel("Notiz")
                .accessibilityIdentifier("entry-note-text")

            if notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Was hat geholfen?")
                    Text("Was war heute anders?")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .allowsHitTesting(false)
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("\(notes.count)/\(limit)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(12)
                }
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(NewEntryStepColorToken.warmAmber.border(for: colorScheme), lineWidth: 1)
        }
    }
}

private struct EntryMoodTile: View {
    @Environment(\.colorScheme) private var colorScheme

    let option: EntryFeelingOption
    let isSelected: Bool
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: option.symbolName)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(isSelected ? NewEntryStepColorToken.warmAmber.color(for: colorScheme) : .secondary)
                    .frame(height: 26)

                Text(option.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(
                isSelected ?
                    NewEntryStepColorToken.warmAmber.selectedFill(for: colorScheme) :
                    Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? NewEntryStepColorToken.warmAmber.border(for: colorScheme) : Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityValue(isSelected ? "Ausgewählt" : "Nicht ausgewählt")
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct EntryTodayLinkCard: View {
    @Environment(\.colorScheme) private var colorScheme

    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Zu heutigem Eintrag hinzufügen")
                    .font(.subheadline.weight(.semibold))
                Text("Diese Notiz wird mit deinem Eintrag von heute verknüpft.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Toggle("Zu heutigem Eintrag hinzufügen", isOn: $isOn)
                .labelsHidden()
                .tint(NewEntryStepColorToken.warmAmber.color)
                .accessibilityIdentifier("entry-note-link-toggle")
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(NewEntryStepColorToken.warmAmber.softFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        VStack(spacing: 12) {
            Button(action: onPrimary) {
                HStack(spacing: 12) {
                    Spacer(minLength: 0)

                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(primaryTitle)
                            .font(.headline.weight(.semibold))
                        Image(systemName: primarySystemImage)
                            .font(.headline.weight(.semibold))
                    }

                    Spacer(minLength: 0)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(AppTheme.symiPetrol, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
            .accessibilityIdentifier(primaryIdentifier)

            if let secondaryTitle, let onSecondary {
                Button(secondaryTitle, action: onSecondary)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(AppTheme.symiPetrol)
                    .frame(minHeight: 44)
                    .disabled(isSaving)
                    .accessibilityIdentifier(secondaryIdentifier ?? "entry-flow-secondary")
            }
        }
    }
}

private struct EntryReviewSummarySection: View {
    let step: EntryFlowStep
    let lines: [String]
    let onEdit: () -> Void

    var body: some View {
        let metadata = NewEntryStepCatalog.metadata(for: step.catalogID)

        HStack(alignment: .top, spacing: 12) {
            StepIcon(metadata)
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 7) {
                Text(metadata.title)
                    .font(.headline.weight(.semibold))

                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Tippe doppelt, um diesen Schritt zu bearbeiten.")
        .accessibilityIdentifier("entry-review-\(step.rawValue)")
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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NewEntryStepColorToken.purple.softFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityIdentifier("entry-review-pattern-hint")
    }
}

private struct EntryFlowBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var colors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.08, green: 0.09, blue: 0.10),
                Color(red: 0.06, green: 0.10, blue: 0.10),
                Color(red: 0.10, green: 0.09, blue: 0.08)
            ]
        }

        return [
            Color(red: 0.99, green: 0.98, blue: 0.96),
            Color.white,
            Color(red: 0.95, green: 0.98, blue: 0.97)
        ]
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
