import SwiftUI

enum SymiTypography {
    // Scale factors
    static let compactScaleFactor = 0.82
    static let tightChipScaleFactor = 0.72
    static let buttonScaleFactor = 0.85
    static let gaugeScaleFactor = 0.75
    static let symiPlusTitleScaleFactor = 0.8
    static let symiPlusBadgeScaleFactor = compactScaleFactor
    static let symiPlusFooterScaleFactor = tightChipScaleFactor

    // Core text styles
    static let headline = Font.headline
    static let body = Font.body
    static let secondary = Font.subheadline
    static let button = Font.headline.weight(.semibold)
    static let caption = Font.caption
    static let symiPlusButtonIcon = Font.system(size: 14, weight: .semibold)

    // Metrics and emphasis
    static let largeMetric = Font.system(size: 58, weight: .bold, design: .rounded)
    static let largeRoundedTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let homePainScaleMetric = Font.system(size: 58, weight: .bold, design: .rounded)
    static let insightHeroTitle = Font.system(size: 23, weight: .bold, design: .rounded)
    static let insightMetric = Font.system(size: 30, weight: .bold, design: .rounded)
    static let homeMetric = Font.system(size: 44, weight: .bold, design: .rounded)
    static let entryDetailIntensityTitle = Font.system(size: 44, weight: .bold, design: .rounded)

    // Input flow
    static let flowTitle = Font.system(size: 24, weight: .bold, design: .rounded)
    static let flowSubtitle = Font.callout
    static let flowSectionTitle = Font.subheadline.weight(.regular)
    static let flowTileLabel = Font.subheadline.weight(.medium)
    static let flowPillLabel = Font.footnote.weight(.medium)
    static let flowPrimaryButton = Font.headline.weight(.semibold)
    static let flowSecondaryAction = Font.footnote.weight(.medium)
    static let flowSummaryTitle = Font.headline.weight(.semibold)
    static let flowSummaryLine = Font.subheadline

    // Symi Plus
    static let symiPlusFeatureIcon = Font.system(size: 25, weight: .semibold)
}
