import Foundation

struct PainLocationMetadata: Equatable, Sendable {
    let storedValue: String
    let displayLabel: String
    let imageName: String
    let isVisibleInEntryFlow: Bool
}

nonisolated enum PainLocationOption: String, CaseIterable, Codable, Identifiable, Sendable {
    case forehead
    case temples
    case neck
    case oneSided
    case everywhere

    nonisolated var id: String { rawValue }

    nonisolated init(storageValue: String) {
        switch storageValue.trimmingCharacters(in: .whitespacesAndNewlines) {
        case Self.forehead.rawValue, "Stirn":
            self = .forehead
        case Self.temples.rawValue, "Schläfen":
            self = .temples
        case Self.neck.rawValue, "Nacken":
            self = .neck
        case Self.oneSided.rawValue, "Einseitig", "links frontal":
            self = .oneSided
        case Self.everywhere.rawValue, "Überall", "Oberkopf":
            self = .everywhere
        default:
            self = .temples
        }
    }

    nonisolated static var entryFlowCases: [PainLocationOption] {
        allCases.filter(\.metadata.isVisibleInEntryFlow)
    }

    nonisolated var metadata: PainLocationMetadata {
        switch self {
        case .forehead:
            PainLocationMetadata(
                storedValue: "Stirn",
                displayLabel: "Stirn",
                imageName: "PainLocationForehead",
                isVisibleInEntryFlow: true
            )
        case .temples:
            PainLocationMetadata(
                storedValue: "Schläfen",
                displayLabel: "Schläfen",
                imageName: "PainLocationTemples",
                isVisibleInEntryFlow: true
            )
        case .neck:
            PainLocationMetadata(
                storedValue: "Nacken",
                displayLabel: "Nacken",
                imageName: "PainLocationNeck",
                isVisibleInEntryFlow: false
            )
        case .oneSided:
            PainLocationMetadata(
                storedValue: "Einseitig",
                displayLabel: "Einseitig",
                imageName: "PainLocationLeftTemple",
                isVisibleInEntryFlow: true
            )
        case .everywhere:
            PainLocationMetadata(
                storedValue: "Überall",
                displayLabel: "Überall",
                imageName: "PainLocationCrown",
                isVisibleInEntryFlow: true
            )
        }
    }

    nonisolated var storedValue: String {
        metadata.storedValue
    }

    nonisolated var displayLabel: String {
        metadata.displayLabel
    }

    nonisolated var imageName: String {
        metadata.imageName
    }
}

struct EpisodeDayPartMetadata: Equatable, Sendable {
    let label: String
    let contextualLabel: String
    let symbolName: String
    let representativeHour: Int
}

nonisolated enum EpisodeSymptomOption: String, CaseIterable, Codable, Identifiable, Sendable {
    case nausea
    case lightSensitivity
    case soundSensitivity
    case aura
    case jawPain
    case throbbing

    nonisolated var id: String { rawValue }

    nonisolated init(storageValue: String) {
        switch storageValue.trimmingCharacters(in: .whitespacesAndNewlines) {
        case Self.nausea.rawValue, "Übelkeit":
            self = .nausea
        case Self.lightSensitivity.rawValue, "Lichtempfindlichkeit":
            self = .lightSensitivity
        case Self.soundSensitivity.rawValue, "Geräuschempfindlichkeit":
            self = .soundSensitivity
        case Self.aura.rawValue, "Aura":
            self = .aura
        case Self.jawPain.rawValue, "Kiefer-/Aufbissschmerz":
            self = .jawPain
        case Self.throbbing.rawValue, "Pochen, Pulsieren":
            self = .throbbing
        default:
            self = .aura
        }
    }

    nonisolated var displayLabel: String {
        switch self {
        case .nausea:
            "Übelkeit"
        case .lightSensitivity:
            "Lichtempfindlichkeit"
        case .soundSensitivity:
            "Geräuschempfindlichkeit"
        case .aura:
            "Aura"
        case .jawPain:
            "Kiefer-/Aufbissschmerz"
        case .throbbing:
            "Pochen, Pulsieren"
        }
    }
}

struct EpisodeTriggerMetadata: Equatable, Sendable {
    let displayLabel: String
    let symbolName: String
}

nonisolated enum EpisodeTriggerOption: String, CaseIterable, Codable, Identifiable, Sendable {
    case weather
    case stress
    case highWorkload
    case period
    case sleepDuration
    case sport
    case nutrition
    case screenTime
    case movement
    case fluids

    nonisolated var id: String { rawValue }

    nonisolated init(storageValue: String) {
        switch storageValue.trimmingCharacters(in: .whitespacesAndNewlines) {
        case Self.weather.rawValue, "Wetter":
            self = .weather
        case Self.stress.rawValue, "Stress":
            self = .stress
        case Self.highWorkload.rawValue, "Erhöhte Arbeitsbelastung", "erhöhte Arbeitsbelastung":
            self = .highWorkload
        case Self.period.rawValue, "Regel", "Zyklus":
            self = .period
        case Self.sleepDuration.rawValue, "Schlafdauer", "Schlaf", "Schlafmangel":
            self = .sleepDuration
        case Self.sport.rawValue, "Sport":
            self = .sport
        case Self.nutrition.rawValue, "Ernährung":
            self = .nutrition
        case Self.screenTime.rawValue, "Bildschirmzeit":
            self = .screenTime
        case Self.movement.rawValue, "Bewegung":
            self = .movement
        case Self.fluids.rawValue, "Flüssigkeit":
            self = .fluids
        default:
            self = .stress
        }
    }

    nonisolated static var entryFlowCases: [EpisodeTriggerOption] {
        [.stress, .weather, .sleepDuration, .nutrition, .screenTime, .period, .movement, .fluids]
    }

    nonisolated var metadata: EpisodeTriggerMetadata {
        switch self {
        case .weather:
            EpisodeTriggerMetadata(displayLabel: "Wetter", symbolName: "cloud.sun")
        case .stress:
            EpisodeTriggerMetadata(displayLabel: "Stress", symbolName: "brain.head.profile")
        case .highWorkload:
            EpisodeTriggerMetadata(displayLabel: "Erhöhte Arbeitsbelastung", symbolName: "briefcase")
        case .period:
            EpisodeTriggerMetadata(displayLabel: "Regel", symbolName: "drop")
        case .sleepDuration:
            EpisodeTriggerMetadata(displayLabel: "Schlafdauer", symbolName: "moon")
        case .sport:
            EpisodeTriggerMetadata(displayLabel: "Sport", symbolName: "figure.run")
        case .nutrition:
            EpisodeTriggerMetadata(displayLabel: "Ernährung", symbolName: "fork.knife.circle")
        case .screenTime:
            EpisodeTriggerMetadata(displayLabel: "Bildschirmzeit", symbolName: "ipad.landscape.and.iphone")
        case .movement:
            EpisodeTriggerMetadata(displayLabel: "Bewegung", symbolName: "figure.walk")
        case .fluids:
            EpisodeTriggerMetadata(displayLabel: "Flüssigkeit", symbolName: "waterbottle")
        }
    }

    nonisolated var displayLabel: String {
        metadata.displayLabel
    }

    nonisolated var symbolName: String {
        metadata.symbolName
    }
}
