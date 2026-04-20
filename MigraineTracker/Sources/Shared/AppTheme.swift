import SwiftUI

enum AppTheme {
    static let ink = Color(red: 0.04, green: 0.30, blue: 0.38)
    static let ocean = Color(red: 0.08, green: 0.56, blue: 0.62)
    static let seaGlass = Color(red: 0.67, green: 0.86, blue: 0.82)
    static let foam = Color(red: 0.96, green: 0.93, blue: 0.84)
    static let coral = Color(red: 0.95, green: 0.46, blue: 0.35)
    static let mist = Color(red: 0.90, green: 0.96, blue: 0.95)

    static let appBackground = LinearGradient(
        colors: [
            mist,
            foam.opacity(0.94),
            seaGlass.opacity(0.30)
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
            Color.white.opacity(0.78),
            foam.opacity(0.92),
            seaGlass.opacity(0.28)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let selectedFill = ocean.opacity(0.18)
    static let secondaryFill = seaGlass.opacity(0.18)
    static let cardBorder = Color.white.opacity(0.45)
    static let shadowColor = ink.opacity(0.12)
}

private struct BrandScreenModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .tint(AppTheme.ocean)
            .scrollContentBackground(.hidden)
            .background(AppTheme.appBackground.ignoresSafeArea())
    }
}

private struct BrandCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.cardGradient)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: AppTheme.shadowColor, radius: 18, y: 10)
    }
}

extension View {
    func brandScreen() -> some View {
        modifier(BrandScreenModifier())
    }

    func brandCard() -> some View {
        modifier(BrandCardModifier())
    }
}
