import Foundation
import SwiftData
import Testing
@testable import Symi

@MainActor
struct DataTransferHealthContextTests {
    @Test
    func backupRoundtripRestoresEpisodeMedicationWeatherAndHealthContext() throws {
        let episodeID = UUID()
        let healthContext = makeHealthContext()
        let sourceContainer = try makeInMemoryContainer()
        let sourceHealthStore = HealthContextStore(baseURL: try makeTemporaryDirectory())
        try seedEpisode(id: episodeID, in: sourceContainer)
        try seedContinuousMedication(in: sourceContainer)
        try sourceHealthStore.save(healthContext, for: episodeID)

        let backupURL = try SwiftDataExportRepository(
            modelContainer: sourceContainer,
            healthContextStore: sourceHealthStore
        ).createBackup()
        let backupText = try String(contentsOf: backupURL, encoding: .utf8)
        #expect(backupText.contains("\"healthContext\""))
        #expect(backupText.contains("\"continuousMedications\""))

        let targetContainer = try makeInMemoryContainer()
        let targetHealthStore = HealthContextStore(baseURL: try makeTemporaryDirectory())
        try SwiftDataExportRepository(
            modelContainer: targetContainer,
            healthContextStore: targetHealthStore
        ).importBackup(from: backupURL)

        let importedEpisodes = try ModelContext(targetContainer).fetch(FetchDescriptor<Episode>())
        #expect(importedEpisodes.count == 1)
        guard let importedEpisode = importedEpisodes.first else {
            Issue.record("Importierte Episode fehlt.")
            return
        }

        #expect(importedEpisode.id == episodeID)
        #expect(importedEpisode.medications.count == 1)
        #expect(importedEpisode.medications.first?.name == "Sumatriptan")
        #expect(importedEpisode.continuousMedicationChecks.first?.name == "Metoprolol")
        #expect(importedEpisode.weatherSnapshot?.condition == "Regen")
        #expect(importedEpisode.weatherSnapshot?.contextPoints.count == 1)
        let importedContinuousMedications = try ModelContext(targetContainer).fetch(FetchDescriptor<ContinuousMedication>())
        #expect(importedContinuousMedications.first?.name == "Metoprolol")
        #expect(targetHealthStore.load(for: episodeID) == HealthContextRecord(snapshot: healthContext))
    }

    @Test
    func importWithoutHealthContextKeyKeepsExistingContext() throws {
        let episodeID = UUID()
        let existingHealthContext = makeHealthContext(source: "Bestehender Kontext")
        let sourceContainer = try makeInMemoryContainer()
        let sourceHealthStore = HealthContextStore(baseURL: try makeTemporaryDirectory())
        try seedEpisode(id: episodeID, notes: "Import ohne Health-Kontext", in: sourceContainer)

        let backupURL = try SwiftDataExportRepository(
            modelContainer: sourceContainer,
            healthContextStore: sourceHealthStore
        ).createBackup()
        let backupText = try String(contentsOf: backupURL, encoding: .utf8)
        #expect(!backupText.contains("\"healthContext\""))

        let targetContainer = try makeInMemoryContainer()
        let targetHealthStore = HealthContextStore(baseURL: try makeTemporaryDirectory())
        try seedEpisode(id: episodeID, notes: "Bestehender Eintrag", in: targetContainer)
        try targetHealthStore.save(existingHealthContext, for: episodeID)

        try SwiftDataExportRepository(
            modelContainer: targetContainer,
            healthContextStore: targetHealthStore
        ).importBackup(from: backupURL)

        let importedEpisode = try ModelContext(targetContainer).fetch(FetchDescriptor<Episode>()).first
        #expect(importedEpisode?.notes == "Import ohne Health-Kontext")
        #expect(targetHealthStore.load(for: episodeID) == HealthContextRecord(snapshot: existingHealthContext))
    }

    @Test
    func explicitNullHealthContextRemovesExistingContext() throws {
        let episodeID = UUID()
        let sourceContainer = try makeInMemoryContainer()
        let sourceHealthStore = HealthContextStore(baseURL: try makeTemporaryDirectory())
        try seedEpisode(id: episodeID, in: sourceContainer)
        let backupURL = try SwiftDataExportRepository(
            modelContainer: sourceContainer,
            healthContextStore: sourceHealthStore
        ).createBackup()
        let explicitNullBackupURL = try backupURLByAddingExplicitNullHealthContext(to: backupURL)

        let targetContainer = try makeInMemoryContainer()
        let targetHealthStore = HealthContextStore(baseURL: try makeTemporaryDirectory())
        try seedEpisode(id: episodeID, in: targetContainer)
        try targetHealthStore.save(makeHealthContext(), for: episodeID)

        try SwiftDataExportRepository(
            modelContainer: targetContainer,
            healthContextStore: targetHealthStore
        ).importBackup(from: explicitNullBackupURL)

        #expect(targetHealthStore.load(for: episodeID) == nil)
    }

    @Test
    func importThrowsWhenHealthContextCannotBeWritten() throws {
        let episodeID = UUID()
        let sourceContainer = try makeInMemoryContainer()
        let sourceHealthStore = HealthContextStore(baseURL: try makeTemporaryDirectory())
        try seedEpisode(id: episodeID, in: sourceContainer)
        try sourceHealthStore.save(makeHealthContext(), for: episodeID)
        let backupURL = try SwiftDataExportRepository(
            modelContainer: sourceContainer,
            healthContextStore: sourceHealthStore
        ).createBackup()

        let blockedBaseURL = try makeTemporaryDirectory()
        try Data("blockiert".utf8).write(to: blockedBaseURL.appending(path: "Symi"))
        let blockedHealthStore = HealthContextStore(baseURL: blockedBaseURL)

        var didThrow = false
        do {
            try SwiftDataExportRepository(
                modelContainer: try makeInMemoryContainer(),
                healthContextStore: blockedHealthStore
            ).importBackup(from: backupURL)
        } catch {
            didThrow = true
        }

        #expect(didThrow)
    }
}

private func makeInMemoryContainer() throws -> ModelContainer {
    let schema = Schema(versionedSchema: SymiSchemaV6.self)
    let configuration = ModelConfiguration(
        "test-\(UUID().uuidString)",
        schema: schema,
        isStoredInMemoryOnly: true,
        cloudKitDatabase: .none
    )
    return try ModelContainer(for: schema, configurations: [configuration])
}

private func seedEpisode(id: UUID, notes: String = "Migräne nach Wetterwechsel", in container: ModelContainer) throws {
    let context = ModelContext(container)
    let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
    let episode = Episode(
        id: id,
        startedAt: startedAt,
        endedAt: startedAt.addingTimeInterval(7_200),
        updatedAt: startedAt.addingTimeInterval(60),
        type: .migraine,
        intensity: 7,
        painLocation: "Stirn",
        painCharacter: "Pulsierend",
        notes: notes,
        symptoms: ["Übelkeit"],
        triggers: ["Stress"],
        functionalImpact: "Arbeiten nur eingeschränkt möglich",
        menstruationStatus: .none
    )
    let medication = MedicationEntry(
        id: UUID(),
        name: "Sumatriptan",
        category: .triptan,
        dosage: "50 mg",
        quantity: 1,
        takenAt: startedAt.addingTimeInterval(900),
        effectiveness: .good,
        reliefStartedAt: startedAt.addingTimeInterval(3_600),
        episode: episode
    )
    episode.medications = [medication]
    episode.continuousMedicationChecks = [
        ContinuousMedicationCheck(
            continuousMedicationID: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            name: "Metoprolol",
            dosage: "50 mg",
            frequency: "täglich",
            wasTaken: true,
            episode: episode
        )
    ]
    episode.weatherSnapshot = WeatherSnapshot(
        id: UUID(),
        recordedAt: startedAt,
        temperature: 18.5,
        condition: "Regen",
        humidity: 72,
        pressure: 1004,
        precipitation: 1.4,
        weatherCode: 63,
        source: "Apple Weather",
        dayRangeStart: Calendar.current.startOfDay(for: startedAt),
        dayRangeEnd: Calendar.current.startOfDay(for: startedAt).addingTimeInterval(86_400),
        contextRangeStart: Calendar.current.startOfDay(for: startedAt).addingTimeInterval(-43_200),
        contextRangeEnd: Calendar.current.startOfDay(for: startedAt).addingTimeInterval(129_600),
        contextPointsStorage: WeatherSnapshot.encodeContextPoints([
            WeatherContextPointData(
                recordedAt: startedAt,
                condition: "Regen",
                temperature: 18.5,
                humidity: 72,
                pressure: 1004,
                precipitation: 1.4,
                weatherCode: 63
            )
        ]),
        episode: episode
    )
    context.insert(episode)
    try context.save()
}

private func seedContinuousMedication(in container: ModelContainer) throws {
    let context = ModelContext(container)
    context.insert(
        ContinuousMedication(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            name: "Metoprolol",
            dosage: "50 mg",
            frequency: "täglich",
            startDate: Date(timeIntervalSince1970: 1_699_000_000),
            endDate: nil
        )
    )
    try context.save()
}

private func makeHealthContext(source: String = "Apple Health") -> HealthContextSnapshotData {
    let recordedAt = Date(timeIntervalSince1970: 1_700_000_300)
    return HealthContextSnapshotData(
        recordedAt: recordedAt,
        source: source,
        sleepMinutes: 420,
        stepCount: 3_200,
        averageHeartRate: 78,
        restingHeartRate: 62,
        heartRateVariability: 41,
        menstrualFlow: nil,
        symptoms: [
            HealthSymptomSampleData(
                type: .headache,
                severity: "Mittel",
                startDate: recordedAt.addingTimeInterval(-1_800),
                endDate: recordedAt,
                source: "Health"
            )
        ]
    )
}

private func backupURLByAddingExplicitNullHealthContext(to backupURL: URL) throws -> URL {
    let data = try Data(contentsOf: backupURL)
    guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          var episodes = root["episodes"] as? [[String: Any]],
          !episodes.isEmpty else {
        throw DataTransferError.invalidFormat
    }

    episodes[0]["healthContext"] = NSNull()
    root["episodes"] = episodes

    let explicitNullData = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    let url = try makeTemporaryDirectory().appending(path: "explicit-null-health-context.json5")
    try explicitNullData.write(to: url, options: .atomic)
    return url
}

private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
