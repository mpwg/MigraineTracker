import SwiftUI

enum SymiGlassLevel: Sendable {
    case subtle
    case regular
    case prominent

    var cornerRadius: CGFloat {
        switch self {
        case .subtle:
            18
        case .regular:
            20
        case .prominent:
            24
        }
    }

    var fillOpacity: Double {
        switch self {
        case .subtle:
            0.70
        case .regular:
            0.80
        case .prominent:
            0.90
        }
    }

    var borderOpacity: Double {
        switch self {
        case .subtle:
            0.24
        case .regular:
            0.32
        case .prominent:
            0.42
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .prominent:
            22
        case .regular:
            14
        case .subtle:
            9
        }
    }

    var shadowY: CGFloat {
        switch self {
        case .prominent:
            9
        case .regular:
            6
        case .subtle:
            3
        }
    }
}

struct GlassCard<Content: View>: View {
    let level: SymiGlassLevel
    let content: Content

    init(level: SymiGlassLevel = .regular, @ViewBuilder content: () -> Content) {
        self.level = level
        self.content = content()
    }

    var body: some View {
        content
            .padding(SymiSpacing.cardPadding)
            .symiGlass(level)
    }
}

struct GlassSheetPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, SymiSpacing.xxl)
            .padding(.top, SymiSpacing.md)
            .padding(.bottom, SymiSpacing.xxl)
            .symiGlass(.prominent, cornerRadius: SymiRadius.glassSheetPanel)
    }
}

private struct SymiGlassSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    let level: SymiGlassLevel
    let cornerRadius: CGFloat?

    @ViewBuilder
    func body(content: Content) -> some View {
        let radius = cornerRadius ?? level.cornerRadius
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        if reduceTransparency {
            content
                .background {
                    shape.fill(SymiColors.cardBackground(for: colorScheme))
                }
                .overlay {
                    shape.stroke(borderColor, lineWidth: SymiStroke.hairline)
                }
                .clipShape(shape)
                .shadow(
                    color: shadowColor,
                    radius: level.shadowRadius,
                    x: SymiShadow.cardXOffset,
                    y: level.shadowY
                )
        } else if #available(iOS 26.0, *) {
            content
                .background {
                    shape.fill(SymiColors.cardBackground(for: colorScheme).opacity(level.fillOpacity))
                }
                .glassEffect(.regular.tint(glassTint), in: .rect(cornerRadius: radius))
                .overlay {
                    shape.stroke(borderColor, lineWidth: SymiStroke.hairline)
                }
                .clipShape(shape)
                .shadow(
                    color: shadowColor,
                    radius: level.shadowRadius,
                    x: SymiShadow.cardXOffset,
                    y: level.shadowY
                )
        } else {
            content
                .background {
                    shape
                        .fill(.thinMaterial)
                        .background {
                            shape.fill(SymiColors.cardBackground(for: colorScheme).opacity(level.fillOpacity))
                        }
                }
                .overlay {
                    shape.stroke(borderColor, lineWidth: SymiStroke.hairline)
                }
                .clipShape(shape)
                .shadow(
                    color: shadowColor,
                    radius: level.shadowRadius,
                    x: SymiShadow.cardXOffset,
                    y: level.shadowY
                )
        }
    }

    private var borderColor: Color {
        if reduceTransparency {
            return SymiColors.subtleSeparator(for: colorScheme).opacity(SymiOpacity.strongSurface)
        }

        return Color.white.opacity(colorScheme == .dark ? level.borderOpacity * SymiOpacity.glassBorderDarkMultiplier : level.borderOpacity)
    }

    private var shadowColor: Color {
        guard colorScheme != .dark else {
            return Color.clear
        }

        return AppTheme.symiPetrol.opacity(level == .prominent ? SymiOpacity.glassProminentShadow : SymiOpacity.glassRegularShadow)
    }

    private var glassTint: Color {
        SymiColors.cardBackground(for: colorScheme).opacity(colorScheme == .dark ? SymiOpacity.glassTintDark : SymiOpacity.glassTintLight)
    }
}

extension View {
    func symiGlass(_ level: SymiGlassLevel = .regular, cornerRadius: CGFloat? = nil) -> some View {
        modifier(SymiGlassSurfaceModifier(level: level, cornerRadius: cornerRadius))
    }
}
