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

    var hexString: String {
        "#\(Self.hexByte(red))\(Self.hexByte(green))\(Self.hexByte(blue))"
    }

    private static func hexByte(_ component: Double) -> String {
        let byte = min(max(Int((component * 255).rounded()), 0), 255)
        let digits = Array("0123456789ABCDEF")
        return String([digits[byte / 16], digits[byte % 16]])
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

    static let triggerBlue = SymiColorValue(hex: 0x4A78D9)
    static let noteAmber = SymiColorValue(hex: 0xD18A2B)
    static let reviewPurple = SymiColorValue(hex: 0x8A65D6)

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
