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
            VStack(spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: systemImage)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(iconColor)
                        .frame(width: 34, height: 30)

                    if state.isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.accent(for: colorScheme))
                            .background(Color(uiColor: .systemBackground), in: Circle())
                            .offset(x: 12, y: -6)
                            .accessibilityHidden(true)
                    }
                }

                Text(title)
                    .font(SymiTypography.flowTileLabel)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(state.isDisabled ? .secondary : .primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 84)
            .background(tileBackground, in: RoundedRectangle(cornerRadius: SymiRadius.flowTile, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SymiRadius.flowTile, style: .continuous)
                    .stroke(borderColor, lineWidth: state.isSelected ? 1.5 : 1)
            }
            .opacity(state.isDisabled ? 0.58 : 1)
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
            return .secondary
        }

        return state.isSelected ? theme.accent(for: colorScheme) : .secondary
    }

    private var tileBackground: Color {
        if state.isSelected {
            return theme.selectedFill(for: colorScheme)
        }

        return colorScheme == .dark ? Color(uiColor: .secondarySystemGroupedBackground) : SymiColors.card.color
    }

    private var borderColor: Color {
        if state.isSelected {
            return theme.border(for: colorScheme)
        }

        return Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.08)
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
