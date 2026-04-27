import SwiftUI

func intensityAccent(_ value: Double) -> Color {
    let clampedValue = min(max(value, 0), 10)

    switch clampedValue {
    case 0 ... 3:
        return SymiColors.intensityLight.color
    case 4 ... 6:
        let progress = (clampedValue - 4) / 2
        return SymiColors.intensityMedium.mixed(with: SymiColors.coral, amount: progress * 0.55).color
    default:
        let progress = (clampedValue - 7) / 3
        return SymiColors.intensityStrong.mixed(with: SymiColors.coral, amount: progress * 0.35).color
    }
}

enum SectionCardProminence {
    case standard
    case dominant
}

struct SectionCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let subtitle: String?
    let theme: InputFlowStepTheme
    let prominence: SectionCardProminence
    let content: Content

    init(
        _ title: String,
        subtitle: String? = nil,
        theme: InputFlowStepTheme,
        prominence: SectionCardProminence = .standard,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.theme = theme
        self.prominence = prominence
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.zero) {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                VStack(alignment: .leading, spacing: SymiSpacing.xxs) {
                    Text(title)
                        .font(prominence == .dominant ? .headline.weight(.semibold) : SymiTypography.flowSectionTitle)
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
            .padding(sectionPadding)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(SectionCardStyle(theme: theme, prominence: prominence))
        .animation(.snappy, value: prominence == .dominant)
    }

    private var sectionPadding: CGFloat {
        prominence == .dominant ? SymiSpacing.xxl : SymiSpacing.xl
    }

    private var sectionSpacing: CGFloat {
        prominence == .dominant ? SymiSpacing.xxl : SymiSpacing.lg
    }
}

struct SectionCardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let theme: InputFlowStepTheme
    let prominence: SectionCardProminence

    func body(content: Content) -> some View {
        content
            .background(background, in: RoundedRectangle(cornerRadius: SymiRadius.flowCard, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SymiRadius.flowCard, style: .continuous)
                    .stroke(borderColor, lineWidth: SymiStroke.hairline)
            }
            .shadow(
                color: colorScheme == .dark ? .clear : shadowColor,
                radius: prominence == .dominant ? 18 : 6,
                x: 0,
                y: prominence == .dominant ? 9 : 3
            )
    }

    private var background: Color {
        if colorScheme == .dark {
            return SymiColors.darkCardBackground.color.opacity(prominence == .dominant ? 0.98 : 0.86)
        }

        return SymiColors.card.color.opacity(prominence == .dominant ? 0.98 : 0.82)
    }

    private var borderColor: Color {
        theme.border(for: colorScheme).opacity(prominence == .dominant ? 0.18 : 0.09)
    }

    private var shadowColor: Color {
        AppTheme.symiPetrol.opacity(prominence == .dominant ? 0.14 : 0.045)
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
    var isCard = true

    var body: some View {
        PainGaugeView(value: $value, accent: intensityAccent(Double(value)), isCard: isCard)
    }
}

struct SymptomCardGrid: View {
    let options: [String]
    @Binding var selection: Set<String>
    let accent: Color

    var body: some View {
        InputFlowTileGrid(minimumColumnWidth: SymiSize.flowCompactTileGridMinWidth) {
            ForEach(options, id: \.self) { option in
                UnifiedSelectionTile(
                    title: option,
                    systemImage: symbolName(for: option),
                    isSelected: selection.contains(option),
                    accent: accent,
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
    let accent: Color

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
                    accent: accent
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
    let accent: Color
    @State private var detailsExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.lg) {
            HeadacheDayPartGrid {
                ForEach(EntryDayPartPreset.allCases) { preset in
                    UnifiedSelectionTile(
                        title: preset.title,
                        systemImage: preset.symbolName,
                        isSelected: EntryDayPartPreset(dayPart: EpisodeDayPart(date: startedAt)) == preset,
                        accent: accent,
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
    let accent: Color

    var body: some View {
        InputFlowTileGrid(minimumColumnWidth: SymiSize.flowTwoColumnTileGridMinWidth) {
            ForEach(options, id: \.self) { option in
                UnifiedSelectionTile(
                    title: option,
                    systemImage: symbolName(for: option),
                    isSelected: selection.contains(option),
                    accent: accent,
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
    let accent: Color

    @State private var selectedDosage = "400 mg"
    @State private var selectedTakenAt = "Jetzt"
    @State private var expandedMedicationID: String?

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
                    MedicationExpandableCard(
                        option: option,
                        isSelected: controller.isMedicationNameSelected(option.title),
                        isExpanded: expandedMedicationID == option.id,
                        selectedDosage: $selectedDosage,
                        selectedTakenAt: $selectedTakenAt,
                        dosageOptions: dosageOptions,
                        takenAtOptions: takenAtOptions,
                        accent: accent,
                        onToggle: { selectMedication(option, controller: controller) },
                        onDosage: { dosage in
                            controller.updateDosage(forMedicationNamed: option.title, dosage: dosage == "Andere" ? "" : dosage)
                        }
                    )
                }
            }

            UnifiedSelectionTile(
                title: controller.selectedMedications.isEmpty ? "Keine Medikation" : "Keine weitere Medikation",
                systemImage: "slash.circle",
                isSelected: controller.selectedMedications.isEmpty,
                accent: accent,
                accessibilityIdentifier: "entry-medication-none"
            ) {
                withAnimation(.snappy) {
                    expandedMedicationID = nil
                    controller.resetSelections()
                }
            }

            if !controller.selectedMedications.isEmpty {
                SelectedMedicationsSection(controller: controller)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.snappy, value: expandedMedicationID)
        .animation(.snappy, value: controller.selectedMedications)
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
        withAnimation(.snappy) {
            if controller.isMedicationNameSelected(option.title), expandedMedicationID == option.id {
                expandedMedicationID = nil
                return
            }

            if !controller.isMedicationNameSelected(option.title) {
                controller.toggleMedicationSelection(
                    named: option.title,
                    fallbackCategory: option.category,
                    fallbackDosage: dosage
                )
            }
            expandedMedicationID = option.id
        }
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
    let option: PainLocationOption
    let isSelected: Bool
    let accent: Color
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
                    .foregroundStyle(isSelected ? accent : AppTheme.symiTextPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(SymiTypography.compactScaleFactor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, SymiSpacing.xs)
            .padding(.vertical, SymiSpacing.xs)
            .frame(maxWidth: .infinity, minHeight: SymiSize.headacheLocationTileMinHeight)
            .modifier(SelectionStyleModifier(isSelected: isSelected, accent: accent))
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(accent)
                        .background(.background, in: Circle())
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
        .buttonStyle(PressScaleButtonStyle())
    }
}

struct MedicationFlowOption: Identifiable {
    let title: String
    let symbolName: String
    let category: MedicationCategory
    let defaultDosage: String

    var id: String { title }
}

struct UnifiedSelectionTile: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let accent: Color
    let accessibilityIdentifier: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: SymiSpacing.xs) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(isSelected ? accent : AppTheme.symiTextSecondary.opacity(SymiOpacity.strongText))
                    .frame(width: SymiSize.inputSelectionIconWidth, height: SymiSize.inputSelectionIconHeight)

                Text(title)
                    .font(SymiTypography.flowTileLabel)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(isSelected ? accent : AppTheme.symiTextPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(SymiTypography.compactScaleFactor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, SymiSpacing.sm)
            .padding(.vertical, SymiSpacing.xs)
            .frame(maxWidth: .infinity, minHeight: SymiSize.inputSelectionTileMinHeight)
            .modifier(SelectionStyleModifier(isSelected: isSelected, accent: accent))
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(accent)
                        .background(.background, in: Circle())
                        .padding(.top, SymiSpacing.sm)
                        .padding(.trailing, SymiSpacing.sm)
                        .accessibilityHidden(true)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Ausgewählt" : "Nicht ausgewählt")
        .accessibilityHint(isSelected ? "Entfernt die Auswahl." : "Wählt diese Option aus.")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(accessibilityIdentifier ?? "entry-selection-\(title)")
    }
}

struct MedicationExpandableCard: View {
    let option: MedicationFlowOption
    let isSelected: Bool
    let isExpanded: Bool
    @Binding var selectedDosage: String
    @Binding var selectedTakenAt: String
    let dosageOptions: [String]
    let takenAtOptions: [String]
    let accent: Color
    let onToggle: () -> Void
    let onDosage: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.md) {
            Button(action: onToggle) {
                HStack(spacing: SymiSpacing.sm) {
                    Image(systemName: option.symbolName)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(isSelected ? accent : AppTheme.symiTextSecondary.opacity(SymiOpacity.strongText))
                        .frame(width: SymiSize.inputSelectionIconWidth, height: SymiSize.inputSelectionIconHeight)

                    Text(option.title)
                        .font(SymiTypography.flowTileLabel)
                        .foregroundStyle(isSelected ? accent : AppTheme.symiTextPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(SymiTypography.compactScaleFactor)

                    Spacer(minLength: 0)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isSelected ? accent : AppTheme.symiTextSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: SymiSize.inputSelectionTileMinHeight, alignment: .leading)
            }
            .buttonStyle(PressScaleButtonStyle())

            if isExpanded {
                VStack(alignment: .leading, spacing: SymiSpacing.md) {
                    chipGroup(title: "Dosierung", options: dosageOptions, selection: $selectedDosage) { dosage in
                        onDosage(dosage)
                    }

                    chipGroup(title: "Einnahme", options: takenAtOptions, selection: $selectedTakenAt)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, SymiSpacing.md)
        .padding(.vertical, SymiSpacing.sm)
        .modifier(SelectionStyleModifier(isSelected: isSelected, accent: accent))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("entry-medication-\(option.title)")
    }

    private func chipGroup(
        title: String,
        options: [String],
        selection: Binding<String>,
        onSelect: ((String) -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: SymiSpacing.sm) {
            Text(title)
                .font(SymiTypography.flowPillLabel)
                .foregroundStyle(AppTheme.symiTextSecondary)

            InputFlowPillGrid {
                ForEach(options, id: \.self) { option in
                    AccentPillOption(
                        title: option,
                        isSelected: selection.wrappedValue == option,
                        accent: accent
                    ) {
                        selection.wrappedValue = option
                        onSelect?(option)
                    }
                }
            }
        }
    }
}

struct AccentPillOption: View {
    let title: String
    let isSelected: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: SymiSpacing.xs) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                        .alignmentGuide(.firstTextBaseline) { dimensions in
                            dimensions[VerticalAlignment.center]
                        }
                        .accessibilityHidden(true)
                }

                Text(title)
                    .font(SymiTypography.flowPillLabel)
                    .lineLimit(2)
                    .minimumScaleFactor(SymiTypography.compactScaleFactor)
            }
            .foregroundStyle(isSelected ? accent : AppTheme.symiTextPrimary)
            .padding(.horizontal, SymiSpacing.md)
            .padding(.vertical, SymiSpacing.pillVerticalPadding)
            .frame(maxWidth: .infinity, minHeight: SymiSize.minInteractiveHeight)
            .modifier(SelectionStyleModifier(isSelected: isSelected, accent: accent, cornerRadius: SymiRadius.flowPill, shape: .capsule))
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Ausgewählt" : "Nicht ausgewählt")
    }
}

struct SelectionStyleModifier: ViewModifier {
    enum ShapeKind {
        case roundedRectangle
        case capsule
    }

    @Environment(\.colorScheme) private var colorScheme

    let isSelected: Bool
    let accent: Color
    var cornerRadius: CGFloat = SymiRadius.flowTile
    var shape: ShapeKind = .roundedRectangle

    func body(content: Content) -> some View {
        content
            .background(background)
            .overlay(border)
            .animation(.snappy, value: isSelected)
    }

    @ViewBuilder
    private var background: some View {
        switch shape {
        case .roundedRectangle:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(isSelected ? accent.opacity(colorScheme == .dark ? 0.26 : 0.16) : neutralBackground)
        case .capsule:
            Capsule()
                .fill(isSelected ? accent.opacity(colorScheme == .dark ? 0.26 : 0.16) : neutralBackground)
        }
    }

    @ViewBuilder
    private var border: some View {
        switch shape {
        case .roundedRectangle:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(isSelected ? accent.opacity(0.82) : neutralBorder, lineWidth: isSelected ? SymiStroke.selectedHairline : SymiStroke.hairline)
        case .capsule:
            Capsule()
                .stroke(isSelected ? accent.opacity(0.82) : neutralBorder, lineWidth: isSelected ? SymiStroke.selectedHairline : SymiStroke.hairline)
        }
    }

    private var neutralBackground: Color {
        colorScheme == .dark ? SymiColors.darkCardBackground.color.opacity(0.74) : SymiColors.card.color.opacity(0.76)
    }

    private var neutralBorder: Color {
        SymiColors.subtleSeparator(for: colorScheme).opacity(0.55)
    }
}

struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: SymiAnimation.quickDuration), value: configuration.isPressed)
    }
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
