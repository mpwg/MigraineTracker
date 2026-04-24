import SwiftUI

enum AppTheme {
    static let groupedHorizontalInset: CGFloat = 20
    static let groupedTopInset: CGFloat = 12
    static let groupedRowInsets = EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)
    static let wideContentMaxWidth: CGFloat = 1180
    static let readableContentMaxWidth: CGFloat = 760
    static let dashboardSpacing: CGFloat = 20

    static let symiPetrol = Color(red: 0.059, green: 0.239, blue: 0.243)
    static let symiSage = Color(red: 0.557, green: 0.804, blue: 0.722)
    static let symiCoral = Color(red: 1.000, green: 0.541, blue: 0.478)
    static let symiBackground = Color(red: 0.965, green: 0.957, blue: 0.937)
    static let symiCard = Color(red: 1.000, green: 0.996, blue: 0.984)
    static let symiTextPrimary = Color(red: 0.110, green: 0.110, blue: 0.118)
    static let symiTextSecondary = Color(red: 0.420, green: 0.420, blue: 0.431)

    static let ink = symiPetrol
    static let ocean = symiPetrol
    static let seaGlass = symiSage
    static let foam = symiBackground
    static let coral = symiCoral
    static let mist = Color(red: 0.925, green: 0.969, blue: 0.955)

    static let appBackground = LinearGradient(
        colors: [
            symiBackground,
            Color.white.opacity(0.72),
            symiSage.opacity(0.22)
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
            Color.white.opacity(0.96)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let selectedFill = symiSage.opacity(0.35)
    static let secondaryFill = symiSage.opacity(0.18)
    static let cardBorder = Color.clear
    static let shadowColor = symiPetrol.opacity(0.10)
}

private struct BrandScreenModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .tint(AppTheme.symiPetrol)
            .scrollContentBackground(.hidden)
            .background(AppTheme.appBackground.ignoresSafeArea())
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
    func body(content: Content) -> some View {
        content
            .background(AppTheme.cardGradient)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: AppTheme.shadowColor, radius: 14, x: 0, y: 6)
    }
}

struct SymiPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(AppTheme.symiCoral.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: AppTheme.symiCoral.opacity(configuration.isPressed ? 0.10 : 0.22), radius: 12, y: 6)
    }
}

struct SymiSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(AppTheme.symiPetrol)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(AppTheme.symiSage.opacity(configuration.isPressed ? 0.20 : 0.32))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
