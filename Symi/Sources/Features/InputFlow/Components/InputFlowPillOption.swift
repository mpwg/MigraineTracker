import SwiftUI

struct InputFlowPillOption: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let isSelected: Bool
    let isDisabled: Bool
    let theme: InputFlowStepTheme
    let accessibilityIdentifier: String?
    let action: () -> Void

    init(
        title: String,
        isSelected: Bool,
        isDisabled: Bool = false,
        theme: InputFlowStepTheme,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isSelected = isSelected
        self.isDisabled = isDisabled
        self.theme = theme
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

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
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(SymiTypography.compactScaleFactor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(isSelected ? theme.accent(for: colorScheme) : AppTheme.symiTextPrimary)
            .padding(.horizontal, SymiSpacing.md)
            .padding(.vertical, SymiSpacing.pillVerticalPadding)
            .frame(
                maxWidth: .infinity,
                minHeight: SymiSize.minInteractiveHeight,
                maxHeight: SymiSize.minInteractiveHeight
            )
            .background(backgroundColor, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(borderColor, lineWidth: SymiStroke.hairline)
            }
            .opacity(isDisabled ? SymiOpacity.disabledContent : SymiOpacity.opaque)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Ausgewählt" : "Nicht ausgewählt")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(accessibilityIdentifier ?? "input-flow-pill-\(title)")
    }

    private var backgroundColor: Color {
        if isSelected {
            return theme.selectedFill(for: colorScheme)
        }

        return SymiColors.elevatedCard(for: colorScheme)
    }

    private var borderColor: Color {
        if isSelected {
            return theme.border(for: colorScheme).opacity(SymiOpacity.selectedStroke)
        }

        return SymiColors.subtleSeparator(for: colorScheme).opacity(SymiOpacity.strongSurface)
    }
}

typealias PillOption = InputFlowPillOption
