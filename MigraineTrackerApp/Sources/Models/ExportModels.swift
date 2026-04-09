import Foundation

struct EpisodeExportRecord: Identifiable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date?
    let type: String
    let intensity: Int
    let symptoms: [String]
    let triggers: [String]
    let notes: String
    let functionalImpact: String
    let medications: [MedicationLine]
    let weather: WeatherLine?

    init(episode: Episode) {
        self.id = episode.id
        self.startedAt = episode.startedAt
        self.endedAt = episode.endedAt
        self.type = episode.type.rawValue
        self.intensity = episode.intensity
        self.symptoms = episode.symptoms
        self.triggers = episode.triggers
        self.notes = episode.notes
        self.functionalImpact = episode.functionalImpact
        self.medications = episode.medications.map {
            MedicationLine(
                name: $0.name,
                category: $0.category.rawValue,
                dosage: $0.dosage,
                effectiveness: $0.effectiveness.rawValue
            )
        }
        self.weather = episode.weatherSnapshot.map {
            WeatherLine(
                condition: $0.condition,
                temperature: $0.temperature,
                humidity: $0.humidity,
                pressure: $0.pressure,
                source: $0.source
            )
        }
    }

    struct MedicationLine: Identifiable {
        let id = UUID()
        let name: String
        let category: String
        let dosage: String
        let effectiveness: String
    }

    struct WeatherLine {
        let condition: String
        let temperature: Double?
        let humidity: Double?
        let pressure: Double?
        let source: String
    }
}

struct ExportPeriodSummary {
    let startDate: Date
    let endDate: Date
    let records: [EpisodeExportRecord]

    var episodeCount: Int { records.count }
    var averageIntensity: Double {
        ExportSummaryMetrics.averageIntensity(for: records.map(\.intensity))
    }

    var medicationNames: [String] {
        ExportSummaryMetrics.uniqueMedicationNames(from: records.map { $0.medications.map(\.name) })
    }
}
