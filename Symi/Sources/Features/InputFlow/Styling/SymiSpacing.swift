import SwiftUI

enum SymiSpacing {
    static let flowHorizontalPadding: CGFloat = 20
    static let flowMaxContentWidth: CGFloat = 420
    static let flowSectionSpacing: CGFloat = 22
    static let flowHeaderTopPadding: CGFloat = 8
    static let flowHeaderControlSpacing: CGFloat = 10
    static let flowHeaderTitleSpacing: CGFloat = 8
    static let flowFooterTopPadding: CGFloat = 10
    static let flowFooterBottomPadding: CGFloat = 10
    static let tileSpacing: CGFloat = 10
    static let pillSpacing: CGFloat = 8
    static let cardPadding: CGFloat = 18
}

enum SymiRadius {
    static let flowCard: CGFloat = 18
    static let flowTile: CGFloat = 14
    static let flowPill: CGFloat = 12
    static let flowBanner: CGFloat = 16
}

enum SymiShadow {
    static let cardColor = AppTheme.symiPetrol.opacity(0.06)
    static let cardRadius: CGFloat = 12
    static let cardYOffset: CGFloat = 5
    static let buttonColor = AppTheme.symiPetrol.opacity(0.16)
    static let buttonRadius: CGFloat = 12
    static let buttonYOffset: CGFloat = 6
}
