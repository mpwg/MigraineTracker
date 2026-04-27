import SwiftUI

struct InputFlowFieldGroup<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SymiSpacing.lg) {
            Text(title)
                .font(SymiTypography.flowSectionTitle)
                .foregroundStyle(AppTheme.symiTextSecondary)

            content
        }
    }
}

struct InputFlowTileGrid<Content: View>: View {
    let minimumColumnWidth: CGFloat
    let content: Content

    init(minimumColumnWidth: CGFloat, @ViewBuilder content: () -> Content) {
        self.minimumColumnWidth = minimumColumnWidth
        self.content = content()
    }

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: minimumColumnWidth), spacing: SymiSpacing.tileSpacing, alignment: .top)
            ],
            alignment: .leading,
            spacing: SymiSpacing.tileSpacing
        ) {
            content
        }
    }
}

struct InputFlowPillGrid<Content: View>: View {
    let minimumColumnWidth: CGFloat
    let content: Content

    init(minimumColumnWidth: CGFloat = SymiSize.pillGridMinWidth, @ViewBuilder content: () -> Content) {
        self.minimumColumnWidth = minimumColumnWidth
        self.content = content()
    }

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: minimumColumnWidth), spacing: SymiSpacing.pillSpacing, alignment: .top)
            ],
            alignment: .leading,
            spacing: SymiSpacing.pillSpacing
        ) {
            content
        }
    }
}

struct InputFlowBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var colors: [Color] {
        if colorScheme == .dark {
            return [
                SymiColors.darkBackgroundTop.color,
                SymiColors.darkBackgroundMiddle.color,
                SymiColors.darkBackgroundBottom.color
            ]
        }

        return [
            SymiColors.warmBackground.color,
            SymiColors.onAccent.color,
            SymiColors.sage.color.opacity(SymiOpacity.secondaryFill)
        ]
    }
}
