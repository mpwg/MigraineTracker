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
        @Bindable var medicationController = controller.medicationController
        let accent = intensityAccent(Double(controller.draft.normalizedIntensity))

        ZStack {
            InputFlowBackground()
                .ignoresSafeArea()

            ScrollViewReader { proxy in
                VStack(spacing: SymiSpacing.zero) {
                    EditEntryHeader(
                        subtitle: "\(controller.draft.type.rawValue) · \(controller.draft.normalizedIntensity)/10",
                        showsDismissButton: showsDismissButton,
                        accent: accent,
                        onNavigate: { target in
                            withAnimation(.snappy) {
                                proxy.scrollTo(target, anchor: .top)
                            }
                        },
                        onDismiss: { dismiss() }
                    )

                    ScrollView {
                        VStack(alignment: .leading, spacing: 26) {
                            if let validationMessage = controller.validationMessage {
                                EditValidationCard(message: validationMessage)
                            }

                            SectionCard("Intensität", theme: .pain, prominence: .dominant) {
                                IntensitySelectorView(value: $controller.draft.intensity, isCard: false)
                            }
                            .id(EditEntrySection.intensity)

                            SectionCard("Symptome", subtitle: "Was spürst du?", theme: .pain) {
                                SymptomCardGrid(
                                    options: controller.symptomOptions,
                                    selection: $controller.draft.selectedSymptoms,
                                    accent: accent
                                )
                            }
                            .id(EditEntrySection.symptoms)

                            SectionCard("Schmerzort", theme: .pain) {
                                PainLocationSelectorView(selection: $controller.draft.selectedPainLocations, accent: accent)
                            }

                            SectionCard("Tagesbereich", subtitle: "Schnellauswahl zuerst, Details bei Bedarf.", theme: .pain) {
                                DayPartInlineSelectorView(startedAt: $controller.draft.startedAt, accent: accent)
                            }

                            SectionCard("Auslöser", subtitle: "Du kannst mehrere auswählen.", theme: .trigger) {
                                TriggerSelectionGrid(
                                    options: controller.triggerOptions,
                                    selection: $controller.draft.selectedTriggers,
                                    accent: accent
                                )
                            }

                            SectionCard("Medikation", theme: .medication) {
                                MedicationFlowInlineView(controller: controller.medicationController, accent: accent)
                            }
                            .id(EditEntrySection.medication)

                            SectionCard("Notiz", theme: .note) {
                                EntryNoteCard(notes: $controller.draft.notes)
                            }

                            EditSecondaryDetailsCard(draft: $controller.draft, weatherState: controller.weatherLoadState)
                        }
                        .padding(.horizontal, SymiSpacing.flowHorizontalPadding)
                        .padding(.top, SymiSpacing.lg)
                        .padding(.bottom, 120)
                        .frame(maxWidth: SymiSpacing.flowMaxContentWidth, alignment: .leading)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            StickyBottomBar {
                InputFlowPrimaryButton(
                    title: controller.mode == .create ? "Eintrag speichern" : "Speichern",
                    systemImage: "checkmark",
                    isLoading: controller.isSaving,
                    isDisabled: controller.isSaving,
                    accessibilityIdentifier: "edit-entry-save",
                    action: save
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .tint(AppTheme.symiPetrol)
        .animation(.snappy, value: controller.draft.normalizedIntensity)
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

}

private enum EditEntrySection: Hashable {
    case intensity
    case symptoms
    case medication
}

private struct EditEntryHeader: View {
    let subtitle: String
    let showsDismissButton: Bool
    let accent: Color
    let onNavigate: (EditEntrySection) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.sm) {
            HStack(alignment: .center, spacing: SymiSpacing.md) {
                VStack(alignment: .leading, spacing: SymiSpacing.micro) {
                    Text("Eintrag bearbeiten")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.symiTextPrimary)

                    Text(subtitle)
                        .font(SymiTypography.caption)
                        .foregroundStyle(AppTheme.symiTextSecondary)
                }

                Spacer()

                if showsDismissButton {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.symiTextSecondary)
                            .frame(width: SymiSize.flowHeaderControlHeight, height: SymiSize.flowHeaderControlHeight)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityLabel("Abbrechen")
                }
            }

            ScrollView(.horizontal) {
                HStack(spacing: SymiSpacing.xs) {
                    navigationChip("Intensität", target: .intensity)
                    navigationChip("Symptome", target: .symptoms)
                    navigationChip("Medikation", target: .medication)
                }
                .padding(.horizontal, SymiSpacing.flowHorizontalPadding)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -SymiSpacing.flowHorizontalPadding)
        }
        .padding(.horizontal, SymiSpacing.flowHorizontalPadding)
        .padding(.top, SymiSpacing.sm)
        .padding(.bottom, SymiSpacing.xs)
        .frame(maxWidth: SymiSpacing.flowMaxContentWidth)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(accent.opacity(0.16))
                .frame(height: SymiStroke.hairline)
        }
    }

    private func navigationChip(_ title: String, target: EditEntrySection) -> some View {
        Button {
            onNavigate(target)
        } label: {
            Text(title)
                .font(SymiTypography.flowPillLabel)
                .foregroundStyle(accent)
                .padding(.horizontal, SymiSpacing.md)
                .padding(.vertical, SymiSpacing.compact)
                .background(accent.opacity(0.12), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(accent.opacity(0.22), lineWidth: SymiStroke.hairline)
                }
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

private struct EditValidationCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(AppTheme.symiCoral)
            .padding(SymiSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                InputFlowStepTheme.pain.selectedFill(for: colorScheme),
                in: RoundedRectangle(cornerRadius: SymiRadius.flowBanner, style: .continuous)
            )
            .accessibilityLabel("Hinweis: \(message)")
    }
}

private struct EditSecondaryDetailsCard: View {
    @Binding var draft: EpisodeDraft
    let weatherState: WeatherLoadState

    var body: some View {
        SectionCard("Weitere Details", subtitle: "Optional und eingeklappt.", theme: .note) {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: SymiSpacing.lg) {
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

                    WeatherStatusContent(state: weatherState)
                }
                .padding(.top, SymiSpacing.sm)
            } label: {
                Text("Details anzeigen")
                    .font(SymiTypography.flowPillLabel)
                    .foregroundStyle(AppTheme.symiPetrol)
            }
        }
    }
}

struct SelectedMedicationsSection: View {
    let controller: EpisodeMedicationSelectionController

    var body: some View {
        if controller.selectedMedications.isEmpty {
            Text("Nur ergänzen, wenn du heute etwas genommen hast.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: SymiSpacing.xs) {
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
            HStack(spacing: SymiSpacing.md) {
                ProgressView()
                Text("Wetter wird ermittelt …")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, SymiSpacing.xs)
        case .loaded(let weather):
            VStack(alignment: .leading, spacing: SymiSpacing.xs) {
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
            .padding(.vertical, SymiSpacing.xxs)
        case .unavailable(let message):
            VStack(alignment: .leading, spacing: SymiSpacing.md) {
                Label(message, systemImage: "location.slash")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if showsLocationSettingsHint(for: message) {
                    Text("Du kannst die Standortfreigabe in den Einstellungen dieser App unter \"Standort\" auf \"Beim Verwenden der App\" ändern.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("Einstellungen öffnen") {
                        openURL(AppSettingsURL.url)
                    }
                    .buttonStyle(SymiSecondaryButtonStyle())
                }
            }
            .padding(.vertical, SymiSpacing.xs)
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
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

private enum AppSettingsURL {
    static let url = URL(string: "app-settings:")!
}

struct CustomMedicationEditorSheet: View {
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
        HStack(spacing: SymiSpacing.md) {
            VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
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
        .padding(SymiSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.secondaryFill)
        .clipShape(RoundedRectangle(cornerRadius: SymiRadius.chip, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SymiRadius.chip, style: .continuous)
                .stroke(AppTheme.symiOnAccent.opacity(SymiOpacity.outline), lineWidth: SymiStroke.hairline)
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
