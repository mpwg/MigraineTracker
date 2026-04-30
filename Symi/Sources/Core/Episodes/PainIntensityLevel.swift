import Foundation

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
        switch self {
        case .none, .low:
            "Leicht"
        case .medium:
            "Mittel"
        case .high, .veryHigh:
            "Stark"
        }
    }

    nonisolated func contains(intensity: Int) -> Bool {
        self == PainIntensityLevel(intensity: intensity)
    }
}
