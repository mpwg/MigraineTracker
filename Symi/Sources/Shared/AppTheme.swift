import SwiftUI

enum AppTheme {
    static let groupedHorizontalInset = SymiSpacing.groupedHorizontalInset
    static let groupedTopInset = SymiSpacing.screenTopInset
    static let groupedRowInsets = EdgeInsets(
        top: SymiSpacing.sm,
        leading: SymiSpacing.xxl,
        bottom: SymiSpacing.sm,
        trailing: SymiSpacing.xxl
    )
    static let wideContentMaxWidth = SymiSpacing.wideContentMaxWidth
    static let readableContentMaxWidth = SymiSpacing.readableContentMaxWidth
    static let dashboardSpacing = SymiSpacing.dashboardSpacing

    static let symiPetrol = SymiColors.primaryPetrol.color
    static let symiSage = SymiColors.sage.color
    static let symiCoral = SymiColors.coral.color
    static let symiBackground = SymiColors.warmBackground.color
    static let symiCard = SymiColors.card.color
    static let symiTextPrimary = SymiColors.textPrimary.color
    static let symiTextSecondary = SymiColors.textSecondary.color
    static let symiOnAccent = SymiColors.onAccent.color

    static let ink = symiPetrol
    static let ocean = symiPetrol
    static let seaGlass = symiSage
    static let foam = symiBackground
    static let coral = symiCoral
    static let mist = SymiColors.mist.color

    static let appBackground = LinearGradient(
        colors: [
            symiBackground,
            symiOnAccent.opacity(SymiOpacity.appBackgroundSurface),
            symiSage.opacity(SymiOpacity.backgroundAccent)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let heroGradient = LinearGradient(
        colors: [
            ocean,
            ink
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardGradient = LinearGradient(
        colors: [
            symiCard,
            symiOnAccent.opacity(SymiOpacity.strongSurface)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let selectedFill = symiSage.opacity(SymiOpacity.selectedFill)
    static let secondaryFill = symiSage.opacity(SymiOpacity.secondaryFill)
    static let cardBorder = Color.clear
    static let shadowColor = symiPetrol.opacity(SymiOpacity.shadow)

    static func petrol(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? SymiColors.petrolDark.color : SymiColors.primaryPetrol.color
    }

    static func sage(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? SymiColors.sageDark.color : SymiColors.sage.color
    }

    static func coral(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? SymiColors.coralDark.color : SymiColors.coral.color
    }

    static func warmBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? SymiColors.darkBackgroundMiddle.color : SymiColors.warmBackground.color
    }

    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        SymiColors.cardBackground(for: colorScheme)
    }

    static func textPrimary(for colorScheme: ColorScheme) -> Color {
        SymiColors.textPrimary(for: colorScheme)
    }

    static func textSecondary(for colorScheme: ColorScheme) -> Color {
        SymiColors.textSecondary(for: colorScheme)
    }

    static func appBackground(for colorScheme: ColorScheme) -> LinearGradient {
        let colors: [Color] = if colorScheme == .dark {
            [
                SymiColors.darkBackgroundTop.color,
                SymiColors.darkBackgroundMiddle.color,
                SymiColors.darkBackgroundBottom.color
            ]
        } else {
            [
                SymiColors.warmBackground.color,
                SymiColors.onAccent.color.opacity(SymiOpacity.appBackgroundSurface),
                SymiColors.sage.color.opacity(SymiOpacity.backgroundAccent)
            ]
        }

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func cardGradient(for colorScheme: ColorScheme) -> LinearGradient {
        let colors: [Color] = if colorScheme == .dark {
            [
                SymiColors.cardBackground(for: colorScheme),
                SymiColors.sageDark.color.opacity(SymiOpacity.softFill)
            ]
        } else {
            [
                SymiColors.card.color,
                SymiColors.onAccent.color.opacity(SymiOpacity.strongSurface)
            ]
        }

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func selectedFill(for colorScheme: ColorScheme) -> Color {
        sage(for: colorScheme).opacity(colorScheme == .dark ? SymiOpacity.stepSelectedFillDark : SymiOpacity.selectedFill)
    }

    static func secondaryFill(for colorScheme: ColorScheme) -> Color {
        sage(for: colorScheme).opacity(colorScheme == .dark ? SymiOpacity.pressedFill : SymiOpacity.secondaryFill)
    }

    static func shadowColor(for colorScheme: ColorScheme) -> Color {
        Color.black.opacity(colorScheme == .dark ? SymiOpacity.backgroundAccent : SymiOpacity.shadow)
    }
}

private struct BrandScreenModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .tint(AppTheme.petrol(for: colorScheme))
            .scrollContentBackground(.hidden)
            .background(AppTheme.appBackground(for: colorScheme).ignoresSafeArea())
    }
}

private struct BrandGroupedScreenModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content
            .brandScreen()
            .contentMargins(.horizontal, horizontalInset, for: .scrollContent)
            .contentMargins(.top, AppTheme.groupedTopInset, for: .scrollContent)
    }

    private var horizontalInset: CGFloat {
        horizontalSizeClass == .compact ? AppTheme.groupedHorizontalInset : 36
    }
}

private struct WideContentModifier: ViewModifier {
    let maxWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: maxWidth, alignment: .center)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct BrandCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(AppTheme.cardGradient(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: SymiRadius.card, style: .continuous))
            .shadow(
                color: AppTheme.shadowColor(for: colorScheme),
                radius: SymiShadow.brandCardRadius,
                x: SymiShadow.cardXOffset,
                y: SymiShadow.brandCardYOffset
            )
    }
}

struct SymiPrimaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SymiTypography.button)
            .foregroundStyle(AppTheme.symiOnAccent)
            .padding(.vertical, SymiSpacing.lg)
            .frame(maxWidth: .infinity)
            .background(AppTheme.coral(for: colorScheme).opacity(configuration.isPressed ? SymiOpacity.heroPrimaryWave : SymiOpacity.opaque))
            .clipShape(RoundedRectangle(cornerRadius: SymiRadius.button, style: .continuous))
            .shadow(
                color: AppTheme.coral(for: colorScheme).opacity(configuration.isPressed ? SymiOpacity.pressedShadow : SymiOpacity.backgroundAccent),
                radius: SymiShadow.buttonRadius,
                y: SymiShadow.buttonYOffset
            )
    }
}

struct SymiSecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SymiTypography.button)
            .foregroundStyle(AppTheme.petrol(for: colorScheme))
            .padding(.vertical, SymiSpacing.secondaryButtonVerticalPadding)
            .frame(maxWidth: .infinity)
            .background(AppTheme.sage(for: colorScheme).opacity(configuration.isPressed ? SymiOpacity.pressedFill : SymiOpacity.secondaryPressedFill))
            .clipShape(RoundedRectangle(cornerRadius: SymiRadius.button, style: .continuous))
    }
}

extension View {
    func brandScreen() -> some View {
        modifier(BrandScreenModifier())
    }

    func brandGroupedScreen() -> some View {
        modifier(BrandGroupedScreenModifier())
    }

    func wideContent(maxWidth: CGFloat = AppTheme.wideContentMaxWidth) -> some View {
        modifier(WideContentModifier(maxWidth: maxWidth))
    }

    func brandGroupedRow() -> some View {
        listRowInsets(AppTheme.groupedRowInsets)
    }

    func brandCard() -> some View {
        modifier(BrandCardModifier())
    }
}

extension Color {
    static let symiPetrol = AppTheme.symiPetrol
    static let symiSage = AppTheme.symiSage
    static let symiCoral = AppTheme.symiCoral
    static let symiBackground = AppTheme.symiBackground
    static let symiCard = AppTheme.symiCard
    static let symiTextPrimary = AppTheme.symiTextPrimary
    static let symiTextSecondary = AppTheme.symiTextSecondary
}
