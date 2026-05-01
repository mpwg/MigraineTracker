import Foundation
import SwiftData

enum SymiMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            SymiSchemaV1.self,
            SymiSchemaV2.self,
            SymiSchemaV3.self,
            SymiSchemaV4.self,
            SymiSchemaV5.self,
            SymiSchemaV6.self,
            SymiSchemaV7.self,
            SymiSchemaV8.self,
            SymiSchemaV9.self
        ]
    }
    static var stages: [MigrationStage] {
        [
            .custom(
                fromVersion: SymiSchemaV1.self,
                toVersion: SymiSchemaV2.self,
                willMigrate: nil,
                didMigrate: { context in
                    let episodes = try context.fetch(FetchDescriptor<SymiSchemaV2.Episode>())
                    for episode in episodes {
                        episode.updatedAt = episode.startedAt
                        episode.deletedAt = nil
                    }

                    let definitions = try context.fetch(FetchDescriptor<SymiSchemaV2.MedicationDefinition>())
                    for definition in definitions {
                        definition.updatedAt = definition.createdAt
                        definition.deletedAt = nil
                    }

                    try context.save()
                }
            ),
            .custom(
                fromVersion: SymiSchemaV2.self,
                toVersion: SymiSchemaV3.self,
                willMigrate: nil,
                didMigrate: { context in
                    let episodes = try context.fetch(FetchDescriptor<SymiSchemaV3.Episode>())
                    for episode in episodes {
                        episode.updatedAt = max(episode.updatedAt, episode.startedAt)
                    }

                    let weatherSnapshots = try context.fetch(FetchDescriptor<SymiSchemaV3.WeatherSnapshot>())
                    for snapshot in weatherSnapshots {
                        snapshot.precipitation = nil
                        snapshot.weatherCode = nil

                        let trimmedSource = snapshot.source.trimmingCharacters(in: .whitespacesAndNewlines)
                        snapshot.source = trimmedSource.isEmpty ? "Legacy manuell" : "Legacy: \(trimmedSource)"
                    }

                    try context.save()
                }
            ),
            .lightweight(
                fromVersion: SymiSchemaV3.self,
                toVersion: SymiSchemaV4.self
            ),
            .custom(
                fromVersion: SymiSchemaV4.self,
                toVersion: SymiSchemaV5.self,
                willMigrate: { context in
                    let appointments = try context.fetch(FetchDescriptor<SymiSchemaV4.DoctorAppointment>())
                    for appointment in appointments {
                        context.delete(appointment)
                    }

                    let doctors = try context.fetch(FetchDescriptor<SymiSchemaV4.Doctor>())
                    for doctor in doctors {
                        context.delete(doctor)
                    }

                    let directoryEntries = try context.fetch(FetchDescriptor<SymiSchemaV4.DoctorDirectoryEntry>())
                    for entry in directoryEntries {
                        context.delete(entry)
                    }

                    try context.save()
                },
                didMigrate: nil
            ),
            .lightweight(
                fromVersion: SymiSchemaV5.self,
                toVersion: SymiSchemaV6.self
            ),
            .custom(
                fromVersion: SymiSchemaV6.self,
                toVersion: SymiSchemaV7.self,
                willMigrate: { context in
                    let episodes = try context.fetch(FetchDescriptor<SymiSchemaV6.Episode>())
                    let migratedLevels = Dictionary(
                        uniqueKeysWithValues: episodes.map { episode in
                            (episode.id.uuidString, PainIntensityLevel(intensity: episode.intensity).rawValue)
                        }
                    )
                    let data = try JSONEncoder().encode(migratedLevels)
                    try data.write(to: v6IntensityLevelMigrationURL, options: [.atomic])
                },
                didMigrate: { context in
                    let migratedLevels: [String: String]
                    if let data = try? Data(contentsOf: v6IntensityLevelMigrationURL),
                       let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
                        migratedLevels = decoded
                    } else {
                        migratedLevels = [:]
                    }

                    let episodes = try context.fetch(FetchDescriptor<SymiSchemaV7.Episode>())
                    for episode in episodes {
                        episode.intensityLevelRaw = migratedLevels[episode.id.uuidString] ?? PainIntensityLevel.medium.rawValue
                    }
                    try? FileManager.default.removeItem(at: v6IntensityLevelMigrationURL)
                    try context.save()
                }
            ),
            .lightweight(
                fromVersion: SymiSchemaV7.self,
                toVersion: SymiSchemaV8.self
            ),
            .lightweight(
                fromVersion: SymiSchemaV8.self,
                toVersion: SymiSchemaV9.self
            )
        ]
    }

    private static var v6IntensityLevelMigrationURL: URL {
        FileManager.default.temporaryDirectory.appending(path: "symi-v6-intensity-level-migration.json")
    }
}
