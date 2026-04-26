import SwiftUI

enum NewEntryStepID: String, CaseIterable, Identifiable, Sendable {
    case headache
    case medication
    case triggers
    case note
    case review

    var id: String { rawValue }
}

enum NewEntryStepStatus: String, Sendable {
    case open
    case active
    case complete
}

struct NewEntryStepMetadata: Identifiable, Sendable {
    let id: NewEntryStepID
    let title: String
    let subline: String
    let symbolName: String
    let colorToken: NewEntryStepColorToken
    let status: NewEntryStepStatus?
}

enum NewEntryStepCatalog {
    static let steps: [NewEntryStepMetadata] = [
        NewEntryStepMetadata(
            id: .headache,
            title: "Kopfschmerz",
            subline: "Wie stark ist es gerade?",
            symbolName: "waveform.path.ecg",
            colorToken: .coral,
            status: nil
        ),
        NewEntryStepMetadata(
            id: .medication,
            title: "Medikation",
            subline: "Was hast du genommen?",
            symbolName: "pills.fill",
            colorToken: .sageTeal,
            status: nil
        ),
        NewEntryStepMetadata(
            id: .triggers,
            title: "Auslöser",
            subline: "Was könnte eine Rolle gespielt haben?",
            symbolName: "brain.head.profile",
            colorToken: .blue,
            status: nil
        ),
        NewEntryStepMetadata(
            id: .note,
            title: "Notiz",
            subline: "Was fällt dir auf?",
            symbolName: "note.text",
            colorToken: .warmAmber,
            status: nil
        ),
        NewEntryStepMetadata(
            id: .review,
            title: "Eintrag prüfen",
            subline: "Alles bereit zum Speichern.",
            symbolName: "checkmark.seal.fill",
            colorToken: .purple,
            status: nil
        )
    ]

    static func metadata(for id: NewEntryStepID) -> NewEntryStepMetadata {
        guard let metadata = steps.first(where: { $0.id == id }) else {
            preconditionFailure("Fehlende Step-Metadaten für \(id.rawValue).")
        }

        return metadata
    }
}

enum NewEntryStepColorToken: String, CaseIterable, Sendable {
    case coral
    case sageTeal
    case blue
    case warmAmber
    case purple

    var color: Color {
        color(for: .light)
    }

    func color(for colorScheme: ColorScheme) -> Color {
        let components = colorScheme == .dark ? darkComponents : lightComponents
        return Color(red: components.red, green: components.green, blue: components.blue)
    }

    func softFill(for colorScheme: ColorScheme) -> Color {
        color(for: colorScheme).opacity(0.16)
    }

    func selectedFill(for colorScheme: ColorScheme) -> Color {
        color(for: colorScheme).opacity(0.24)
    }

    func border(for colorScheme: ColorScheme) -> Color {
        color(for: colorScheme).opacity(0.36)
    }

    private var lightComponents: ColorComponents {
        switch self {
        case .coral:
            ColorComponents(red: 0.98, green: 0.39, blue: 0.33)
        case .sageTeal:
            ColorComponents(red: 0.23, green: 0.61, blue: 0.52)
        case .blue:
            ColorComponents(red: 0.24, green: 0.47, blue: 0.84)
        case .warmAmber:
            ColorComponents(red: 0.82, green: 0.52, blue: 0.19)
        case .purple:
            ColorComponents(red: 0.54, green: 0.38, blue: 0.82)
        }
    }

    private var darkComponents: ColorComponents {
        switch self {
        case .coral:
            ColorComponents(red: 1.00, green: 0.56, blue: 0.50)
        case .sageTeal:
            ColorComponents(red: 0.48, green: 0.82, blue: 0.73)
        case .blue:
            ColorComponents(red: 0.50, green: 0.67, blue: 1.00)
        case .warmAmber:
            ColorComponents(red: 0.96, green: 0.70, blue: 0.38)
        case .purple:
            ColorComponents(red: 0.75, green: 0.62, blue: 1.00)
        }
    }
}

struct StepIcon: View {
    @Environment(\.colorScheme) private var colorScheme

    let metadata: NewEntryStepMetadata

    init(_ metadata: NewEntryStepMetadata) {
        self.metadata = metadata
    }

    var body: some View {
        Image(systemName: metadata.symbolName)
            .font(.title3.weight(.semibold))
            .foregroundStyle(metadata.colorToken.color(for: colorScheme))
            .frame(width: 44, height: 44)
            .background(metadata.colorToken.softFill(for: colorScheme))
            .clipShape(Circle())
            .accessibilityHidden(true)
    }
}

struct ProgressIndicator: View {
    @Environment(\.colorScheme) private var colorScheme

    let currentStep: Int
    let totalSteps: Int
    let colorToken: NewEntryStepColorToken

    init(currentStep: Int, totalSteps: Int = NewEntryStepCatalog.steps.count, colorToken: NewEntryStepColorToken) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.colorToken = colorToken
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(clampedCurrentStep) von \(safeTotalSteps)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityLabel("Schritt \(clampedCurrentStep) von \(safeTotalSteps)")

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.18))

                    Capsule()
                        .fill(colorToken.color(for: colorScheme))
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 6)
        }
    }

    private var safeTotalSteps: Int {
        max(totalSteps, 1)
    }

    private var clampedCurrentStep: Int {
        min(max(currentStep, 1), safeTotalSteps)
    }

    private var progress: Double {
        Double(clampedCurrentStep) / Double(safeTotalSteps)
    }
}

struct PrimaryButton<Label: View>: View {
    let action: () -> Void
    let label: () -> Label

    init(action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.label = label
    }

    var body: some View {
        Button(action: action) {
            label()
        }
        .buttonStyle(SymiPrimaryButtonStyle())
    }
}

struct SelectionChip: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let isSelected: Bool
    let colorToken: NewEntryStepColorToken
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .imageScale(.medium)

                Text(title)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(isSelected ? colorToken.selectedFill(for: colorScheme) : colorToken.softFill(for: colorScheme))
            .foregroundStyle(isSelected ? colorToken.color(for: colorScheme) : Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? colorToken.border(for: colorScheme) : Color.secondary.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct MultiSelectGrid: View {
    let options: [String]
    @Binding var selection: Set<String>
    let colorToken: NewEntryStepColorToken
    let accessibilityPrefix: String

    init(
        options: [String],
        selection: Binding<Set<String>>,
        colorToken: NewEntryStepColorToken,
        accessibilityPrefix: String
    ) {
        self.options = options
        _selection = selection
        self.colorToken = colorToken
        self.accessibilityPrefix = accessibilityPrefix
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection.contains(option)

                SelectionChip(
                    title: option,
                    isSelected: isSelected,
                    colorToken: colorToken
                ) {
                    toggle(option)
                }
                .accessibilityLabel("\(accessibilityPrefix): \(option)")
                .accessibilityValue(isSelected ? "Ausgewählt" : "Nicht ausgewählt")
                .accessibilityHint(isSelected ? "Entfernt die Auswahl." : "Wählt diese Option aus.")
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

private struct ColorComponents: Sendable {
    let red: Double
    let green: Double
    let blue: Double
}
