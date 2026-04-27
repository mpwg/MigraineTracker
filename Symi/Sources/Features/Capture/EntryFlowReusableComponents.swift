import SwiftUI

struct SectionCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let theme: InputFlowStepTheme
    let content: Content

    init(
        _ title: String,
        subtitle: String? = nil,
        theme: InputFlowStepTheme,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.theme = theme
        self.content = content()
    }

    var body: some View {
        InputFlowCard(theme: theme) {
            VStack(alignment: .leading, spacing: SymiSpacing.lg) {
                VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
                    Text(title)
                        .font(SymiTypography.flowSectionTitle)
                        .foregroundStyle(AppTheme.symiTextPrimary)

                    if let subtitle {
                        Text(subtitle)
                            .font(SymiTypography.caption)
                            .foregroundStyle(AppTheme.symiTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                content
            }
        }
    }
}

struct StickyBottomBar<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, SymiSpacing.flowHorizontalPadding)
            .padding(.top, SymiSpacing.flowFooterTopPadding)
            .padding(.bottom, SymiSpacing.flowFooterBottomPadding)
            .frame(maxWidth: SymiSpacing.flowMaxContentWidth)
            .frame(maxWidth: .infinity)
            .background(InputFlowBackground().opacity(SymiOpacity.footerBackground).ignoresSafeArea())
    }
}

struct IntensitySelectorView: View {
    @Binding var value: Int

    var body: some View {
        PainGaugeView(value: $value)
    }
}

struct SymptomCardGrid: View {
    let options: [String]
    @Binding var selection: Set<String>

    private let theme = InputFlowStepTheme.pain

    var body: some View {
        InputFlowTileGrid(minimumColumnWidth: SymiSize.flowCompactTileGridMinWidth) {
            ForEach(options, id: \.self) { option in
                InputFlowSelectionTile(
                    title: option,
                    systemImage: symbolName(for: option),
                    isSelected: selection.contains(option),
                    theme: theme,
                    accessibilityIdentifier: "entry-symptom-\(option)"
                ) {
                    toggle(option)
                }
            }
        }
    }

    private func toggle(_ option: String) {
        if selection.contains(option) {
            selection.remove(option)
        } else {
            selection.insert(option)
        }
    }

    private func symbolName(for option: String) -> String {
        switch option {
        case "Übelkeit":
            "stomach"
        case "Lichtempfindlichkeit":
            "sun.max"
        case "Geräuschempfindlichkeit":
            "speaker.wave.3"
        case "Aura":
            "sparkles"
        case "Kiefer-/Aufbissschmerz":
            "face.dashed"
        case "Pochen, Pulsieren":
            "waveform.path.ecg"
        default:
            "circle.grid.2x2"
        }
    }
}

struct PainLocationSelectorView: View {
    @Binding var selection: Set<String>

    private let theme = InputFlowStepTheme.pain
    private let options: [PainLocationOption] = [
        .init(title: "Stirn", imageName: "PainLocationForehead"),
        .init(title: "Schläfen", imageName: "PainLocationTemples"),
        .init(title: "Einseitig", imageName: "PainLocationLeftTemple"),
        .init(title: "Überall", imageName: "PainLocationCrown")
    ]

    var body: some View {
        HeadacheLocationGrid {
            ForEach(options) { option in
                PainLocationCard(
                    option: option,
                    isSelected: selection.contains(option.title),
                    theme: theme
                ) {
                    toggle(option.title)
                }
            }
        }
    }

    private func toggle(_ option: String) {
        if selection.contains(option) {
            selection.remove(option)
        } else {
            selection.insert(option)
        }
    }
}

struct DayPartInlineSelectorView: View {
    @Binding var startedAt: Date
    @State private var detailsExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.lg) {
            HeadacheDayPartGrid {
                ForEach(EntryDayPartPreset.allCases) { preset in
                    InputFlowSelectionTile(
                        title: preset.title,
                        systemImage: preset.symbolName,
                        isSelected: EntryDayPartPreset(dayPart: EpisodeDayPart(date: startedAt)) == preset,
                        theme: .pain,
                        accessibilityIdentifier: "entry-daypart-\(preset.rawValue)"
                    ) {
                        startedAt = preset.date(on: startedAt)
                    }
                }
            }

            DisclosureGroup(isExpanded: $detailsExpanded.animation(.snappy)) {
                DatePicker(
                    "Exakter Zeitpunkt",
                    selection: $startedAt,
                    in: ...Date.now,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .padding(.top, SymiSpacing.sm)
            } label: {
                Text("Exakten Zeitpunkt anpassen")
                    .font(SymiTypography.flowPillLabel)
                    .foregroundStyle(AppTheme.symiPetrol)
            }
        }
    }
}

struct TriggerSelectionGrid: View {
    let options: [String]
    @Binding var selection: Set<String>

    private let theme = InputFlowStepTheme.trigger

    var body: some View {
        InputFlowTileGrid(minimumColumnWidth: SymiSize.flowTwoColumnTileGridMinWidth) {
            ForEach(options, id: \.self) { option in
                InputFlowSelectionTile(
                    title: option,
                    systemImage: symbolName(for: option),
                    isSelected: selection.contains(option),
                    theme: theme,
                    accessibilityIdentifier: "entry-trigger-\(option)"
                ) {
                    toggle(option)
                }
            }
        }
    }

    private func toggle(_ option: String) {
        if selection.contains(option) {
            selection.remove(option)
        } else {
            selection.insert(option)
        }
    }

    private func symbolName(for option: String) -> String {
        switch option {
        case "Stress", "Erhöhte Arbeitsbelastung":
            "brain.head.profile"
        case "Wetter":
            "cloud.sun"
        case "Schlaf", "Schlafdauer":
            "moon"
        case "Ernährung":
            "fork.knife.circle"
        case "Bildschirmzeit":
            "ipad.landscape.and.iphone"
        case "Regel", "Zyklus":
            "drop"
        case "Sport", "Bewegung":
            "figure.run"
        case "Flüssigkeit":
            "waterbottle"
        default:
            "sparkles"
        }
    }
}

struct MedicationFlowInlineView: View {
    let controller: EpisodeMedicationSelectionController

    @State private var selectedDosage = "400 mg"
    @State private var selectedTakenAt = "Jetzt"

    private let medicationOptions: [MedicationFlowOption] = [
        MedicationFlowOption(title: "Ibuprofen", symbolName: "pills", category: .nsar, defaultDosage: "400 mg"),
        MedicationFlowOption(title: "Triptan", symbolName: "capsule", category: .triptan, defaultDosage: ""),
        MedicationFlowOption(title: "Paracetamol", symbolName: "syringe", category: .paracetamol, defaultDosage: "500 mg"),
        MedicationFlowOption(title: "Andere", symbolName: "ellipsis", category: .other, defaultDosage: "")
    ]
    private let dosageOptions = ["200 mg", "400 mg", "500 mg", "600 mg", "Andere"]
    private let takenAtOptions = ["Jetzt", "Vor 1 Std.", "Vor 2 Std.", "Anderer Zeitpunkt"]

    var body: some View {
        @Bindable var controller = controller

        VStack(alignment: .leading, spacing: SymiSpacing.lg) {
            InputFlowTileGrid(minimumColumnWidth: SymiSize.flowTwoColumnTileGridMinWidth) {
                ForEach(medicationOptions) { option in
                    InputFlowSelectionTile(
                        title: option.title,
                        systemImage: option.symbolName,
                        isSelected: controller.isMedicationNameSelected(option.title),
                        theme: .medication,
                        accessibilityIdentifier: "entry-medication-\(option.title)"
                    ) {
                        selectMedication(option, controller: controller)
                    }
                }
            }

            InputFlowSelectionTile(
                title: controller.selectedMedications.isEmpty ? "Keine Medikation" : "Keine weitere Medikation",
                systemImage: "slash.circle",
                isSelected: controller.selectedMedications.isEmpty,
                theme: .medication,
                accessibilityIdentifier: "entry-medication-none"
            ) {
                controller.resetSelections()
            }

            if !controller.selectedMedications.isEmpty {
                VStack(alignment: .leading, spacing: SymiSpacing.md) {
                    InputFlowFieldGroup(title: "Dosierung") {
                        InputFlowPillGrid {
                            ForEach(dosageOptions, id: \.self) { dosage in
                                InputFlowPillOption(
                                    title: dosage,
                                    isSelected: selectedDosage == dosage,
                                    theme: .medication,
                                    accessibilityIdentifier: "entry-dosage-\(dosage)"
                                ) {
                                    selectedDosage = dosage
                                    controller.updateDosageForSelectedMedications(dosage == "Andere" ? "" : dosage)
                                }
                            }
                        }
                    }

                    InputFlowFieldGroup(title: "Einnahme") {
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

                    SelectedMedicationsSection(controller: controller)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear {
            if let dosage = controller.selectedMedications.first?.dosage, !dosage.isEmpty {
                selectedDosage = dosageOptions.contains(dosage) ? dosage : "Andere"
            }
        }
    }

    private func selectMedication(_ option: MedicationFlowOption, controller: EpisodeMedicationSelectionController) {
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

struct EntryNoteCard: View {
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

struct HeadacheLocationGrid<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(
                    .flexible(minimum: SymiSize.headacheOptionGridMinWidth),
                    spacing: SymiSpacing.xs,
                    alignment: .top
                ),
                count: SymiSize.headacheOptionGridColumnCount
            ),
            alignment: .leading,
            spacing: SymiSpacing.xs
        ) {
            content
        }
    }
}

struct HeadacheDayPartGrid<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(
                    .flexible(minimum: SymiSize.headacheOptionGridMinWidth),
                    spacing: SymiSpacing.xs,
                    alignment: .top
                ),
                count: SymiSize.headacheOptionGridColumnCount
            ),
            alignment: .leading,
            spacing: SymiSpacing.xs
        ) {
            content
        }
    }
}

private struct PainLocationOption: Identifiable, Hashable {
    let title: String
    let imageName: String

    var id: String { title }
}

private struct PainLocationCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let option: PainLocationOption
    let isSelected: Bool
    let theme: InputFlowStepTheme
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
        .accessibilityValue(isSelected ? "Ausgewählt" : "Nicht ausgewählt")
        .accessibilityHint(isSelected ? "Entfernt die Auswahl." : "Wählt diese Option aus.")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("entry-location-\(option.title)")
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

private struct MedicationFlowOption: Identifiable {
    let title: String
    let symbolName: String
    let category: MedicationCategory
    let defaultDosage: String

    var id: String { title }
}

extension EntryDayPartPreset {
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
