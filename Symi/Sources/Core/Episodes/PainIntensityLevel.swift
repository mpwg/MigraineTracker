import Foundation

nonisolated enum PainIntensityLevel: CaseIterable, Equatable, Sendable {
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
