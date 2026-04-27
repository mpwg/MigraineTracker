import SwiftUI

enum SymiTypography {
    static let compactScaleFactor = 0.82
    static let tightChipScaleFactor = 0.72
    static let buttonScaleFactor = 0.85
    static let gaugeScaleFactor = 0.75
    static let headline = Font.headline
    static let body = Font.body
    static let secondary = Font.subheadline
    static let button = Font.headline.weight(.semibold)
    static let caption = Font.caption
    static let largeMetric = Font.system(size: 58, weight: .bold, design: .rounded)
    static let largeRoundedTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let homePainScaleMetric = Font.system(size: 58, weight: .bold, design: .rounded)
    static let insightHeroTitle = Font.system(size: 23, weight: .bold, design: .rounded)
    static let insightMetric = Font.system(size: 30, weight: .bold, design: .rounded)
    static let painGaugeMetric = Font.system(size: 52, weight: .bold, design: .rounded)
    static let painGaugeUnit = Font.footnote.weight(.medium)
    static let painGaugeLabel = Font.title3.weight(.semibold)
    static let homeMetric = Font.system(size: 44, weight: .bold, design: .rounded)
    static let flowTitle = Font.system(size: 24, weight: .bold, design: .rounded)
    static let flowSubtitle = Font.callout
    static let flowSectionTitle = Font.subheadline.weight(.regular)
    static let flowTileLabel = Font.subheadline.weight(.medium)
    static let flowPillLabel = Font.footnote.weight(.medium)
    static let flowPrimaryButton = Font.headline.weight(.semibold)
    static let flowSecondaryAction = Font.footnote.weight(.medium)
    static let flowSummaryTitle = Font.headline.weight(.semibold)
    static let flowSummaryLine = Font.subheadline
}
