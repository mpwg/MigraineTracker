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
        PainIntensityLevel(intensity: intensity).displayLabel
    }

    static func intensityColor(for intensity: Int) -> Color {
        switch PainIntensityLevel(intensity: intensity) {
        case .low:
            SymiColors.intensityLight.color
        case .medium:
            SymiColors.intensityMedium.color
        case .high, .veryHigh:
            SymiColors.intensityStrong.color
        case .none:
            SymiColors.textPrimary.color
        }
    }

    static func timeOfDay(for date: Date, calendar: Calendar = .current) -> String {
        EpisodeDayPart(date: date, calendar: calendar).contextualLabel
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
        PainIntensityLevel(intensity: intensity).contextText
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
