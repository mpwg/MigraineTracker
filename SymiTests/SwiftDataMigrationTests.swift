import Foundation
import SwiftData
import Testing
@testable import Symi

@MainActor
struct SwiftDataMigrationTests {
    @Test
    func migratesV4StoreToCurrentSchemaAndDropsDoctorData() throws {
        let storeURL = try makeStoreURL()
        let episodeID = UUID(uuidString: "15500000-0000-0000-0000-000000000004")!
        let weatherID = UUID(uuidString: "15500000-0000-0000-0000-000000000014")!

        do {
            let container = try makeContainer(schema: SymiSchemaV4.self, storeURL: storeURL)
            let context = ModelContext(container)
            let startedAt = Date(timeIntervalSince1970: 1_710_000_000)
            let episode = SymiSchemaV4.Episode(
                id: episodeID,
                startedAt: startedAt,
                endedAt: startedAt.addingTimeInterval(5_400),
                updatedAt: startedAt.addingTimeInterval(60),
                typeRaw: EpisodeType.migraine.rawValue,
                intensity: 8,
                painLocation: "Stirn",
                painCharacter: "Pulsierend",
                notes: "V4-Migration",
                symptomsStorage: "Übelkeit",
                triggersStorage: "Wetter",
                functionalImpact: "Ruhe nötig",
                menstruationStatusRaw: MenstruationStatus.none.rawValue
            )
            episode.medications = [
                SymiSchemaV4.MedicationEntry(
                    name: "Sumatriptan",
                    categoryRaw: MedicationCategory.triptan.rawValue,
                    dosage: "50 mg",
                    takenAt: startedAt.addingTimeInterval(1_200),
                    effectivenessRaw: MedicationEffectiveness.good.rawValue,
                    episode: episode
                )
            ]
            episode.weatherSnapshot = SymiSchemaV4.WeatherSnapshot(
                id: weatherID,
                recordedAt: startedAt,
                temperature: 17.5,
                condition: "Regen",
                humidity: 73,
                pressure: 1002,
                precipitation: 2.1,
                weatherCode: 63,
                source: "Apple Weather",
                episode: episode
            )

            let doctor = SymiSchemaV4.Doctor(
                name: "Dr. Migration",
                specialty: "Neurologie",
                city: "Wien"
            )
            let appointment = SymiSchemaV4.DoctorAppointment(
                scheduledAt: startedAt.addingTimeInterval(86_400),
                practiceName: "Praxis Migration",
                doctor: doctor
            )
            doctor.appointments = [appointment]

            context.insert(episode)
            context.insert(doctor)
            context.insert(SymiSchemaV4.DoctorDirectoryEntry(
                id: "legacy-doctor",
                name: "Legacy Praxis",
                specialty: "Neurologie",
                street: "Testgasse 1",
                city: "Wien",
                state: "Wien",
                sourceLabel: "Seed",
                sourceURL: "https://example.invalid"
            ))
            try context.save()
        }

        let migratedContainer = try makeCurrentContainer(storeURL: storeURL)
        let context = ModelContext(migratedContainer)
        let episodes = try context.fetch(FetchDescriptor<Episode>())

        #expect(episodes.count == 1)
        guard let episode = episodes.first else {
            Issue.record("Migrierte Episode fehlt.")
            return
        }

        #expect(episode.id == episodeID)
        #expect(episode.intensity == 8)
        #expect(episode.medications.first?.name == "Sumatriptan")
        #expect(episode.weatherSnapshot?.id == weatherID)
        #expect(episode.weatherSnapshot?.condition == "Regen")
        #expect(episode.continuousMedicationChecks.isEmpty)
    }

    @Test
    func migratesV5StoreToCurrentSchemaAndPreservesWeatherContext() throws {
        let storeURL = try makeStoreURL()
        let episodeID = UUID(uuidString: "15500000-0000-0000-0000-000000000005")!
        let startedAt = Date(timeIntervalSince1970: 1_720_000_000)
        let contextRangeStart = startedAt.addingTimeInterval(-43_200)
        let contextRangeEnd = startedAt.addingTimeInterval(129_600)
        let contextPoint = WeatherContextPointData(
            recordedAt: startedAt,
            condition: "Bewölkt",
            temperature: 19.2,
            humidity: 68,
            pressure: 1009,
            precipitation: 0.3,
            weatherCode: 3
        )

        do {
            let container = try makeContainer(schema: SymiSchemaV5.self, storeURL: storeURL)
            let context = ModelContext(container)
            let episode = SymiSchemaV5.Episode(
                id: episodeID,
                startedAt: startedAt,
                updatedAt: startedAt.addingTimeInterval(90),
                typeRaw: EpisodeType.headache.rawValue,
                intensity: 5,
                painLocation: "Schläfen",
                painCharacter: "Drückend",
                notes: "V5-Migration",
                symptomsStorage: "Lichtempfindlichkeit",
                triggersStorage: "Schlaf",
                functionalImpact: "Langsamer Tag",
                menstruationStatusRaw: MenstruationStatus.unknown.rawValue
            )
            episode.weatherSnapshot = SymiSchemaV5.WeatherSnapshot(
                recordedAt: startedAt,
                temperature: 19.2,
                condition: "Bewölkt",
                humidity: 68,
                pressure: 1009,
                precipitation: 0.3,
                weatherCode: 3,
                source: "Apple Weather",
                dayRangeStart: Calendar.current.startOfDay(for: startedAt),
                dayRangeEnd: Calendar.current.startOfDay(for: startedAt).addingTimeInterval(86_400),
                contextRangeStart: contextRangeStart,
                contextRangeEnd: contextRangeEnd,
                contextPointsStorage: WeatherSnapshot.encodeContextPoints([contextPoint]),
                episode: episode
            )

            context.insert(episode)
            try context.save()
        }

        let migratedContainer = try makeCurrentContainer(storeURL: storeURL)
        let context = ModelContext(migratedContainer)
        let episodes = try context.fetch(FetchDescriptor<Episode>())

        #expect(episodes.count == 1)
        let episode = try #require(episodes.first)
        #expect(episode.id == episodeID)
        #expect(episode.weatherSnapshot?.contextRangeStart == contextRangeStart)
        #expect(episode.weatherSnapshot?.contextRangeEnd == contextRangeEnd)
        #expect(episode.weatherSnapshot?.contextPoints == [contextPoint])
        #expect(episode.continuousMedicationChecks.isEmpty)
        #expect(try context.fetch(FetchDescriptor<ContinuousMedication>()).isEmpty)
    }
}

private func makeStoreURL() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: "SymiMigrationTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appending(path: "Symi.store")
}

private func makeContainer<SchemaType: VersionedSchema>(
    schema: SchemaType.Type,
    storeURL: URL
) throws -> ModelContainer {
    let schema = Schema(versionedSchema: SchemaType.self)
    let configuration = ModelConfiguration("migration-test", schema: schema, url: storeURL, cloudKitDatabase: .none)
    return try ModelContainer(for: schema, configurations: [configuration])
}

private func makeCurrentContainer(storeURL: URL) throws -> ModelContainer {
    let schema = Schema(versionedSchema: SymiSchemaV6.self)
    let configuration = ModelConfiguration("migration-test", schema: schema, url: storeURL, cloudKitDatabase: .none)
    return try ModelContainer(
        for: schema,
        migrationPlan: SymiMigrationPlan.self,
        configurations: [configuration]
    )
}
