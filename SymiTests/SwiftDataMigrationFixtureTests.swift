import Foundation
import SwiftData
import Testing
@testable import Symi

@MainActor
struct SwiftDataMigrationFixtureTests {
    @Test
    func migratesProductiveV1FixtureToCurrentSchema() throws {
        let result = try migrateFixture(schema: SymiSchemaV1.self, seed: SwiftDataMigrationFixture.seedV1)
        try assertCurrentStoreMatchesFixture(result)
    }

    @Test
    func migratesProductiveV2FixtureToCurrentSchema() throws {
        let result = try migrateFixture(schema: SymiSchemaV2.self, seed: SwiftDataMigrationFixture.seedV2)
        try assertCurrentStoreMatchesFixture(result)
    }

    @Test
    func migratesProductiveV3FixtureToCurrentSchema() throws {
        let result = try migrateFixture(schema: SymiSchemaV3.self, seed: SwiftDataMigrationFixture.seedV3)
        try assertCurrentStoreMatchesFixture(result)
    }

    @Test
    func migratesProductiveV4FixtureToCurrentSchema() throws {
        let result = try migrateFixture(schema: SymiSchemaV4.self, seed: SwiftDataMigrationFixture.seedV4)
        try assertCurrentStoreMatchesFixture(result)

        let context = ModelContext(result.container)
        #expect(try context.fetch(FetchDescriptor<Episode>()).count == 1)
    }

    @Test
    func migratesProductiveV5FixtureToCurrentSchema() throws {
        let result = try migrateFixture(schema: SymiSchemaV5.self, seed: SwiftDataMigrationFixture.seedV5)
        try assertCurrentStoreMatchesFixture(result)

        let context = ModelContext(result.container)
        let episode = try #require(try context.fetch(FetchDescriptor<Episode>()).first)
        #expect(episode.weatherSnapshot?.contextRangeStart == result.expectation.contextRangeStart)
        #expect(episode.weatherSnapshot?.contextRangeEnd == result.expectation.contextRangeEnd)
        #expect(episode.weatherSnapshot?.contextPoints == result.expectation.contextPoints)
    }

    @Test
    func opensProductiveV6FixtureWithCurrentSchema() throws {
        let result = try migrateFixture(schema: SymiSchemaV6.self, seed: SwiftDataMigrationFixture.seedV6)
        try assertCurrentStoreMatchesFixture(result)

        let context = ModelContext(result.container)
        #expect(try context.fetch(FetchDescriptor<ContinuousMedication>()).count == 1)
        let episode = try #require(try context.fetch(FetchDescriptor<Episode>()).first)
        #expect(episode.continuousMedicationChecks.first?.name == "Magnesium")
    }
}

private enum SwiftDataMigrationFixture {
    static func seedV1(_ context: ModelContext) -> MigrationFixtureExpectation {
        let dates = FixtureDates(offset: 1)
        let episode = SymiSchemaV1.Episode(
            id: UUID(uuidString: "23100000-0000-0000-0000-000000000001")!,
            startedAt: dates.startedAt,
            endedAt: dates.endedAt,
            typeRaw: EpisodeType.migraine.rawValue,
            intensity: 4,
            painLocation: "Stirn",
            painCharacter: "Pulsierend",
            notes: "Produktive V1-Fixture",
            symptomsStorage: "Übelkeit",
            triggersStorage: "Wetter",
            functionalImpact: "Pause",
            menstruationStatusRaw: MenstruationStatus.none.rawValue
        )
        episode.medications = [
            SymiSchemaV1.MedicationEntry(
                name: "Ibuprofen",
                categoryRaw: MedicationCategory.nsar.rawValue,
                dosage: "400 mg",
                takenAt: dates.medicationTakenAt,
                effectivenessRaw: MedicationEffectiveness.partial.rawValue,
                episode: episode
            )
        ]
        episode.weatherSnapshot = SymiSchemaV1.WeatherSnapshot(
            id: UUID(uuidString: "23100000-0000-0000-0000-000000000011")!,
            recordedAt: dates.startedAt,
            temperature: 18.4,
            condition: "Bewölkt",
            humidity: 64,
            pressure: 1008,
            source: "Manuell",
            episode: episode
        )
        context.insert(episode)
        return .fromLegacyEpisode(id: episode.id, weatherID: episode.weatherSnapshot?.id, expectedWeatherSource: "Legacy: Manuell")
    }

    static func seedV2(_ context: ModelContext) -> MigrationFixtureExpectation {
        let dates = FixtureDates(offset: 2)
        let episode = SymiSchemaV2.Episode(
            id: UUID(uuidString: "23100000-0000-0000-0000-000000000002")!,
            startedAt: dates.startedAt,
            endedAt: dates.endedAt,
            updatedAt: dates.updatedAt,
            typeRaw: EpisodeType.headache.rawValue,
            intensity: 5,
            painLocation: "Schläfen",
            painCharacter: "Drückend",
            notes: "Produktive V2-Fixture",
            symptomsStorage: "Lärm",
            triggersStorage: "Schlaf",
            functionalImpact: "Langsamer Tag",
            menstruationStatusRaw: MenstruationStatus.unknown.rawValue
        )
        episode.medications = [
            SymiSchemaV2.MedicationEntry(
                name: "Paracetamol",
                categoryRaw: MedicationCategory.paracetamol.rawValue,
                dosage: "500 mg",
                takenAt: dates.medicationTakenAt,
                effectivenessRaw: MedicationEffectiveness.good.rawValue,
                episode: episode
            )
        ]
        episode.weatherSnapshot = SymiSchemaV2.WeatherSnapshot(
            id: UUID(uuidString: "23100000-0000-0000-0000-000000000012")!,
            recordedAt: dates.startedAt,
            temperature: 20.1,
            condition: "Sonnig",
            humidity: 52,
            pressure: 1015,
            source: "Manuell",
            episode: episode
        )
        context.insert(episode)
        return .fromLegacyEpisode(id: episode.id, weatherID: episode.weatherSnapshot?.id, expectedWeatherSource: "Legacy: Manuell")
    }

    static func seedV3(_ context: ModelContext) -> MigrationFixtureExpectation {
        let dates = FixtureDates(offset: 3)
        let episode = SymiSchemaV3.Episode(
            id: UUID(uuidString: "23100000-0000-0000-0000-000000000003")!,
            startedAt: dates.startedAt,
            endedAt: dates.endedAt,
            updatedAt: dates.updatedAt,
            typeRaw: EpisodeType.migraine.rawValue,
            intensity: 6,
            painLocation: "Nacken",
            painCharacter: "Stechend",
            notes: "Produktive V3-Fixture",
            symptomsStorage: "Aura",
            triggersStorage: "Stress",
            functionalImpact: "Rückzug",
            menstruationStatusRaw: MenstruationStatus.none.rawValue
        )
        episode.medications = [
            SymiSchemaV3.MedicationEntry(
                name: "Sumatriptan",
                categoryRaw: MedicationCategory.triptan.rawValue,
                dosage: "50 mg",
                takenAt: dates.medicationTakenAt,
                effectivenessRaw: MedicationEffectiveness.good.rawValue,
                episode: episode
            )
        ]
        episode.weatherSnapshot = SymiSchemaV3.WeatherSnapshot(
            id: UUID(uuidString: "23100000-0000-0000-0000-000000000013")!,
            recordedAt: dates.startedAt,
            temperature: 16.8,
            condition: "Regen",
            humidity: 78,
            pressure: 998,
            precipitation: 3.4,
            weatherCode: 63,
            source: "Apple Weather",
            episode: episode
        )
        context.insert(episode)
        return .fromLegacyEpisode(id: episode.id, weatherID: episode.weatherSnapshot?.id, expectedWeatherSource: "Apple Weather")
    }

    static func seedV4(_ context: ModelContext) -> MigrationFixtureExpectation {
        let dates = FixtureDates(offset: 4)
        let episode = SymiSchemaV4.Episode(
            id: UUID(uuidString: "23100000-0000-0000-0000-000000000004")!,
            startedAt: dates.startedAt,
            endedAt: dates.endedAt,
            updatedAt: dates.updatedAt,
            typeRaw: EpisodeType.headache.rawValue,
            intensity: 7,
            painLocation: "Oberkopf",
            painCharacter: "Dumpf",
            notes: "Produktive V4-Fixture",
            symptomsStorage: "Müdigkeit",
            triggersStorage: "Wetterwechsel",
            functionalImpact: "Arbeit reduziert",
            menstruationStatusRaw: MenstruationStatus.unknown.rawValue
        )
        episode.medications = [
            SymiSchemaV4.MedicationEntry(
                name: "Naproxen",
                categoryRaw: MedicationCategory.nsar.rawValue,
                dosage: "250 mg",
                takenAt: dates.medicationTakenAt,
                effectivenessRaw: MedicationEffectiveness.none.rawValue,
                episode: episode
            )
        ]
        episode.weatherSnapshot = SymiSchemaV4.WeatherSnapshot(
            id: UUID(uuidString: "23100000-0000-0000-0000-000000000014")!,
            recordedAt: dates.startedAt,
            temperature: 12.2,
            condition: "Wind",
            humidity: 70,
            pressure: 1001,
            precipitation: 1.1,
            weatherCode: 51,
            source: "Apple Weather",
            episode: episode
        )
        context.insert(episode)
        context.insert(SymiSchemaV4.Doctor(name: "Dr. Legacy", specialty: "Neurologie"))
        return .fromLegacyEpisode(id: episode.id, weatherID: episode.weatherSnapshot?.id, expectedWeatherSource: "Apple Weather")
    }

    static func seedV5(_ context: ModelContext) -> MigrationFixtureExpectation {
        let dates = FixtureDates(offset: 5)
        let contextPoint = WeatherContextPointData(
            recordedAt: dates.startedAt,
            condition: "Nebel",
            temperature: 9.7,
            humidity: 86,
            pressure: 1005,
            precipitation: 0.2,
            weatherCode: 45
        )
        let episode = SymiSchemaV5.Episode(
            id: UUID(uuidString: "23100000-0000-0000-0000-000000000005")!,
            startedAt: dates.startedAt,
            endedAt: dates.endedAt,
            updatedAt: dates.updatedAt,
            typeRaw: EpisodeType.migraine.rawValue,
            intensity: 8,
            painLocation: "Einseitig",
            painCharacter: "Pulsierend",
            notes: "Produktive V5-Fixture",
            symptomsStorage: "Lichtempfindlichkeit",
            triggersStorage: "Schlafmangel",
            functionalImpact: "Bett",
            menstruationStatusRaw: MenstruationStatus.none.rawValue
        )
        episode.weatherSnapshot = SymiSchemaV5.WeatherSnapshot(
            id: UUID(uuidString: "23100000-0000-0000-0000-000000000015")!,
            recordedAt: dates.startedAt,
            temperature: 9.7,
            condition: "Nebel",
            humidity: 86,
            pressure: 1005,
            precipitation: 0.2,
            weatherCode: 45,
            source: "Apple Weather",
            dayRangeStart: dates.dayStart,
            dayRangeEnd: dates.dayEnd,
            contextRangeStart: dates.contextRangeStart,
            contextRangeEnd: dates.contextRangeEnd,
            contextPointsStorage: WeatherSnapshot.encodeContextPoints([contextPoint]),
            episode: episode
        )
        context.insert(episode)
        return .fromLegacyEpisode(
            id: episode.id,
            weatherID: episode.weatherSnapshot?.id,
            expectedWeatherSource: "Apple Weather",
            contextRangeStart: dates.contextRangeStart,
            contextRangeEnd: dates.contextRangeEnd,
            contextPoints: [contextPoint]
        )
    }

    static func seedV6(_ context: ModelContext) -> MigrationFixtureExpectation {
        let dates = FixtureDates(offset: 6)
        let continuousMedicationID = UUID(uuidString: "23100000-0000-0000-0000-000000000106")!
        let episode = SymiSchemaV6.Episode(
            id: UUID(uuidString: "23100000-0000-0000-0000-000000000006")!,
            startedAt: dates.startedAt,
            endedAt: dates.endedAt,
            updatedAt: dates.updatedAt,
            typeRaw: EpisodeType.migraine.rawValue,
            intensity: 9,
            painLocation: "Schläfen",
            painCharacter: "Pulsierend",
            notes: "Produktive V6-Fixture",
            symptomsStorage: "Übelkeit",
            triggersStorage: "Stress",
            functionalImpact: "Ausfall",
            menstruationStatusRaw: MenstruationStatus.unknown.rawValue
        )
        episode.continuousMedicationChecks = [
            SymiSchemaV6.ContinuousMedicationCheck(
                continuousMedicationID: continuousMedicationID,
                name: "Magnesium",
                dosage: "300 mg",
                frequency: "Täglich",
                wasTaken: true,
                episode: episode
            )
        ]
        episode.weatherSnapshot = SymiSchemaV6.WeatherSnapshot(
            id: UUID(uuidString: "23100000-0000-0000-0000-000000000016")!,
            recordedAt: dates.startedAt,
            temperature: 21.0,
            condition: "Klar",
            humidity: 49,
            pressure: 1018,
            precipitation: 0,
            weatherCode: 0,
            source: "Apple Weather",
            dayRangeStart: dates.dayStart,
            dayRangeEnd: dates.dayEnd,
            episode: episode
        )
        context.insert(episode)
        context.insert(SymiSchemaV6.ContinuousMedication(
            id: continuousMedicationID,
            name: "Magnesium",
            dosage: "300 mg",
            frequency: "Täglich",
            startDate: dates.startedAt.addingTimeInterval(-86_400)
        ))
        return .fromLegacyEpisode(id: episode.id, weatherID: episode.weatherSnapshot?.id, expectedWeatherSource: "Apple Weather")
    }
}

private struct FixtureDates {
    let startedAt: Date
    let endedAt: Date
    let updatedAt: Date
    let medicationTakenAt: Date
    let dayStart: Date
    let dayEnd: Date
    let contextRangeStart: Date
    let contextRangeEnd: Date

    init(offset: TimeInterval) {
        startedAt = Date(timeIntervalSince1970: 1_700_000_000 + offset * 100_000)
        endedAt = startedAt.addingTimeInterval(3_600)
        updatedAt = startedAt.addingTimeInterval(120)
        medicationTakenAt = startedAt.addingTimeInterval(900)
        dayStart = Calendar(identifier: .gregorian).startOfDay(for: startedAt)
        dayEnd = dayStart.addingTimeInterval(86_400)
        contextRangeStart = startedAt.addingTimeInterval(-43_200)
        contextRangeEnd = startedAt.addingTimeInterval(129_600)
    }
}

private struct MigrationFixtureExpectation {
    let episodeID: UUID
    let weatherID: UUID?
    let expectedWeatherSource: String
    let contextRangeStart: Date?
    let contextRangeEnd: Date?
    let contextPoints: [WeatherContextPointData]

    static func fromLegacyEpisode(
        id: UUID,
        weatherID: UUID?,
        expectedWeatherSource: String,
        contextRangeStart: Date? = nil,
        contextRangeEnd: Date? = nil,
        contextPoints: [WeatherContextPointData] = []
    ) -> Self {
        Self(
            episodeID: id,
            weatherID: weatherID,
            expectedWeatherSource: expectedWeatherSource,
            contextRangeStart: contextRangeStart,
            contextRangeEnd: contextRangeEnd,
            contextPoints: contextPoints
        )
    }
}

private struct MigrationFixtureResult {
    let container: ModelContainer
    let expectation: MigrationFixtureExpectation
}

private func migrateFixture<SchemaType: VersionedSchema>(
    schema: SchemaType.Type,
    seed: (ModelContext) throws -> MigrationFixtureExpectation
) throws -> MigrationFixtureResult {
    let storeURL = try makeFixtureStoreURL()
    let expectation: MigrationFixtureExpectation

    do {
        let container = try makeFixtureContainer(schema: SchemaType.self, storeURL: storeURL)
        let context = ModelContext(container)
        expectation = try seed(context)
        try context.save()
    }

    return MigrationFixtureResult(
        container: try makeFixtureCurrentContainer(storeURL: storeURL),
        expectation: expectation
    )
}

private func assertCurrentStoreMatchesFixture(_ result: MigrationFixtureResult) throws {
    let context = ModelContext(result.container)
    let episodes = try context.fetch(FetchDescriptor<Episode>())
    #expect(episodes.count == 1)

    let episode = try #require(episodes.first)
    #expect(episode.id == result.expectation.episodeID)
    #expect(episode.weatherSnapshot?.id == result.expectation.weatherID)
    #expect(episode.weatherSnapshot?.source == result.expectation.expectedWeatherSource)
}

private func makeFixtureStoreURL() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: "SymiMigrationFixtureTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appending(path: "Symi.store")
}

private func makeFixtureContainer<SchemaType: VersionedSchema>(
    schema: SchemaType.Type,
    storeURL: URL
) throws -> ModelContainer {
    let schema = Schema(versionedSchema: SchemaType.self)
    let configuration = ModelConfiguration("migration-fixture-test", schema: schema, url: storeURL, cloudKitDatabase: .none)
    return try ModelContainer(for: schema, configurations: [configuration])
}

private func makeFixtureCurrentContainer(storeURL: URL) throws -> ModelContainer {
    let schema = Schema(versionedSchema: SymiSchemaV9.self)
    let configuration = ModelConfiguration("migration-fixture-test", schema: schema, url: storeURL, cloudKitDatabase: .none)
    return try ModelContainer(
        for: schema,
        migrationPlan: SymiMigrationPlan.self,
        configurations: [configuration]
    )
}
