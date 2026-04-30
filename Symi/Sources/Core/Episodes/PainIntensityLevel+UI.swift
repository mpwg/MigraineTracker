import SwiftUI

extension PainIntensityLevel {
    @MainActor var colorValue: SymiColorValue {
        SymiColorValue(hex: metadata.colorHex)
    }

    @MainActor var tintColor: Color {
        colorValue.color
    }

    @MainActor var selectedBackgroundColor: Color {
        tintColor.opacity(0.15)
    }

    @MainActor var selectedBorderColor: Color {
        tintColor.opacity(0.35)
    }

    @MainActor var selectedIconColor: Color {
        tintColor
    }

    @MainActor var unselectedIconColor: Color {
        Color.gray.opacity(0.4)
    }

    @MainActor var calendarDotColor: Color {
        switch self {
        case .none:
            tintColor.opacity(SymiOpacity.calendarLowIntensityDot)
        case .low:
            tintColor.opacity(SymiOpacity.calendarLowIntensityDot)
        case .medium:
            tintColor.opacity(SymiOpacity.calendarMediumIntensityDot)
        case .high, .veryHigh:
            tintColor.opacity(SymiOpacity.calendarHighIntensityDot)
        }
    }

    @MainActor var faceBackgroundColor: Color {
        switch self {
        case .none:
            ColorToken.Surface.iconBackground
        case .low:
            tintColor.opacity(0.18)
        case .medium:
            tintColor.opacity(0.20)
        case .high, .veryHigh:
            tintColor.opacity(SymiOpacity.clearAccent)
        }
    }
}
