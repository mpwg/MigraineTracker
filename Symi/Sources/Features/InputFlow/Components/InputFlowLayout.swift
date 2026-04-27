import SwiftUI

struct InputFlowFieldGroup<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(SymiTypography.flowSectionTitle)
                .foregroundStyle(.primary)

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

    init(minimumColumnWidth: CGFloat = 70, @ViewBuilder content: () -> Content) {
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
                Color(red: 0.08, green: 0.09, blue: 0.10),
                Color(red: 0.06, green: 0.10, blue: 0.10),
                Color(red: 0.10, green: 0.09, blue: 0.08)
            ]
        }

        return [
            SymiColors.warmBackground.color,
            Color.white,
            SymiColors.sage.color.opacity(0.18)
        ]
    }
}
