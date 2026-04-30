import SwiftUI

struct SymiColorValue: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(hex: Int) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
    }

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    func mixed(with other: SymiColorValue, amount: Double) -> SymiColorValue {
        let clampedAmount = min(max(amount, 0), 1)
        let inverseAmount = 1 - clampedAmount
        return SymiColorValue(
            red: red * inverseAmount + other.red * clampedAmount,
            green: green * inverseAmount + other.green * clampedAmount,
            blue: blue * inverseAmount + other.blue * clampedAmount
        )
    }

    var hexString: String {
        "#\(Self.hexByte(red))\(Self.hexByte(green))\(Self.hexByte(blue))"
    }

    var hexValue: Int {
        (Self.byte(red) << 16) + (Self.byte(green) << 8) + Self.byte(blue)
    }

    private static func hexByte(_ component: Double) -> String {
        let byte = byte(component)
        let digits = Array("0123456789ABCDEF")
        return String([digits[byte / 16], digits[byte % 16]])
    }

    private static func byte(_ component: Double) -> Int {
        min(max(Int((component * 255).rounded()), 0), 255)
    }
}

enum SymiColors {
    // Brand palette
    static let primaryPetrol = SymiColorValue(hex: 0x0F3D3E)
    static let sage = SymiColorValue(hex: 0x8ECDB8)
    static let coral = SymiColorValue(hex: 0xFF8A7A)

    // Core surfaces and text
    static let warmBackground = SymiColorValue(hex: 0xF6F4EF)
    static let card = SymiColorValue(hex: 0xFFFEFB)
    static let textPrimary = SymiColorValue(hex: 0x1C1C1E)
    static let textSecondary = SymiColorValue(hex: 0x6B6B6E)
    static let mist = SymiColorValue(hex: 0xECF7F4)
    static let onAccent = SymiColorValue(hex: 0xFFFFFF)

    // Journal
    static let journalInk = SymiColorValue(hex: 0x143F3F)
    static let journalSelectedChipFill = SymiColorValue(hex: 0xDDEFE7)

    // Input flow accents
    static let triggerBlue = SymiColorValue(hex: 0x4A78D9)
    static let noteAmber = SymiColorValue(hex: 0xD18A2B)
    static let reviewPurple = SymiColorValue(hex: 0x8A65D6)

    // Entry detail
    static let entryDetailCard = SymiColorValue(hex: 0xFFFFFB)
    static let entryDetailIconFill = SymiColorValue(hex: 0xECF3E4)
    static let entryDetailFaceFill = SymiColorValue(hex: 0xF6EAD5)
    static let entryDetailProgressWarmMid = SymiColorValue(hex: 0xE6BA75)
    static let entryDetailProgressSageMid = SymiColorValue(hex: 0xC2D19E)

    // Pain intensity
    static let painIntensityNone = SymiColorValue(hex: 0x6B6B6E)
    static let painIntensityLow = SymiColorValue(hex: 0xA7B8B2)
    static let painIntensityMedium = SymiColorValue(hex: 0xE7C29D)
    static let painIntensityHigh = SymiColorValue(hex: 0xF19A7A)
    static let painIntensityVeryHigh = SymiColorValue(hex: 0xE3746A)

    // Dark mode accents
    static let petrolDark = sage
    static let coralDark = SymiColorValue(hex: 0xFFA196)
    static let sageDark = SymiColorValue(hex: 0xA9DEC9)
    static let triggerBlueDark = SymiColorValue(hex: 0x81A0F1)
    static let noteAmberDark = SymiColorValue(hex: 0xF0B867)
    static let reviewPurpleDark = SymiColorValue(hex: 0xB096F2)

    // Dark mode surfaces and text
    static let darkBackgroundTop = SymiColorValue(hex: 0x14171A)
    static let darkBackgroundMiddle = SymiColorValue(hex: 0x0F1A1A)
    static let darkBackgroundBottom = SymiColorValue(hex: 0x1A1714)
    static let darkCardBackground = SymiColorValue(hex: 0x202629)
    static let darkTextPrimary = SymiColorValue(hex: 0xF5F7F6)
    static let darkTextSecondary = SymiColorValue(hex: 0xC5CFCC)

    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkCardBackground.color : card.color
    }

    static func textPrimary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkTextPrimary.color : textPrimary.color
    }

    static func textSecondary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkTextSecondary.color : textSecondary.color
    }

    static func elevatedCard(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkCardBackground.color : card.color
    }

    static func subtleSeparator(for colorScheme: ColorScheme) -> Color {
        Color.primary.opacity(colorScheme == .dark ? SymiOpacity.softFill : SymiOpacity.hairline)
    }
}

// MARK: - Semantic Color Tokens

enum PainIntensityColorToken: Sendable {
    case none
    case low
    case medium
    case high
    case veryHigh
}

enum ColorToken {
    enum Text {
        static let primary = SymiColors.textPrimary.color.opacity(SymiOpacity.entryDetailPrimaryText)
        static let secondary = SymiColors.textPrimary.color.opacity(SymiOpacity.entryDetailSecondaryText)
        static let tertiary = SymiColors.textSecondary.color.opacity(SymiOpacity.entryDetailTertiaryText)
        static let label = SymiColors.textSecondary.color
        static let onSurface = SymiColors.textPrimary.color
        static let destructive = SymiColors.coral.color.opacity(SymiOpacity.entryDetailDeleteText)
    }

    enum Surface {
        static let appBackground = SymiColors.warmBackground.color
        static let primary = SymiColors.entryDetailCard.color
        static let headerControlBackground = SymiColors.onAccent.color
        static let cardHighlight = SymiColors.onAccent.color.opacity(SymiOpacity.entryDetailHighlight)
        static let iconBackground = SymiColors.entryDetailIconFill.color
        static let progressTrack = SymiColors.textPrimary.color.opacity(SymiOpacity.entryDetailProgressTrack)
        static let progressHighlight = SymiColors.onAccent.color.opacity(SymiOpacity.entryDetailProgressHighlight)
        static let topFade = LinearGradient(
            colors: [
                SymiColors.warmBackground.color,
                SymiColors.warmBackground.color.opacity(SymiOpacity.entryDetailTopFadeEnd)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    enum Shadow {
        static let card = SymiColors.primaryPetrol.color.opacity(SymiOpacity.entryDetailShadow)
    }

    enum Brand {
        static let primary = SymiColors.primaryPetrol.color
    }

    enum Journal {
        static let background = ColorToken.Surface.appBackground
        static let card = SymiColors.onAccent.color
        static let accent = SymiColors.sage.color
        static let ink = SymiColors.journalInk.color
        static let primaryText = SymiColors.textPrimary.color
        static let secondaryText = SymiColors.textSecondary.color
        static let border = Color.primary.opacity(SymiOpacity.journalBorder)
        static let chipFill = SymiColors.onAccent.color.opacity(SymiOpacity.journalChipFill)
        static let selectedChipFill = SymiColors.journalSelectedChipFill.color
        static let shadow = Color.primary.opacity(SymiOpacity.journalShadow)
    }

    enum Neutral {
        static let icon = SymiColors.primaryPetrol.color.opacity(SymiOpacity.entryDetailIcon)
    }

    enum Medication {
        static let foreground = SymiColors.sage.color
    }

    enum Trigger {
        static let foreground = SymiColors.textPrimary.color.opacity(SymiOpacity.entryDetailTriggerChipText)
        static let background = SymiColors.sage.color.opacity(SymiOpacity.entryDetailTriggerChipFill)
    }

    enum Pain {
        static func token(forIntensity intensity: Int) -> PainToken {
            PainToken(level: PainIntensityLevel(intensity: intensity))
        }

        static func token(for level: PainIntensityLevel) -> PainToken {
            PainToken(level: level)
        }

        static func colorValue(for token: PainIntensityColorToken) -> SymiColorValue {
            switch token {
            case .none:
                SymiColors.painIntensityNone
            case .low:
                SymiColors.painIntensityLow
            case .medium:
                SymiColors.painIntensityMedium
            case .high:
                SymiColors.painIntensityHigh
            case .veryHigh:
                SymiColors.painIntensityVeryHigh
            }
        }

        static func colorHex(for token: PainIntensityColorToken) -> Int {
            colorValue(for: token).hexValue
        }
    }
}

// MARK: - Pain Tokens

struct PainToken {
    let level: PainIntensityLevel

    var foreground: Color {
        baseValue.color
    }

    var colorHex: Int {
        ColorToken.Pain.colorHex(for: level.metadata.colorToken)
    }

    var icon: Color {
        baseValue.color.opacity(SymiOpacity.entryDetailIcon)
    }

    var emphasizedText: Color {
        level.isHighImpact ? foreground : ColorToken.Text.primary
    }

    var descriptionText: Color {
        level.isHighImpact ? foreground : ColorToken.Text.secondary
    }

    var faceBackground: Color {
        level.faceBackgroundColor
    }

    var progressGradient: LinearGradient {
        LinearGradient(
            colors: [
                darkerValue.color,
                lighterValue.color
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var baseValue: SymiColorValue {
        ColorToken.Pain.colorValue(for: level.metadata.colorToken)
    }

    private var darkerValue: SymiColorValue {
        baseValue.mixed(with: SymiColors.primaryPetrol, amount: SymiOpacity.clearAccent)
    }

    private var lighterValue: SymiColorValue {
        baseValue.mixed(with: SymiColors.onAccent, amount: SymiOpacity.backgroundAccent)
    }
}
