import Foundation

nonisolated struct EpisodeExportRecord: Identifiable, Sendable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date?
    let type: String
    let intensity: Int
    let painLocation: String
    let painCharacter: String
    let menstruationStatus: String
    let symptoms: [String]
    let triggers: [String]
    let notes: String
    let functionalImpact: String
    let medications: [MedicationLine]
    let weather: WeatherLine?
    let healthContext: HealthLine?

    nonisolated init(episode: Episode, healthContext: HealthContextRecord?) {
        self.id = episode.id
        self.startedAt = episode.startedAt
        self.endedAt = episode.endedAt
        self.type = episode.type.rawValue
        self.intensity = episode.intensity
        self.painLocation = episode.painLocation
        self.painCharacter = episode.painCharacter
        self.menstruationStatus = episode.menstruationStatus.rawValue
        self.symptoms = episode.symptoms
        self.triggers = episode.triggers
        self.notes = episode.notes
        self.functionalImpact = episode.functionalImpact
        self.medications = episode.medications.map {
            MedicationLine(
                name: $0.name,
                category: $0.category.rawValue,
                dosage: $0.dosage,
                quantity: $0.quantity,
                effectiveness: $0.effectiveness.rawValue
            )
        }
        self.weather = episode.weatherSnapshot.map {
            WeatherLine(
                condition: $0.condition,
                temperature: $0.temperature,
                humidity: $0.humidity,
                pressure: $0.pressure,
                precipitation: $0.precipitation,
                weatherCode: $0.weatherCode,
                source: $0.source
            )
        }
        self.healthContext = healthContext.map(HealthLine.init)
    }

    nonisolated struct MedicationLine: Identifiable, Sendable {
        let id = UUID()
        let name: String
        let category: String
        let dosage: String
        let quantity: Int
        let effectiveness: String
    }

    nonisolated struct WeatherLine: Sendable {
        let condition: String
        let temperature: Double?
        let humidity: Double?
        let pressure: Double?
        let precipitation: Double?
        let weatherCode: Int?
        let source: String
    }

    nonisolated struct HealthLine: Sendable {
        let recordedAt: Date
        let source: String
        let sleepMinutes: Double?
        let stepCount: Int?
        let averageHeartRate: Double?
        let restingHeartRate: Double?
        let heartRateVariability: Double?
        let menstrualFlow: String?
        let symptoms: [String]

        nonisolated init(record: HealthContextRecord) {
            self.recordedAt = record.recordedAt
            self.source = record.source
            self.sleepMinutes = record.sleepMinutes
            self.stepCount = record.stepCount
            self.averageHeartRate = record.averageHeartRate
            self.restingHeartRate = record.restingHeartRate
            self.heartRateVariability = record.heartRateVariability
            self.menstrualFlow = record.menstrualFlow
            self.symptoms = record.symptoms.map { "\($0.type.displayName): \($0.severity)" }
        }
    }
}

nonisolated struct ExportPeriodSummary: Sendable {
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
