import SwiftUI

enum JournalEntryContext {
    static func title(for episode: EpisodeRecord) -> String {
        "\(intensityLabel(for: episode.intensity)) • \(episode.intensity)/10"
    }

    static func subtitle(for episode: EpisodeRecord) -> String {
        if !episode.notes.trimmed.isEmpty {
            return episode.notes.trimmed
        }

        let contextSegments = contextualSubtitleSegments(for: episode)
        guard !contextSegments.isEmpty else {
            return "Keine weiteren Details"
        }

        return contextSegments.prefix(2).joined(separator: " • ")
    }

    static func intensityLabel(for intensity: Int) -> String {
        switch intensity {
        case 1 ... 3:
            "Leicht"
        case 4 ... 6:
            "Mittel"
        case 7 ... 10:
            "Stark"
        default:
            "Nicht bewertet"
        }
    }

    static func intensityColor(for intensity: Int) -> Color {
        switch intensity {
        case 1 ... 3:
            SymiColors.intensityLight.color
        case 4 ... 6:
            SymiColors.intensityMedium.color
        case 7 ... 10:
            SymiColors.intensityStrong.color
        default:
            SymiColors.textPrimary.color
        }
    }

    static func timeOfDay(for date: Date, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)

        return switch hour {
        case 5 ..< 11:
            "Am Morgen"
        case 11 ..< 17:
            "Am Nachmittag"
        case 17 ..< 22:
            "Am Abend"
        default:
            "In der Nacht"
        }
    }

    static func medicationSummary(for episode: EpisodeRecord) -> String? {
        if let medicationName = acuteMedicationNames(for: episode).first {
            return "\(medicationName) genommen"
        }

        if let medicationName = continuousMedicationNames(for: episode).first {
            return "Medikation erfasst: \(medicationName)"
        }

        return nil
    }

    static func medicationDetail(for episode: EpisodeRecord) -> String? {
        let medicationNames = acuteMedicationNames(for: episode) + continuousMedicationNames(for: episode)
        guard !medicationNames.isEmpty else {
            return nil
        }

        return medicationNames.prefix(3).joined(separator: ", ")
    }

    static func intensityContext(for intensity: Int) -> String? {
        switch intensity {
        case 1 ... 3:
            "Leichter Verlauf"
        case 4 ... 6:
            "Mittlerer Verlauf"
        case 7 ... 10:
            "Starker Verlauf"
        default:
            nil
        }
    }

    private static func contextualSubtitleSegments(for episode: EpisodeRecord) -> [String] {
        var segments: [String] = []

        if !episode.painLocation.trimmed.isEmpty {
            segments.append(episode.painLocation.trimmed)
        }

        if let medicationSummary = medicationSummary(for: episode) {
            segments.append(medicationSummary)
        }

        segments.append(timeOfDay(for: episode.startedAt))

        if let intensityContext = intensityContext(for: episode.intensity) {
            segments.append(intensityContext)
        }

        return segments
    }

    private static func acuteMedicationNames(for episode: EpisodeRecord) -> [String] {
        episode.medications
            .map(\.name)
            .map(\.trimmed)
            .filter { !$0.isEmpty }
    }

    private static func continuousMedicationNames(for episode: EpisodeRecord) -> [String] {
        episode.continuousMedicationChecks
            .filter(\.wasTaken)
            .map(\.name)
            .map(\.trimmed)
            .filter { !$0.isEmpty }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
