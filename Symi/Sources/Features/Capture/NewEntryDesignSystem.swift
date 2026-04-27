import SwiftUI

typealias NewEntryStepID = InputFlowStepID
typealias NewEntryStepStatus = InputFlowStepStatus
typealias NewEntryStepMetadata = InputFlowStepMetadata
typealias NewEntryStepCatalog = InputFlowStepCatalog
typealias NewEntryStepColorToken = InputFlowStepColorToken

struct StepIcon: View {
    let metadata: NewEntryStepMetadata

    init(_ metadata: NewEntryStepMetadata) {
        self.metadata = metadata
    }

    var body: some View {
        InputFlowStepIcon(metadata)
    }
}

struct ProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    let colorToken: NewEntryStepColorToken

    init(currentStep: Int, totalSteps: Int = NewEntryStepCatalog.steps.count, colorToken: NewEntryStepColorToken) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.colorToken = colorToken
    }

    var body: some View {
        InputFlowProgressView(
            currentStep: currentStep,
            totalSteps: totalSteps,
            theme: InputFlowStepTheme(colorToken: colorToken)
        )
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
