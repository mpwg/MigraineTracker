import SwiftUI

// MARK: - Spacing

nonisolated enum SymiSpacing {
    // Base scale
    static let zero: CGFloat = 0
    static let micro: CGFloat = 2
    static let xxs: CGFloat = 4
    static let compact: CGFloat = 6
    static let xs: CGFloat = 8
    static let sm: CGFloat = 10
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 18
    static let xxl: CGFloat = 20
    static let xxxl: CGFloat = 24

    // App layout
    static let screenTopInset: CGFloat = 12
    static let groupedHorizontalInset: CGFloat = 20
    static let dashboardSpacing: CGFloat = 20
    static let insightsContentSpacing: CGFloat = 22
    static let wideContentMaxWidth: CGFloat = 1180
    static let readableContentMaxWidth: CGFloat = 760

    // Input flow layout
    static let flowHorizontalPadding: CGFloat = 20
    static let flowMaxContentWidth: CGFloat = 420
    static let flowSectionSpacing: CGFloat = 12
    static let flowHeaderTopPadding: CGFloat = 2
    static let flowHeaderControlSpacing: CGFloat = 8
    static let flowHeaderTitleSpacing: CGFloat = 4
    static let flowFooterTopPadding: CGFloat = 2
    static let flowFooterBottomPadding: CGFloat = 6
    static let flowExpandedControlBottomPadding: CGFloat = 80
    static let tileSpacing: CGFloat = 10
    static let pillSpacing: CGFloat = 8
    static let cardPadding: CGFloat = 16
    static let buttonTrailingIconPadding: CGFloat = 18
    static let pillVerticalPadding: CGFloat = 7
    static let secondaryButtonVerticalPadding: CGFloat = 14
    static let chevronTopPadding: CGFloat = 3
    static let selectedCheckOffsetX: CGFloat = 8
    static let selectedCheckOffsetY: CGFloat = -4
    static let painIntensityFaceEyeOffsetY: CGFloat = -4
    static let painIntensityFaceMouthOffsetY: CGFloat = 5
    static let painIntensityFaceEyeSpacing: CGFloat = 7

    // Home effects
    static let heroWavePrimaryOffsetX: CGFloat = -10
    static let heroWavePrimaryOffsetY: CGFloat = 18
    static let heroWaveSecondaryOffsetX: CGFloat = 6
    static let heroWaveSecondaryOffsetY: CGFloat = 24
    static let heroWaveAccentOffsetX: CGFloat = -8
    static let heroWaveAccentOffsetY: CGFloat = 28
    static let homeLiquidBackgroundPrimaryOffsetX: CGFloat = -160
    static let homeLiquidBackgroundPrimaryOffsetY: CGFloat = -260
    static let homeLiquidBackgroundSecondaryOffsetX: CGFloat = 170
    static let homeLiquidBackgroundSecondaryOffsetY: CGFloat = 260

    // Entry detail
    static let entryDetailBottomPadding: CGFloat = 76
    static let entryDetailHeroSpacing: CGFloat = 25
    static let entryDetailHeroPadding: CGFloat = 26
    static let entryDetailContextRowSpacing: CGFloat = 11
    static let entryDetailContextHorizontalPadding: CGFloat = 22
    static let entryDetailContextVerticalPadding: CGFloat = 10
    static let entryDetailContextRowVerticalPadding: CGFloat = 18
    static let entryDetailTriggerSectionSpacing: CGFloat = 14
    static let entryDetailTriggerCardPadding: CGFloat = 18
    static let entryDetailTriggerGridSpacing: CGFloat = 10
    static let entryDetailTriggerGridColumnSpacing: CGFloat = 9
    static let entryDetailTriggerChipHorizontalPadding: CGFloat = 15
    static let entryDetailTriggerChipVerticalPadding: CGFloat = 9
    static let entryDetailMedicationCardPadding: CGFloat = 22
    static let entryDetailDeleteBottomPadding: CGFloat = 38

    // Data sharing and export
    static let dataSharingContentBottomPadding: CGFloat = 132
    static let dataSharingBulletIndent: CGFloat = 30
    static let reportBottomPadding: CGFloat = 100
    static let settingsContentBottomPadding: CGFloat = 128
    static let settingsSafeAreaBottomPadding: CGFloat = 32
    static let settingsDividerLeadingPadding: CGFloat = 62

    // Symi Plus
    static let symiPlusContentSpacing: CGFloat = 20
    static let symiPlusFeatureSpacing: CGFloat = 12
    static let symiPlusCompactHorizontalPadding: CGFloat = 16
    static let symiPlusRegularHorizontalPadding: CGFloat = 24
    static let symiPlusContentTopPadding: CGFloat = 16
    static let symiPlusContentBottomPadding: CGFloat = 120
    static let symiPlusHeroSpacing: CGFloat = 16
    static let symiPlusHeroPadding: CGFloat = 20
    static let symiPlusBadgeHorizontalPadding: CGFloat = 12
    static let symiPlusBadgeVerticalPadding: CGFloat = 6
    static let symiPlusFeatureRowSpacing: CGFloat = 16
    static let symiPlusFeatureTextSpacing: CGFloat = 6
    static let symiPlusCardPadding: CGFloat = 16
    static let symiPlusBottomSpacing: CGFloat = 12
    static let symiPlusBottomTopPadding: CGFloat = 14
    static let symiPlusBottomPadding: CGFloat = 8
    static let symiPlusFooterTopPadding: CGFloat = 2
    static let symiPlusFooterLinkSpacing: CGFloat = 18
    static let symiPlusHeroImageOffsetY: CGFloat = 5
}

// MARK: - Radius

nonisolated enum SymiRadius {
    // Core surfaces
    static let card: CGFloat = 20
    static let button: CGFloat = 18
    static let chip: CGFloat = 12
    static let settingsIconContainer: CGFloat = 9

    // Feature surfaces
    static let homeActionButton: CGFloat = 22
    static let heroCard: CGFloat = 24
    static let glassSheetPanel: CGFloat = 32
    static let journalCard: CGFloat = 16
    static let journalAccentBar: CGFloat = 2

    // Input flow
    static let flowCard: CGFloat = 18
    static let flowTile: CGFloat = 14
    static let flowPill: CGFloat = 12
    static let flowBanner: CGFloat = 16
}

// MARK: - Shadow

enum SymiShadow {
    // Card shadows
    static let cardColor = AppTheme.symiPetrol.opacity(SymiOpacity.cardShadow)
    static let cardRadius: CGFloat = 12
    static let cardXOffset: CGFloat = 0
    static let cardYOffset: CGFloat = 5
    static let brandCardRadius: CGFloat = 14
    static let brandCardYOffset: CGFloat = 6
    static let journalCardRadius: CGFloat = 16
    static let journalCardXOffset: CGFloat = 0
    static let journalCardYOffset: CGFloat = 8

    // Text shadows
    static let heroTextRadius: CGFloat = 3
    static let heroTextYOffset: CGFloat = 1

    // Controls
    static let buttonColor = AppTheme.symiPetrol.opacity(SymiOpacity.shadow)
    static let buttonRadius: CGFloat = 8
    static let buttonXOffset: CGFloat = 0
    static let buttonYOffset: CGFloat = 6
    static let symiPlusCardRadius: CGFloat = 8
    static let symiPlusCardYOffset: CGFloat = 3
    static let symiPlusPrimaryButtonRadius: CGFloat = 10
    static let symiPlusPrimaryButtonYOffset: CGFloat = 5
    static let calendarButtonRadius: CGFloat = 7
    static let calendarButtonYOffset: CGFloat = 3
    static let sliderThumbRadius: CGFloat = 2
    static let sliderThumbYOffset: CGFloat = 1
}

// MARK: - Size

nonisolated enum SymiSize {
    // Core interaction and platform
    static let accessibilityMarker: CGFloat = 1
    static let minInteractiveHeight: CGFloat = 44
    static let defaultWindowWidth: CGFloat = 1280
    static let defaultWindowHeight: CGFloat = 800
    static let emptyStateMinHeight: CGFloat = 360

    // App shell and brand
    static let homeBrandLogoWidth: CGFloat = 140
    static let homeBrandLogoHeight: CGFloat = 68
    static let productInfoIconWidth: CGFloat = 28

    // Input flow controls
    static let flowHeaderControlHeight: CGFloat = 34
    static let primaryButtonHeight: CGFloat = 48
    static let progressIndicator: CGFloat = 22
    static let progressTrackHeight: CGFloat = 4
    static let progressTotalWidth: CGFloat = 44
    static let inputSelectionTileMinHeight: CGFloat = 78
    static let inputSelectionIconWidth: CGFloat = 34
    static let inputSelectionIconHeight: CGFloat = 30
    static let headacheLocationImageHeight: CGFloat = 64
    static let headacheLocationIconHeight: CGFloat = 26
    static let headacheLocationTileMinHeight: CGFloat = 112
    static let headachePresetMinHeight: CGFloat = 50
    static let headacheOptionGridMinWidth: CGFloat = 58
    static let headacheOptionGridColumnCount: Int = 4
    static let painSliderTouchHeight: CGFloat = 44
    static let painSliderTrackHeight: CGFloat = 5
    static let painSliderThumbSize: CGFloat = 24
    static let medicationRowMinHeight: CGFloat = 72
    static let selectedMedicationRowMinHeight: CGFloat = 108
    static let medicationQuantityMinWidth: CGFloat = 24
    static let noteEditorMinHeight: CGFloat = 220
    static let painIntensityFaceEye: CGFloat = 3.2
    static let painIntensityFaceMouthWidth: CGFloat = 15
    static let painIntensityFaceMouthHeight: CGFloat = 8
    static let painIntensityFaceOpenMouthWidth: CGFloat = 6

    // Grid and dashboard layout
    static let dashboardWideColumnMinWidth: CGFloat = 360
    static let dashboardColumnMinWidth: CGFloat = 320
    static let dashboardActionColumnMinWidth: CGFloat = 180
    static let historySidebarMinWidth: CGFloat = 420
    static let historySidebarMaxWidth: CGFloat = 560
    static let medicationGridMinWidth: CGFloat = 220
    static let multiSelectGridMinWidth: CGFloat = 140
    static let tagGridMinWidth: CGFloat = 120
    static let pillGridMinWidth: CGFloat = 70
    static let flowCompactTileGridMinWidth: CGFloat = 72
    static let flowTwoColumnTileGridMinWidth: CGFloat = 132

    // Status and calendar
    static let statusDot: CGFloat = 10
    static let settingsIconContainer: CGFloat = 32
    static let settingsAppleHealthIcon: CGFloat = 38
    static let settingsAppleHealthCardMinHeight: CGFloat = 78
    static let calendarDot: CGFloat = 9
    static let calendarPlaceholderHeight: CGFloat = 16
    static let calendarDayMinHeight: CGFloat = 52
    static let calendarWeekdayHeight: CGFloat = 44
    static let homeCalendarWeekdayHeight: CGFloat = 26
    static let homeCalendarNavigationButton: CGFloat = 50
    static let homeCalendarDayNumber: CGFloat = 36
    static let homeCalendarAccessibilityGrowth: CGFloat = 10
    static let homeCalendarDayAccessibilityGrowth: CGFloat = 14

    // Home
    static let quickEntryIcon: CGFloat = 58
    static let homeQuickEntryIcon: CGFloat = 48
    static let homeQuickEntryButtonMinHeight: CGFloat = 68
    static let homePainScaleSelectedSegmentHeight: CGFloat = 12
    static let homePainScaleSegmentHeight: CGFloat = 8
    static let homePainScaleBarHeight: CGFloat = 16
    static let quickEntryMinHeight: CGFloat = 108
    static let homePatternIcon: CGFloat = 34
    static let homePatternWideMinHeight: CGFloat = 138
    static let homePatternMinHeight: CGFloat = 168
    static let homePatternAccessibilityHeightGrowth: CGFloat = 54
    static let homePatternEmptyIcon: CGFloat = 38
    static let homeLiquidBackgroundPrimaryBlur: CGFloat = 70
    static let homeLiquidBackgroundSecondaryBlur: CGFloat = 86

    // Insights
    static let trendChartHeight: CGFloat = 88
    static let insightHeroIcon: CGFloat = 42
    static let insightTrendStripHeight: CGFloat = 142
    static let insightDotPatternHeight: CGFloat = 78
    static let insightAverageTrackHeight: CGFloat = 7
    static let insightCardHeaderIcon: CGFloat = 28
    static let insightShareTrackHeight: CGFloat = 6
    static let insightTrendPoint: CGFloat = 7
    static let insightPatternDot: CGFloat = 9

    // Review and hero artwork
    static let reviewStepIcon: CGFloat = 44
    static let reviewSummaryIcon: CGFloat = 42
    static let heroSymbolWidth: CGFloat = 90
    static let heroSymbolHeight: CGFloat = 120
    static let heroWavePrimaryHeight: CGFloat = 54
    static let heroWaveSecondaryHeight: CGFloat = 44
    static let heroWaveAccentWidth: CGFloat = 132
    static let heroWaveAccentHeight: CGFloat = 34

    // Entry detail
    static let entryDetailTopFadeHeight: CGFloat = 16
    static let entryDetailFaceBadge: CGFloat = 58
    static let entryDetailFaceIcon: CGFloat = 32
    static let entryDetailProgressBarHeight: CGFloat = 11
    static let entryDetailProgressHighlightHeight: CGFloat = 2
    static let entryDetailContextIcon: CGFloat = 32
    static let entryDetailTriggerGridMinWidth: CGFloat = 118
    static let entryDetailDeleteHeight: CGFloat = 54

    // Weather attribution
    static let weatherInlineLogoMaxWidth: CGFloat = 180
    static let weatherInlineLogoMinHeight: CGFloat = 28
    static let weatherInlineLogoMaxHeight: CGFloat = 48
    static let weatherFooterLogoMaxWidth: CGFloat = 220
    static let weatherFooterLogoMinHeight: CGFloat = 32
    static let weatherFooterLogoMaxHeight: CGFloat = 56

    // Data sharing and export
    static let dataSharingPrimaryButtonHeight: CGFloat = 52
    static let dataSharingBulletSize: CGFloat = 6
    static let reportHeroCompactHeight: CGFloat = 96
    static let reportHeroRegularHeight: CGFloat = 104
    static let reportHeroCompactMaxWidth: CGFloat = 300
    static let reportHeroRegularMaxWidth: CGFloat = 340
    static let reportDateRowMinHeight: CGFloat = 48
    static let reportFloatingButtonHeight: CGFloat = 100
    static let reportFadeHeight: CGFloat = 80

    // Journal
    static let journalAccentBarWidth: CGFloat = 4
    static let journalActiveFilterChipMinHeight: CGFloat = 34
    static let journalEntryCardMinHeight: CGFloat = 76
    static let journalEmptyStateMinHeight: CGFloat = 180

    // Symi Plus
    static let symiPlusContentMaxWidth: CGFloat = 780
    static let symiPlusHeroImage: CGFloat = 100
    static let symiPlusFeatureIcon: CGFloat = 44
    static let symiPlusFeatureMinHeight: CGFloat = 88
    static let symiPlusButtonHeight: CGFloat = 52
    static let symiPlusFooterMaxWidth: CGFloat = 260
    static let symiPlusSeparatorDot: CGFloat = 5
}

// MARK: - Stroke

nonisolated enum SymiStroke {
    // Core
    static let hairline: CGFloat = 1
    static let selectedHairline: CGFloat = 1.5
    static let painIntensityVeryHighSelectedBorder: CGFloat = 2
    static let symiPlusOutline: CGFloat = 1.2

    // Charts and artwork
    static let trendLine: CGFloat = 3
    static let heroWaveAccent: CGFloat = 4
    static let heroWaveSecondary: CGFloat = 5
    static let heroWavePrimary: CGFloat = 8

    // Entry detail
    static let entryDetailFaceIcon: CGFloat = 2
    static let painIntensityFace: CGFloat = 1.8
}

// MARK: - Animation

nonisolated enum SymiAnimation {
    static let quickDuration: TimeInterval = 0.18
}

// MARK: - Opacity

nonisolated enum SymiOpacity {
    // Absolute values
    static let entryDetailTopFadeEnd: Double = 0
    static let hiddenDebugControl: Double = 0.01
    static let opaque: Double = 1
    static let elevatedShadow: Double = 1.2

    // General surfaces and strokes
    static let clearStroke: Double = 0.04
    static let symiPlusLightShadow = clearStroke
    static let glassRegularShadow: Double = 0.045
    static let clearAccent: Double = 0.06
    static let journalBorder = clearAccent
    static let cardShadow: Double = 0.07
    static let journalShadow = cardShadow
    static let insightSecondaryFill = cardShadow
    static let hairline: Double = 0.08
    static let faintTrack = hairline
    static let glassProminentShadow = hairline
    static let shadow: Double = 0.10
    static let pressedShadow = shadow
    static let subtleButtonHighlight: Double = 0.11
    static let faintSurface: Double = 0.12
    static let painIntensitySelectedFill: Double = 0.15
    static let painIntensityVeryHighSelectedFill: Double = 0.18
    static let softFill: Double = 0.16
    static let symiPlusDarkShadow = softFill
    static let secondaryFill: Double = 0.18
    static let painIntensityLowFaceFill = secondaryFill
    static let sliderThumbShadow = secondaryFill
    static let pressedFill: Double = 0.20
    static let painIntensityMediumFaceFill = pressedFill
    static let backgroundAccent: Double = 0.22
    static let selectedStroke: Double = 0.24
    static let glassTintLight: Double = 0.26
    static let selectedFill: Double = 0.35
    static let painIntensitySelectedStroke = selectedFill
    static let outline: Double = 0.45
    static let symiPlusSecondaryPressedStroke: Double = 0.50
    static let painIntensityUnselectedStroke = outline
    static let disabledRow = outline
    static let painIntensityUnselectedIcon: Double = 0.60
    static let symiPlusFooterDot = painIntensityUnselectedIcon
    static let strongSurface: Double = 0.96
    static let footerBackground = strongSurface

    // Text and icons
    static let textMuted: Double = 0.50
    static let disabledContent: Double = 0.55
    static let iconMuted = disabledContent
    static let secondaryActionText: Double = 0.66
    static let textReadableSecondary: Double = 0.72
    static let strongText: Double = 0.82
    static let heroSecondaryText: Double = 0.86

    // Control state
    static let disabledFill = disabledContent
    static let disabledTile: Double = 0.58
    static let entryDetailDeletePressed: Double = 0.68
    static let journalSelectedStroke: Double = 0.80
    static let journalPressed: Double = 0.88
    static let symiPlusPrimaryPressed = journalPressed
    static let pressedContent: Double = 0.92
    static let reportPressedScale: Double = 0.99
    static let reportPrimaryPressedScale: Double = 0.98
    static let entryDetailDeleteScale = reportPrimaryPressedScale

    // Progress and selection
    static let progressTrackLight = faintSurface
    static let progressTrackDark = backgroundAccent
    static let progressIndicatorStrokeDark = secondaryFill
    static let progressIndicatorStrokeLight = pressedContent
    static let stepSelectedFillDark: Double = 0.30
    static let symiPlusSecondaryStroke = stepSelectedFillDark
    static let secondaryPressedFill: Double = 0.32
    static let symiPlusChevron: Double = 0.40
    static let stepBorderLight: Double = 0.36
    static let stepBorderDark: Double = 0.48

    // Brand, hero, and backgrounds
    static let heroSecondaryWave: Double = 0.72
    static let appBackgroundSurface = heroSecondaryWave
    static let heroPrimaryWave: Double = 0.82
    static let journalChipFill: Double = 0.84
    static let heroAccentWave: Double = 0.92
    static let glassBorderDarkMultiplier = backgroundAccent
    static let glassTintDark = secondaryFill
    static let homeActionShadowLight = shadow
    static let homeActionShadowDark: Double = 0.05
    static let homeBackgroundPrimaryLight: Double = 0.16
    static let homeBackgroundPrimaryDark = hairline
    static let homeBackgroundSecondaryLight = shadow
    static let homeBackgroundSecondaryDark: Double = 0.05

    // Calendar
    static let calendarHighIntensityDot = heroSecondaryWave
    static let calendarMediumIntensityDot = heroSecondaryWave
    static let calendarLowIntensityDot: Double = 0.62
    static let calendarInactiveDayText: Double = 0.60

    // Entry detail
    static let entryDetailShadow: Double = 0.022
    static let entryDetailHighlight: Double = 0.74
    static let entryDetailPrimaryText: Double = 0.98
    static let entryDetailBodyText = strongText
    static let entryDetailFaceStroke: Double = 0.60
    static let entryDetailProgressTrack: Double = 0.065
    static let entryDetailProgressStart = entryDetailPrimaryText
    static let entryDetailProgressEnd = entryDetailPrimaryText
    static let entryDetailProgressHighlight: Double = 0.14
    static let entryDetailIcon: Double = 0.62
    static let entryDetailTriggerChipText: Double = 0.84
    static let entryDetailTriggerChipFill = backgroundAccent
    static let entryDetailDeleteText: Double = 0.78
    static let entryDetailSecondaryText: Double = 0.84
    static let entryDetailTertiaryText = strongText

    // Report
    static let reportPrimaryPressedStart = journalPressed
    static let reportPrimaryRestingEnd: Double = 0.94
    static let reportPrimaryPressedEnd = strongText
}
