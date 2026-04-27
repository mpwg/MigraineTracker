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
                    .stroke(borderColor, lineWidth: SymiStroke.hairline)
            }
            .shadow(color: shadowColor, radius: SymiShadow.cardRadius, x: SymiShadow.cardXOffset, y: SymiShadow.cardYOffset)
    }

    private var cardBackground: Color {
        SymiColors.elevatedCard(for: colorScheme)
    }

    private var borderColor: Color {
        guard isHighlighted, let theme else {
            return SymiColors.subtleSeparator(for: colorScheme).opacity(SymiOpacity.strongSurface)
        }

        return theme.border(for: colorScheme).opacity(SymiOpacity.clearStroke)
    }

    private var shadowColor: Color {
        colorScheme == .dark ? Color.clear : SymiShadow.cardColor
    }
}
