import SwiftUI

struct InputFlowCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let theme: InputFlowStepTheme?
    let isHighlighted: Bool
    let content: Content

    init(
        theme: InputFlowStepTheme? = nil,
        isHighlighted: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.theme = theme
        self.isHighlighted = isHighlighted
        self.content = content()
    }

    var body: some View {
        content
            .padding(SymiSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: SymiRadius.flowCard, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SymiRadius.flowCard, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }
            .shadow(color: shadowColor, radius: SymiShadow.cardRadius, x: 0, y: SymiShadow.cardYOffset)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(uiColor: .secondarySystemGroupedBackground) : SymiColors.card.color
    }

    private var borderColor: Color {
        guard isHighlighted, let theme else {
            return Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.08)
        }

        return theme.border(for: colorScheme)
    }

    private var shadowColor: Color {
        colorScheme == .dark ? .clear : SymiShadow.cardColor
    }
}
