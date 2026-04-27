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
    static let card = SymiColorValue(hex: 0xFFFFFF)
    static let textPrimary = SymiColorValue(hex: 0x1C1C1E)
    static let textSecondary = SymiColorValue(hex: 0x6B6B6E)

    static let triggerBlue = SymiColorValue(hex: 0x4A78D9)
    static let noteAmber = SymiColorValue(hex: 0xD18A2B)
    static let reviewPurple = SymiColorValue(hex: 0x8A65D6)
}
