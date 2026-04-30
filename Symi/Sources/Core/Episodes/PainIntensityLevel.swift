import Foundation

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

struct PainIntensityMetadata: Equatable, Sendable {
    let storedIntensity: Int
    let displayLabel: String
    let contextText: String?
    let detailDescription: String
    let colorToken: PainIntensityColorToken
    let faceExpression: PainIntensityFaceExpression
    let healthSeverity: PainIntensityHealthSeverity
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

    nonisolated var metadata: PainIntensityMetadata {
        switch self {
        case .none:
            PainIntensityMetadata(
                storedIntensity: 0,
                displayLabel: "Nicht bewertet",
                contextText: nil,
                detailDescription: "Die Intensität wurde für diesen Eintrag nicht bewertet.",
                colorToken: .none,
                faceExpression: .neutral,
                healthSeverity: .mild
            )
        case .low:
            PainIntensityMetadata(
                storedIntensity: 2,
                displayLabel: "Leicht",
                contextText: "Leichter Verlauf",
                detailDescription: "Die Schmerzen waren leicht und gut im Alltag einzuordnen.",
                colorToken: .low,
                faceExpression: .calm,
                healthSeverity: .mild
            )
        case .medium:
            PainIntensityMetadata(
                storedIntensity: 5,
                displayLabel: "Mittel",
                contextText: "Mittlerer Verlauf",
                detailDescription: "Die Schmerzen waren spürbar, aber noch gut auszuhalten.",
                colorToken: .medium,
                faceExpression: .neutral,
                healthSeverity: .moderate
            )
        case .high:
            PainIntensityMetadata(
                storedIntensity: 8,
                displayLabel: "Stark",
                contextText: "Starker Verlauf",
                detailDescription: "Die Schmerzen waren deutlich und haben viel Aufmerksamkeit gebraucht.",
                colorToken: .high,
                faceExpression: .strained,
                healthSeverity: .severe
            )
        case .veryHigh:
            PainIntensityMetadata(
                storedIntensity: 10,
                displayLabel: "Sehr stark",
                contextText: "Sehr starker Verlauf",
                detailDescription: "Die Schmerzen waren sehr stark und haben den Alltag deutlich eingeschränkt.",
                colorToken: .veryHigh,
                faceExpression: .intense,
                healthSeverity: .severe
            )
        }
    }

    nonisolated var storedIntensity: Int {
        metadata.storedIntensity
    }

    nonisolated var displayLabel: String {
        metadata.displayLabel
    }

    nonisolated var isHighImpact: Bool {
        self == .high || self == .veryHigh
    }

    nonisolated var faceExpression: PainIntensityFaceExpression {
        metadata.faceExpression
    }

    nonisolated var contextText: String? {
        metadata.contextText
    }

    nonisolated var detailDescription: String {
        metadata.detailDescription
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
        metadata.healthSeverity
    }

    nonisolated func contains(intensity: Int) -> Bool {
        self == PainIntensityLevel(intensity: intensity)
    }
}
