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

    private static func hexByte(_ component: Double) -> String {
        let byte = min(max(Int((component * 255).rounded()), 0), 255)
        let digits = Array("0123456789ABCDEF")
        return String([digits[byte / 16], digits[byte % 16]])
    }
}

nonisolated enum PainLevel: Sendable {
    case none
    case low
    case medium
    case high

    init(intensity: Int) {
        switch intensity {
        case 1 ... 3:
            self = .low
        case 4 ... 6:
            self = .medium
        case 7 ... 10:
            self = .high
        default:
            self = .none
        }
    }
}

enum SymiColors {
    static let primaryPetrol = SymiColorValue(hex: 0x0F3D3E)
    static let sage = SymiColorValue(hex: 0x8ECDB8)
    static let coral = SymiColorValue(hex: 0xFF8A7A)
    static let warmBackground = SymiColorValue(hex: 0xF6F4EF)
    static let card = SymiColorValue(hex: 0xFFFEFB)
    static let textPrimary = SymiColorValue(hex: 0x1C1C1E)
    static let textSecondary = SymiColorValue(hex: 0x6B6B6E)
    static let mist = SymiColorValue(hex: 0xECF7F4)
    static let onAccent = SymiColorValue(hex: 0xFFFFFF)

    static let journalInk = SymiColorValue(hex: 0x143F3F)
    static let journalTextSecondary = SymiColorValue(hex: 0x68706D)
    static let journalSelectedChipFill = SymiColorValue(hex: 0xDDEFE7)
    static let intensityLight = SymiColorValue(hex: 0x4E9D7D)
    static let intensityMedium = SymiColorValue(hex: 0xC1842F)
    static let intensityStrong = SymiColorValue(hex: 0xD85C4A)

    static let triggerBlue = SymiColorValue(hex: 0x4A78D9)
    static let noteAmber = SymiColorValue(hex: 0xD18A2B)
    static let reviewPurple = SymiColorValue(hex: 0x8A65D6)
    static let entryDetailCard = SymiColorValue(hex: 0xFFFFFB)
    static let entryDetailIconFill = SymiColorValue(hex: 0xECF3E4)
    static let entryDetailFaceFill = SymiColorValue(hex: 0xF6EAD5)
    static let entryDetailProgressWarmMid = SymiColorValue(hex: 0xE6BA75)
    static let entryDetailProgressSageMid = SymiColorValue(hex: 0xC2D19E)

    static let petrolDark = SymiColorValue(hex: 0x8ECDB8)
    static let coralDark = SymiColorValue(hex: 0xFFA196)
    static let sageDark = SymiColorValue(hex: 0xA9DEC9)
    static let triggerBlueDark = SymiColorValue(hex: 0x81A0F1)
    static let noteAmberDark = SymiColorValue(hex: 0xF0B867)
    static let reviewPurpleDark = SymiColorValue(hex: 0xB096F2)

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

enum ColorToken {
    enum Text {
        static let primary = SymiColors.textPrimary.color.opacity(SymiOpacity.entryDetailPrimaryText)
        static let secondary = SymiColors.textPrimary.color.opacity(SymiOpacity.entryDetailSecondaryText)
        static let tertiary = SymiColors.textSecondary.color.opacity(SymiOpacity.entryDetailTertiaryText)
        static let label = SymiColors.textSecondary.color
        static let onSurface = SymiColors.textPrimary.color
        static let destructive = SymiColors.intensityStrong.color.opacity(SymiOpacity.entryDetailDeleteText)
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
        static func token(for level: PainLevel) -> PainToken {
            PainToken(level: level)
        }
    }
}

struct PainToken {
    let level: PainLevel

    var foreground: Color {
        baseValue.color
    }

    var icon: Color {
        baseValue.color.opacity(SymiOpacity.entryDetailIcon)
    }

    var emphasizedText: Color {
        level == .high ? foreground : ColorToken.Text.primary
    }

    var descriptionText: Color {
        level == .high ? foreground : ColorToken.Text.secondary
    }

    var faceBackground: Color {
        switch level {
        case .none:
            ColorToken.Surface.iconBackground
        case .low:
            SymiColors.entryDetailIconFill.color
        case .medium:
            SymiColors.entryDetailFaceFill.color
        case .high:
            SymiColors.coral.color.opacity(SymiOpacity.clearAccent)
        }
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
        switch level {
        case .none:
            SymiColors.textSecondary
        case .low:
            SymiColors.intensityLight
        case .medium:
            SymiColors.intensityMedium
        case .high:
            SymiColors.intensityStrong
        }
    }

    private var darkerValue: SymiColorValue {
        baseValue.mixed(with: SymiColors.primaryPetrol, amount: SymiOpacity.clearAccent)
    }

    private var lighterValue: SymiColorValue {
        baseValue.mixed(with: SymiColors.onAccent, amount: SymiOpacity.backgroundAccent)
    }
}
