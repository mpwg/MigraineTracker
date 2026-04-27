import SwiftUI

enum InputFlowSelectionState: Equatable, Sendable {
    case unselected
    case selected
    case disabled

    var isSelected: Bool {
        self == .selected
    }

    var isDisabled: Bool {
        self == .disabled
    }
}

struct InputFlowSelectionTile: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let systemImage: String
    let state: InputFlowSelectionState
    let theme: InputFlowStepTheme
    let accessibilityIdentifier: String?
    let action: () -> Void

    init(
        title: String,
        systemImage: String,
        isSelected: Bool,
        isDisabled: Bool = false,
        theme: InputFlowStepTheme,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.state = isDisabled ? .disabled : (isSelected ? .selected : .unselected)
        self.theme = theme
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: SymiSpacing.xs) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(iconColor)
                    .frame(width: SymiSize.inputSelectionIconWidth, height: SymiSize.inputSelectionIconHeight)

                Text(title)
                    .font(SymiTypography.flowTileLabel)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(state.isDisabled ? AppTheme.symiTextSecondary : AppTheme.symiTextPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(SymiTypography.compactScaleFactor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, SymiSpacing.sm)
            .padding(.vertical, SymiSpacing.xs)
            .frame(maxWidth: .infinity, minHeight: SymiSize.inputSelectionTileMinHeight)
            .background(tileBackground, in: RoundedRectangle(cornerRadius: SymiRadius.flowTile, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SymiRadius.flowTile, style: .continuous)
                    .stroke(borderColor, lineWidth: SymiStroke.hairline)
            }
            .overlay(alignment: .topTrailing) {
                if state.isSelected {
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
            .opacity(state.isDisabled ? SymiOpacity.disabledTile : SymiOpacity.opaque)
        }
        .buttonStyle(.plain)
        .disabled(state.isDisabled)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(state.isSelected ? .isSelected : [])
        .accessibilityIdentifier(accessibilityIdentifier ?? "input-flow-tile-\(title)")
    }

    private var iconColor: Color {
        if state.isDisabled {
            return AppTheme.symiTextSecondary
        }

        return state.isSelected ? theme.accent(for: colorScheme) : AppTheme.symiTextSecondary.opacity(SymiOpacity.strongText)
    }

    private var tileBackground: Color {
        if state.isSelected {
            return theme.selectedFill(for: colorScheme)
        }

        return SymiColors.elevatedCard(for: colorScheme)
    }

    private var borderColor: Color {
        if state.isSelected {
            return theme.border(for: colorScheme).opacity(SymiOpacity.selectedStroke)
        }

        return SymiColors.subtleSeparator(for: colorScheme).opacity(SymiOpacity.strongSurface)
    }

    private var accessibilityValue: String {
        switch state {
        case .selected:
            "Ausgewählt"
        case .unselected:
            "Nicht ausgewählt"
        case .disabled:
            "Nicht verfügbar"
        }
    }

    private var accessibilityHint: String {
        state.isSelected ? "Entfernt die Auswahl." : "Wählt diese Option aus."
    }
}

typealias SelectionTile = InputFlowSelectionTile
