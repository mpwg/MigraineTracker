import Foundation
import CoreLocation
import Testing
import WeatherKit
@testable import Symi

@MainActor
struct CoreArchitectureTests {
    @Test
    func saveEpisodeUseCaseRejectsInvalidDateRange() async {
        let repository = EpisodeRepositoryMock()
        let useCase = SaveEpisodeUseCase(repository: repository)
        var draft = EpisodeDraft.makeNew()
        draft.endedAtEnabled = true
        draft.startedAt = Date(timeIntervalSince1970: 2_000)
        draft.endedAt = Date(timeIntervalSince1970: 1_000)

        await #expect(throws: EpisodeSaveError.invalidDateRange) {
            try await useCase.execute(draft, weatherSnapshot: nil)
        }
    }

    @Test
    func saveEpisodeUseCasePassesWeatherSnapshotToRepository() async throws {
        let repository = EpisodeRepositoryMock()
        let useCase = SaveEpisodeUseCase(repository: repository)
        let draft = EpisodeDraft.makeNew()
        let snapshot = WeatherSnapshotData(
            recordedAt: Date(timeIntervalSince1970: 1_000),
            condition: "Regen",
            temperature: 18.5,
            humidity: 72,
            pressure: 1004,
            precipitation: 1.4,
            weatherCode: 63,
            source: "Apple Weather"
        )

        let savedID = try await useCase.execute(draft, weatherSnapshot: snapshot)

        #expect(savedID == repository.savedDraftID)
        #expect(repository.lastWeatherSnapshot == snapshot)
    }

    @Test
    func saveEpisodeUseCasePassesHealthContextToRepository() async throws {
        let repository = EpisodeRepositoryMock()
        let useCase = SaveEpisodeUseCase(repository: repository)
        let draft = EpisodeDraft.makeNew()
        let context = HealthContextSnapshotData(
            recordedAt: Date(timeIntervalSince1970: 2_000),
            source: "Apple Health",
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
                    startDate: draft.startedAt,
                    endDate: draft.startedAt,
                    source: "Health"
                )
            ]
        )

        _ = try await useCase.execute(draft, weatherSnapshot: nil, healthContext: context)

        #expect(repository.lastHealthContext == context)
    }

    @Test
    func healthSeverityMapperUsesPainIntensityBands() {
        #expect(HealthSeverityMapper.symptomSeverityLabel(forIntensity: 1) == "Leicht")
        #expect(HealthSeverityMapper.symptomSeverityLabel(forIntensity: 4) == "Mittel")
        #expect(HealthSeverityMapper.symptomSeverityLabel(forIntensity: 8) == "Stark")
    }

    @Test
    func healthTypePreferencesSeparateSelectionFromAuthorizationRequest() {
        let suiteName = "HealthTypePreferencesTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = HealthTypePreferences(defaults: defaults)

        let enabledTypes = preferences.enabledTypes(for: .read, definitions: HealthDataCatalog.readDefinitions)

        #expect(enabledTypes.contains(.sleep))
        #expect(preferences.hasRequestedAuthorization(for: .read) == false)

        preferences.markAuthorizationRequested(for: .read)

        #expect(preferences.hasRequestedAuthorization(for: .read) == true)
    }

    @Test
    func appleWeatherKitServiceSkipsDatesBeforeHourlyHistory() async throws {
        let service = AppleWeatherKitWeatherService()
        let oldDate = Date(timeIntervalSince1970: 1_627_775_999)
        let location = CLLocation(latitude: 48.2082, longitude: 16.3738)

        let snapshot = try await service.fetchWeather(for: oldDate, location: location)

        #expect(snapshot == nil)
    }

    @Test
    func weatherContextServiceReusesOriginalSnapshotWithoutLocationRefresh() async {
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = WeatherSnapshotData(
            recordedAt: startedAt,
            condition: "Regen",
            temperature: 18.5,
            humidity: 72,
            pressure: 1004,
            precipitation: 1.4,
            weatherCode: 63,
            source: "Apple Weather"
        )
        let service = EpisodeWeatherContextService(
            weatherService: FailingWeatherService(),
            locationService: FailingLocationService()
        )

        let state = await service.loadWeather(
            for: startedAt,
            originalStartedAt: startedAt,
            originalSnapshot: snapshot
        )

        #expect(state == .loaded(snapshot))
    }

    @Test
    func weatherConditionMapperUsesGermanDescriptions() {
        #expect(WeatherConditionMapper.description(for: .clear) == "Klar")
        #expect(WeatherConditionMapper.description(for: .heavyRain) == "Starker Regen")
        #expect(WeatherConditionMapper.description(for: .thunderstorms) == "Gewitter")
    }

    @Test
    func saveEpisodeUseCaseRejectsFutureDate() async {
        let repository = EpisodeRepositoryMock()
        let useCase = SaveEpisodeUseCase(repository: repository)
        var draft = EpisodeDraft.makeNew()
        draft.startedAt = .now.addingTimeInterval(3_600)

        await #expect(throws: EpisodeSaveError.futureDate) {
            try await useCase.execute(draft, weatherSnapshot: nil)
        }
    }

    @Test
    func medicationSelectionControllerSavesCustomDefinitionWithoutEpisodeSave() async {
        let repository = MedicationCatalogRepositoryMock()
        let controller = EpisodeMedicationSelectionController(
            medicationRepository: repository,
            autoload: false
        )
        let draft = CustomMedicationDefinitionDraft(
            id: "custom:sumatriptan",
            originalSelectionKey: nil,
            name: "Sumatriptan",
            category: .triptan,
            dosage: "50 mg"
        )

        await controller.saveCustomMedication(from: draft)

        #expect(repository.savedDrafts == [draft])
        #expect(controller.selectedMedications.count == 1)
        #expect(controller.selectedMedications.first?.name == "Sumatriptan")
        #expect(controller.validationMessage == nil)
    }

    @Test
    func medicationSelectionControllerDeletesCustomDefinitionWithoutEpisodeSave() async {
        let repository = MedicationCatalogRepositoryMock()
        let definition = MedicationDefinitionRecord(
            catalogKey: "custom:sumatriptan",
            groupID: "custom-medications",
            groupTitle: "Eigene Medikamente",
            groupFooter: nil,
            name: "Sumatriptan",
            category: .triptan,
            suggestedDosage: "50 mg",
            sortOrder: 1,
            isCustom: true,
            isDeleted: false
        )
        let controller = EpisodeMedicationSelectionController(
            medicationRepository: repository,
            initialMedications: [MedicationSelectionDraft(definition: definition)],
            autoload: false
        )

        await controller.deleteCustomMedication(definition)

        #expect(repository.deletedCatalogKeys == ["custom:sumatriptan"])
        #expect(controller.selectedMedications.isEmpty)
        #expect(controller.validationMessage == nil)
    }

    @Test
    func loadHistoryMonthUseCaseGroupsByCalendarDay() async throws {
        let repository = EpisodeRepositoryMock()
        let firstDay = Date(timeIntervalSince1970: 10_000)
        let sameDayLater = firstDay.addingTimeInterval(60 * 60)
        let secondDay = firstDay.addingTimeInterval(60 * 60 * 24)
        repository.monthRecords = [
            makeEpisode(id: UUID(), startedAt: firstDay, intensity: 5),
            makeEpisode(id: UUID(), startedAt: sameDayLater, intensity: 7),
            makeEpisode(id: UUID(), startedAt: secondDay, intensity: 3)
        ]

        let result = try await LoadHistoryMonthUseCase(repository: repository).execute(month: firstDay)

        #expect(result.episodesByDay.count == 2)
        #expect(result.episodesByDay[Calendar.current.startOfDay(for: firstDay)]?.count == 2)
        #expect(result.episodesByDay[Calendar.current.startOfDay(for: secondDay)]?.count == 1)
    }

    @Test
    func homePatternPreviewRequiresEnoughPainEpisodes() async throws {
        let repository = EpisodeRepositoryMock()
        repository.recentRecords = [
            makeEpisode(id: UUID(), startedAt: .now, intensity: 5, type: .migraine),
            makeEpisode(id: UUID(), startedAt: .now.addingTimeInterval(-86_400), intensity: 3, type: .unclear),
            makeEpisode(id: UUID(), startedAt: .now.addingTimeInterval(-172_800), intensity: 4, type: .headache)
        ]

        let result = try await LoadHomePatternPreviewUseCase(
            repository: repository,
            insightEngine: InsightEngine()
        ).execute()

        #expect(result.totalPainEpisodeCount == 2)
        #expect(result.hasEnoughData == false)
        #expect(result.cards.isEmpty)
    }

    @Test
    func insightEngineIgnoresUnclearEpisodesForAverageAndMinimumCount() {
        let engine = InsightEngine()
        let start = fixedDate()
        let episodes = [
            makeEpisode(id: UUID(), startedAt: start, intensity: 6, type: .migraine),
            makeEpisode(id: UUID(), startedAt: start, intensity: 6, type: .headache),
            makeEpisode(id: UUID(), startedAt: start, intensity: 6, type: .migraine),
            makeEpisode(id: UUID(), startedAt: start, intensity: 6, type: .headache),
            makeEpisode(id: UUID(), startedAt: start, intensity: 6, type: .migraine),
            makeEpisode(id: UUID(), startedAt: start, intensity: 10, type: .unclear),
            makeEpisode(id: UUID(), startedAt: start, intensity: 10, type: .unclear)
        ]

        let result = engine.evaluate(episodes: episodes, calendar: fixedCalendar())
        let average = result.insights.first { $0.category == .averageIntensity }

        #expect(result.totalQualifiedEpisodeCount == 5)
        #expect(average?.title == "Durchschnitt 6/10")
    }

    @Test
    func insightEngineReturnsNoArtificialInsightForEmptyData() {
        let result = InsightEngine().evaluate(episodes: [], calendar: fixedCalendar())

        #expect(result.totalQualifiedEpisodeCount == 0)
        #expect(result.heroInsight == nil)
        #expect(result.insights.isEmpty)
    }

    @Test
    func insightEngineBuildsAverageIntensityInsight() {
        let engine = InsightEngine()
        let start = fixedDate()
        let intensities = [4, 6, 8, 5, 7]
        let episodes = intensities.enumerated().map { offset, intensity in
            makeEpisode(id: UUID(), startedAt: start.addingTimeInterval(Double(offset) * 86_400), intensity: intensity)
        }

        let result = engine.evaluate(episodes: episodes, calendar: fixedCalendar())
        let average = result.insights.first { $0.category == .averageIntensity }

        #expect(average?.title == "Durchschnitt 6/10")
        #expect(average?.description.contains("6 von 10") == true)
        #expect(average?.confidence ?? 0 >= InsightScorer.confidenceThreshold)
        #expect(abs((average?.importance ?? 0) - 0.6) < 0.001)
    }

    @Test
    func insightEngineAppliesWeekdayAndTriggerThresholds() {
        let engine = InsightEngine()
        let start = fixedDate()
        let weakEpisodes = (0 ..< 5).map { offset in
            makeEpisode(
                id: UUID(),
                startedAt: start.addingTimeInterval(Double(offset) * 86_400),
                intensity: 4,
                triggers: offset < 2 ? ["Stress"] : []
            )
        }

        let weakResult = engine.evaluate(episodes: weakEpisodes, calendar: fixedCalendar())

        #expect(!weakResult.insights.contains { $0.category == .weekdayPattern })
        #expect(!weakResult.insights.contains { $0.category == .triggerCorrelation })

        let strongEpisodes = [
            makeEpisode(id: UUID(), startedAt: start, intensity: 8, triggers: ["Stress"]),
            makeEpisode(id: UUID(), startedAt: start.addingTimeInterval(7 * 86_400), intensity: 8, triggers: ["Stress"]),
            makeEpisode(id: UUID(), startedAt: start.addingTimeInterval(14 * 86_400), intensity: 8, triggers: ["Stress"]),
            makeEpisode(id: UUID(), startedAt: start.addingTimeInterval(21 * 86_400), intensity: 8),
            makeEpisode(id: UUID(), startedAt: start.addingTimeInterval(86_400), intensity: 7)
        ]

        let strongResult = engine.evaluate(episodes: strongEpisodes, calendar: fixedCalendar())

        #expect(strongResult.insights.contains { $0.category == .weekdayPattern })
        #expect(strongResult.insights.contains { $0.category == .triggerCorrelation })
    }

    @Test
    func insightEngineDetectsRisingAndFallingTrends() {
        let engine = InsightEngine()
        let start = fixedDate()
        let rising = [2, 2, 3, 7, 8, 8].enumerated().map { offset, intensity in
            makeEpisode(id: UUID(), startedAt: start.addingTimeInterval(Double(offset) * 86_400), intensity: intensity)
        }
        let falling = [8, 8, 7, 3, 2, 2].enumerated().map { offset, intensity in
            makeEpisode(id: UUID(), startedAt: start.addingTimeInterval(Double(offset) * 86_400), intensity: intensity)
        }

        let risingTrend = engine.evaluate(episodes: rising, calendar: fixedCalendar()).insights.first { $0.category == .trend }
        let fallingTrend = engine.evaluate(episodes: falling, calendar: fixedCalendar()).insights.first { $0.category == .trend }

        #expect(risingTrend?.title == "Intensität steigt")
        #expect(fallingTrend?.title == "Intensität fällt")
    }

    @Test
    func insightEngineSortsByCombinedScoreAndExposesHeroInsight() {
        let engine = InsightEngine()
        let start = fixedDate()
        let episodes = [
            makeEpisode(id: UUID(), startedAt: start, intensity: 8, triggers: ["Stress"]),
            makeEpisode(id: UUID(), startedAt: start.addingTimeInterval(7 * 86_400), intensity: 8, triggers: ["Stress"]),
            makeEpisode(id: UUID(), startedAt: start.addingTimeInterval(14 * 86_400), intensity: 8, triggers: ["Stress"]),
            makeEpisode(id: UUID(), startedAt: start.addingTimeInterval(21 * 86_400), intensity: 8, triggers: ["Stress"]),
            makeEpisode(id: UUID(), startedAt: start.addingTimeInterval(28 * 86_400), intensity: 8, triggers: ["Stress"])
        ]

        let result = engine.evaluate(episodes: episodes, calendar: fixedCalendar())

        #expect(Array(result.insights.map(\.category).prefix(2)) == [.weekdayPattern, .triggerCorrelation])
        #expect(result.heroInsight == result.insights.first)
        #expect(result.heroInsight?.category == .weekdayPattern)
    }

    @Test
    func loadSettingsUseCaseCountsActiveTrashAndConflicts() async throws {
        let episodeRepository = EpisodeRepositoryMock()
        let medicationRepository = MedicationCatalogRepositoryMock()
        let syncService = SyncServiceMock()
        episodeRepository.recentRecords = [
            makeEpisode(id: UUID(), startedAt: .now, intensity: 5),
            makeEpisode(id: UUID(), startedAt: .now.addingTimeInterval(-1_000), intensity: 3)
        ]
        episodeRepository.deletedRecords = [
            makeEpisode(id: UUID(), startedAt: .now.addingTimeInterval(-2_000), intensity: 7, deletedAt: .now)
        ]
        medicationRepository.deletedDefinitions = [
            MedicationDefinitionRecord(
                catalogKey: "custom:1",
                groupID: "custom-medications",
                groupTitle: "Eigene Medikamente",
                groupFooter: nil,
                name: "Sumatriptan",
                category: .triptan,
                suggestedDosage: "50 mg",
                sortOrder: 1,
                isCustom: true,
                isDeleted: true
            )
        ]
        syncService.conflictsStorage = [
            SyncConflict(
                documentID: "episode-1",
                entityType: .episode,
                base: nil,
                local: sampleEnvelope(),
                remote: sampleEnvelope(),
                conflictingFields: ["notes"]
            )
        ]

        let summary = try await LoadSettingsUseCase(
            episodeRepository: episodeRepository,
            medicationRepository: medicationRepository,
            syncService: syncService
        ).execute()

        #expect(summary.activeEpisodeCount == 2)
        #expect(summary.trashCount == 2)
        #expect(summary.conflictCount == 1)
    }

}

private final class EpisodeRepositoryMock: EpisodeRepository, @unchecked Sendable {
    var recentRecords: [EpisodeRecord] = []
    var monthRecords: [EpisodeRecord] = []
    var dayRecords: [EpisodeRecord] = []
    var loadedRecord: EpisodeRecord?
    var deletedRecords: [EpisodeRecord] = []
    var lastSavedDraft: EpisodeDraft?
    var lastWeatherSnapshot: WeatherSnapshotData?
    var lastHealthContext: HealthContextSnapshotData?
    let savedDraftID = UUID()

    func fetchRecent() throws -> [EpisodeRecord] { recentRecords }
    func fetchByDay(_ day: Date) throws -> [EpisodeRecord] { dayRecords }
    func fetchByMonth(_ month: Date) throws -> [EpisodeRecord] { monthRecords }
    func load(id: UUID) throws -> EpisodeRecord? { loadedRecord }
    func save(draft: EpisodeDraft, weatherSnapshot: WeatherSnapshotData?, healthContext: HealthContextSnapshotData?) throws -> UUID {
        lastSavedDraft = draft
        lastWeatherSnapshot = weatherSnapshot
        lastHealthContext = healthContext
        return savedDraftID
    }
    func softDelete(id: UUID) throws {}
    func restore(id: UUID) throws {}
    func fetchDeleted() throws -> [EpisodeRecord] { deletedRecords }
}

private final class MedicationCatalogRepositoryMock: MedicationCatalogRepository, @unchecked Sendable {
    var definitions: [MedicationDefinitionRecord] = []
    var deletedDefinitions: [MedicationDefinitionRecord] = []
    var savedDrafts: [CustomMedicationDefinitionDraft] = []
    var deletedCatalogKeys: [String] = []

    func fetchDefinitions(searchText: String?) throws -> [MedicationDefinitionRecord] { definitions }
    func saveCustomDefinition(_ draft: CustomMedicationDefinitionDraft) throws -> MedicationDefinitionRecord {
        savedDrafts.append(draft)
        let record = MedicationDefinitionRecord(
            catalogKey: draft.id,
            groupID: "custom-medications",
            groupTitle: "Eigene Medikamente",
            groupFooter: nil,
            name: draft.name,
            category: draft.category,
            suggestedDosage: draft.dosage,
            sortOrder: 1,
            isCustom: true,
            isDeleted: false
        )
        definitions.append(record)
        return record
    }
    func softDeleteCustomDefinition(catalogKey: String) throws {
        deletedCatalogKeys.append(catalogKey)
    }
    func fetchDeletedDefinitions() throws -> [MedicationDefinitionRecord] { deletedDefinitions }
}

private enum UnexpectedServiceCallError: Error {
    case called
}

private struct FailingWeatherService: Symi.WeatherService {
    func fetchWeather(for date: Date, location: CLLocation) async throws -> WeatherSnapshotData? {
        throw UnexpectedServiceCallError.called
    }
}

@MainActor
private final class FailingLocationService: LocationService {
    func requestApproximateLocation() async throws -> CLLocation {
        throw UnexpectedServiceCallError.called
    }
}

@MainActor
private final class SyncServiceMock: SyncService {
    var isEnabled = false
    var status = SyncStatusSnapshot()
    var conflictsStorage: [SyncConflict] = []
    var conflicts: [SyncConflict] { conflictsStorage }

    func setSyncEnabled(_ enabled: Bool) { isEnabled = enabled }
    func refreshStatus() {}
    func syncNow() async {}
    func retryLastError() async {}
    func resolveConflictKeepingLocal(_ conflict: SyncConflict) async {}
    func resolveConflictUsingRemote(_ conflict: SyncConflict) async {}
}

private func makeEpisode(
    id: UUID,
    startedAt: Date,
    intensity: Int,
    deletedAt: Date? = nil,
    type: EpisodeType = .migraine,
    symptoms: [String] = [],
    triggers: [String] = [],
    menstruationStatus: MenstruationStatus = .unknown,
    weather: WeatherRecord? = nil
) -> EpisodeRecord {
    EpisodeRecord(
        id: id,
        startedAt: startedAt,
        endedAt: nil,
        updatedAt: startedAt,
        deletedAt: deletedAt,
        type: type,
        intensity: intensity,
        painLocation: "",
        painCharacter: "",
        notes: "",
        symptoms: symptoms,
        triggers: triggers,
        functionalImpact: "",
        menstruationStatus: menstruationStatus,
        medications: [],
        continuousMedicationChecks: [],
        weather: weather,
        healthContext: nil
    )
}

private func fixedDate() -> Date {
    Date(timeIntervalSince1970: 1_704_067_200)
}

private func fixedCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    calendar.firstWeekday = 2
    return calendar
}

private func sampleEnvelope() -> SyncDocumentEnvelope {
    SyncDocumentEnvelope(
        documentID: "episode-1",
        entityType: .episode,
        modifiedAt: .now,
        authorDeviceID: "device-a",
        payload: .episode(
            SyncEpisodePayload(
                id: "episode-1",
                startedAt: .now,
                endedAt: nil,
                type: "Migräne",
                intensity: 5,
                painLocation: "",
                painCharacter: "",
                notes: "",
                symptoms: [],
                triggers: [],
                functionalImpact: "",
                menstruationStatus: MenstruationStatus.unknown.rawValue,
                medications: [],
                weatherSnapshot: nil
            )
        )
    )
}
