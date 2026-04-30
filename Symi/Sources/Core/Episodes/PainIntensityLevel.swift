import SwiftUI

enum PainIntensityHealthSeverity: Sendable {
    case mild
    case moderate
    case severe
}

enum PainIntensityFaceExpression: Sendable {
    case calm
    case neutral
    case strained
    case intense
}

nonisolated enum PainIntensityLevel: String, CaseIterable, Codable, Equatable, Sendable {
    case none
    case low
    case medium
    case high
    case veryHigh

    nonisolated init(intensity: Int) {
        switch intensity {
        case 1 ... 3:
            self = .low
        case 4 ... 6:
            self = .medium
        case 7 ... 8:
            self = .high
        case 9 ... 10:
            self = .veryHigh
        default:
            self = .none
        }
    }

    nonisolated init(storageValue: String) {
        switch storageValue {
        case Self.low.rawValue, "leicht", "Leicht":
            self = .low
        case Self.medium.rawValue, "mittel", "Mittel":
            self = .medium
        case Self.high.rawValue, "stark", "Stark":
            self = .high
        case Self.veryHigh.rawValue, "very_high", "sehrStark", "Sehr stark", "Sehr Stark":
            self = .veryHigh
        default:
            self = .none
        }
    }

    nonisolated static var selectableCases: [PainIntensityLevel] {
        [.low, .medium, .high, .veryHigh]
    }

    nonisolated var storedIntensity: Int {
        switch self {
        case .none:
            0
        case .low:
            2
        case .medium:
            5
        case .high:
            8
        case .veryHigh:
            10
        }
    }

    nonisolated var displayLabel: String {
        switch self {
        case .none:
            "Nicht bewertet"
        case .low:
            "Leicht"
        case .medium:
            "Mittel"
        case .high:
            "Stark"
        case .veryHigh:
            "Sehr stark"
        }
    }

    @MainActor var colorValue: SymiColorValue {
        switch self {
        case .none:
            SymiColors.textSecondary
        case .low:
            SymiColorValue(hex: 0xA4B1A0)
        case .medium:
            SymiColorValue(hex: 0xF6B78D)
        case .high:
            SymiColorValue(hex: 0xF29C7D)
        case .veryHigh:
            SymiColorValue(hex: 0xE6867C)
        }
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
            SymiColors.textSecondary.color.opacity(SymiOpacity.calendarLowIntensityDot)
        case .low:
            tintColor.opacity(SymiOpacity.calendarLowIntensityDot)
        case .medium:
            tintColor.opacity(SymiOpacity.calendarMediumIntensityDot)
        case .high, .veryHigh:
            tintColor.opacity(SymiOpacity.calendarHighIntensityDot)
        }
    }

    nonisolated var isHighImpact: Bool {
        self == .high || self == .veryHigh
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

    nonisolated var faceExpression: PainIntensityFaceExpression {
        switch self {
        case .none, .medium:
            .neutral
        case .low:
            .calm
        case .high:
            .strained
        case .veryHigh:
            .intense
        }
    }

    nonisolated var contextText: String? {
        switch self {
        case .none:
            nil
        case .low:
            "Leichter Verlauf"
        case .medium:
            "Mittlerer Verlauf"
        case .high:
            "Starker Verlauf"
        case .veryHigh:
            "Sehr starker Verlauf"
        }
    }

    nonisolated var detailDescription: String {
        switch self {
        case .none:
            "Die Intensität wurde für diesen Eintrag nicht bewertet."
        case .low:
            "Die Schmerzen waren leicht und gut im Alltag einzuordnen."
        case .medium:
            "Die Schmerzen waren spürbar, aber noch gut auszuhalten."
        case .high:
            "Die Schmerzen waren deutlich und haben viel Aufmerksamkeit gebraucht."
        case .veryHigh:
            "Die Schmerzen waren sehr stark und haben den Alltag deutlich eingeschränkt."
        }
    }

    nonisolated var healthSeverityLabel: String {
        switch healthSeverity {
        case .mild:
            "Leicht"
        case .moderate:
            "Mittel"
        case .severe:
            "Stark"
        }
    }

    nonisolated var healthSeverity: PainIntensityHealthSeverity {
        switch self {
        case .none, .low:
            .mild
        case .medium:
            .moderate
        case .high, .veryHigh:
            .severe
        }
    }

    nonisolated func contains(intensity: Int) -> Bool {
        self == PainIntensityLevel(intensity: intensity)
    }
}
