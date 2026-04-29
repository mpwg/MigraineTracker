import Foundation
import CoreLocation
import os
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
        #expect(HealthSeverityMapper.symptomSeverityLabel(forIntensity: 10) == "Stark")
    }

    @Test
    func appMenstruationStatusNeverQualifiesAsHealthFlowSample() {
        for status in MenstruationStatus.allCases {
            #expect(!HealthDataCatalog.canWriteMenstrualFlowSample(from: status))
            #expect(!status.canWriteMenstrualFlowSample)
            #expect(!status.accuracyDescription.isEmpty)
        }

        #expect(!HealthDataCatalog.writeDefinitions.contains { $0.id == .menstrualFlow })
    }

    @Test
    func healthMenstrualFlowSampleKeepsSourceAndPrecisionSeparateFromAppStatus() {
        let sample = HealthMenstrualFlowSampleData(
            flow: "Mittel",
            precision: .specified,
            startDate: Date(timeIntervalSince1970: 1_000),
            endDate: Date(timeIntervalSince1970: 2_000),
            source: "Apple Health",
            isUserEntered: true
        )
        let snapshot = HealthContextSnapshotData(
            recordedAt: Date(timeIntervalSince1970: 3_000),
            source: "Apple Health",
            sleepMinutes: nil,
            stepCount: nil,
            averageHeartRate: nil,
            restingHeartRate: nil,
            heartRateVariability: nil,
            menstrualFlow: sample.flow,
            menstrualFlowSample: sample,
            symptoms: []
        )

        #expect(sample.canWriteToAppleHealth)
        #expect(snapshot.hasVisibleData)
        #expect(snapshot.menstrualFlowSample?.precision == .specified)
        #expect(MenstruationStatus.active.displayName == "Aktuell")
        #expect(!MenstruationStatus.active.canWriteMenstrualFlowSample)
    }

    @Test
    func painIntensityLevelUsesCentralBoundaryBuckets() {
        let expectations: [(Int, PainIntensityLevel, String, String?)] = [
            (0, .none, "Nicht bewertet", nil),
            (1, .low, "Leicht", "Leichter Verlauf"),
            (3, .low, "Leicht", "Leichter Verlauf"),
            (4, .medium, "Mittel", "Mittlerer Verlauf"),
            (6, .medium, "Mittel", "Mittlerer Verlauf"),
            (7, .high, "Stark", "Starker Verlauf"),
            (8, .high, "Stark", "Starker Verlauf"),
            (9, .veryHigh, "Sehr stark", "Sehr starker Verlauf"),
            (10, .veryHigh, "Sehr stark", "Sehr starker Verlauf"),
            (11, .none, "Nicht bewertet", nil)
        ]

        for expectation in expectations {
            let level = PainIntensityLevel(intensity: expectation.0)

            #expect(level == expectation.1)
            #expect(level.displayLabel == expectation.2)
            #expect(level.contextText == expectation.3)
            #expect(level.contains(intensity: expectation.0))
        }
    }

    @Test
    func painTokenMapsRawIntensityThroughDomainLevel() {
        for intensity in 0 ... 11 {
            let token = ColorToken.Pain.token(forIntensity: intensity)

            #expect(token.level == PainIntensityLevel(intensity: intensity))
        }
    }

    @Test
    func episodeDayPartProvidesCentralClassificationAndDisplayText() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let expectations: [(Int, EpisodeDayPart, String)] = [
            (4, .nacht, "In der Nacht"),
            (5, .morgens, "Am Morgen"),
            (10, .morgens, "Am Morgen"),
            (11, .mittags, "Am Nachmittag"),
            (16, .mittags, "Am Nachmittag"),
            (17, .abends, "Am Abend"),
            (21, .abends, "Am Abend"),
            (22, .nacht, "In der Nacht")
        ]

        for expectation in expectations {
            let date = calendar.date(from: DateComponents(year: 2026, month: 4, day: 28, hour: expectation.0))!
            let dayPart = EpisodeDayPart(date: date, calendar: calendar)

            #expect(dayPart == expectation.1)
            #expect(dayPart.contextualLabel == expectation.2)
            #expect(JournalEntryContext.timeOfDay(for: date, calendar: calendar) == expectation.2)
        }
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
    func healthDataCatalogDocumentsSeparateReadableAndWritableTypes() {
        let readDefinitions = HealthDataCatalog.readDefinitions
        let writeDefinitions = HealthDataCatalog.writeDefinitions

        #expect(!readDefinitions.isEmpty)
        #expect(!writeDefinitions.isEmpty)
        #expect(readDefinitions.allSatisfy { $0.direction == .read })
        #expect(writeDefinitions.allSatisfy { $0.direction == .write })
        #expect(Set(readDefinitions.map(\.id)).count == readDefinitions.count)
        #expect(Set(writeDefinitions.map(\.id)).count == writeDefinitions.count)
        #expect(readDefinitions.contains { $0.category == .sleep })
        #expect(readDefinitions.contains { $0.category == .activity })
        #expect(readDefinitions.contains { $0.category == .heart })
        #expect(readDefinitions.contains { $0.category == .cycle })
        #expect(readDefinitions.contains { $0.category == .symptom })
        #expect(writeDefinitions.allSatisfy { $0.category == .symptom })
        #expect(HealthDataCatalog.allDefinitions.allSatisfy { !$0.rationale.trimmed.isEmpty })
        #expect(HealthDataCatalog.allDefinitions.allSatisfy { !$0.healthKitIdentifier.trimmed.isEmpty })
    }

    @Test
    func usageDataConsentStorePersistsExplicitDecisions() {
        let suiteName = "UsageDataConsentStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UsageDataConsentStore(defaults: defaults)

        #expect(store.consent == .undecided)

        store.setConsent(.allowed)
        #expect(store.consent == .allowed)

        store.setConsent(.denied)
        #expect(store.consent == .denied)

        store.setConsent(.undecided)
        #expect(store.consent == .undecided)
    }

    @Test
    func featureSourcesDoNotWireAppContainerOrInfrastructureImplementations() throws {
        let featureFiles = try swiftSourceFiles(in: "Symi/Sources/Features")
        #expect(!featureFiles.isEmpty)
        let forbiddenReferences = [
            "AppContainer",
            "SwiftDataEpisodeRepository",
            "SwiftDataMedicationCatalogRepository",
            "SwiftDataContinuousMedicationRepository",
            "SwiftDataExportRepository",
            "AppleHealthKitService",
            "AppleWeatherKitWeatherService",
            "SystemLocationService",
            "SyncServiceAdapter"
        ]

        for file in featureFiles {
            let contents = try String(contentsOf: file, encoding: .utf8)

            for reference in forbiddenReferences {
                #expect(
                    !contents.contains(reference),
                    "\(file.lastPathComponent) verdrahtet \(reference) direkt statt Feature-Dependencies zu verwenden."
                )
            }
        }
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
    func medicationDetailTextFormatsEmptyWhitespaceAndCombinations() {
        #expect(MedicationTextFormatter.detailText(dosage: "", frequency: "").isEmpty)
        #expect(MedicationTextFormatter.detailText(dosage: "  ", frequency: "\n\t").isEmpty)
        #expect(MedicationTextFormatter.detailText(dosage: " 50 mg ", frequency: "") == "50 mg")
        #expect(MedicationTextFormatter.detailText(dosage: "", frequency: " täglich ") == "täglich")
        #expect(MedicationTextFormatter.detailText(dosage: " 50 mg ", frequency: " täglich ") == "50 mg · täglich")
    }

    @Test
    func medicationSelectionKeyNormalizesEmptyWhitespaceAndCombinations() {
        #expect(MedicationSelectionKey.make(name: "", category: .other, dosage: "") == "medication-sha256:82978ea8f0f7c687c3da6025348d05ff1374c5bef81cab2cc82e60cb31dffc65")
        #expect(MedicationSelectionKey.make(name: "  ", category: .other, dosage: "\n\t") == "medication-sha256:82978ea8f0f7c687c3da6025348d05ff1374c5bef81cab2cc82e60cb31dffc65")
        #expect(MedicationSelectionKey.make(name: " Sumatriptan ", category: .triptan, dosage: "") == "medication-sha256:d86f49430a38ae6e54ee854f9592e26a4c785384eca3bae9e4987ead9b299798")
        #expect(MedicationSelectionKey.make(name: "", category: .nsar, dosage: " 400 MG ") == "medication-sha256:b9f25953cf30b394f34897efb939cf4d2abb9efc33ccfa85ef0c260ea1cacf00")
        #expect(MedicationSelectionKey.make(name: " IBUprofen ", category: .nsar, dosage: " 400 MG ") == "medication-sha256:bd0ab64203035d1e1990e1c16f12fb23d41471aa7d2f2b070b33fc0346768081")
    }

    @Test
    func stringListStorageRoundtripsDelimiterCharactersAsJSON() {
        let values = ["Übelkeit|Aura", "Stress", "Bildschirm|Zeit"]
        let storage = StringListStorage.encode(values)

        #expect(storage == "[\"Übelkeit|Aura\",\"Stress\",\"Bildschirm|Zeit\"]")
        #expect(StringListStorage.decode(storage) == values)
        #expect(StringListStorage.decode("Übelkeit|Aura") == ["Übelkeit", "Aura"])
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
        #expect(average?.title == "Muster erkannt: Durchschnitt 6/10")
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

        #expect(average?.title == "Muster erkannt: Durchschnitt 6/10")
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

        #expect(risingTrend?.title == "Muster erkannt: häufiger höhere Intensität")
        #expect(fallingTrend?.title == "Muster erkannt: häufiger niedrigere Intensität")
    }

    @Test
    func insightEngineUsesCautiousNonDiagnosticLanguage() {
        let engine = InsightEngine()
        let start = fixedDate()
        let episodes = [
            makeEpisode(id: UUID(), startedAt: start, intensity: 8, triggers: ["Stress"]),
            makeEpisode(id: UUID(), startedAt: start.addingTimeInterval(7 * 86_400), intensity: 8, triggers: ["Stress"]),
            makeEpisode(id: UUID(), startedAt: start.addingTimeInterval(14 * 86_400), intensity: 8, triggers: ["Stress"]),
            makeEpisode(id: UUID(), startedAt: start.addingTimeInterval(21 * 86_400), intensity: 8),
            makeEpisode(id: UUID(), startedAt: start.addingTimeInterval(86_400), intensity: 7)
        ]

        let result = engine.evaluate(episodes: episodes, calendar: fixedCalendar())
        let combinedInsightText = result.insights
            .flatMap { [$0.title, $0.description] }
            .joined(separator: " ")

        #expect(combinedInsightText.contains("Muster erkannt"))
        #expect(combinedInsightText.contains("häufiger zusammen mit") || combinedInsightText.contains("in deinen Einträgen auffällig"))
        #expect(combinedInsightText.localizedCaseInsensitiveContains("Diagnose") == false)
        #expect(combinedInsightText.localizedCaseInsensitiveContains("Ursache") == false)
        #expect(combinedInsightText.localizedCaseInsensitiveContains("Risiko") == false)
        #expect(combinedInsightText.localizedCaseInsensitiveContains("du solltest") == false)
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
    func insightAggregationFiltersSupportedPeriods() {
        let calendar = fixedCalendar()
        let referenceDate = fixedDate().addingTimeInterval(40 * 86_400)
        let episodes = [
            makeEpisode(id: UUID(), startedAt: referenceDate.addingTimeInterval(-2 * 86_400), intensity: 5),
            makeEpisode(id: UUID(), startedAt: referenceDate.addingTimeInterval(-6 * 86_400), intensity: 6),
            makeEpisode(id: UUID(), startedAt: referenceDate.addingTimeInterval(-20 * 86_400), intensity: 7),
            makeEpisode(id: UUID(), startedAt: referenceDate.addingTimeInterval(-70 * 86_400), intensity: 8)
        ]

        let sevenDays = InsightEngine().evaluate(
            episodes: episodes,
            period: .sevenDays,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let thirtyDays = InsightEngine().evaluate(
            episodes: episodes,
            period: .thirtyDays,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let threeMonths = InsightEngine().evaluate(
            episodes: episodes,
            period: .threeMonths,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(sevenDays.totalQualifiedEpisodeCount == 2)
        #expect(thirtyDays.totalQualifiedEpisodeCount == 3)
        #expect(threeMonths.totalQualifiedEpisodeCount == 4)
    }

    @Test
    func insightAggregationExposesSharedMetricsForTriggersMedicationWeatherAndTrend() {
        let calendar = fixedCalendar()
        let start = fixedDate()
        let medication = MedicationRecord(
            id: UUID(),
            name: "Sumatriptan",
            category: .triptan,
            dosage: "50 mg",
            quantity: 1,
            takenAt: start,
            effectiveness: .good,
            reliefStartedAt: nil,
            isRepeatDose: false
        )
        let check = ContinuousMedicationCheckRecord(
            id: UUID(),
            continuousMedicationID: UUID(),
            name: "Metoprolol",
            dosage: "50 mg",
            frequency: "täglich",
            wasTaken: true
        )
        let weather = WeatherRecord(
            recordedAt: start,
            condition: "Regen",
            temperature: 12,
            humidity: 80,
            pressure: 1_004,
            precipitation: 2,
            weatherCode: 63,
            source: "Test",
            contextRangeStart: start.addingTimeInterval(-3_600),
            contextRangeEnd: start
        )
        let episodes = (0 ..< 5).map { offset in
            makeEpisode(
                id: UUID(),
                startedAt: start.addingTimeInterval(Double(offset) * 86_400),
                intensity: 4 + offset,
                triggers: offset < 3 ? ["Stress"] : [],
                medications: offset < 2 ? [medication] : [],
                continuousMedicationChecks: offset < 4 ? [check] : [],
                weather: offset < 2 ? weather : nil
            )
        }

        let result = InsightEngine().evaluate(
            episodes: episodes,
            period: .thirtyDays,
            referenceDate: start.addingTimeInterval(5 * 86_400),
            calendar: calendar
        )

        #expect(result.metrics.triggerSummaries.first?.name == "Stress")
        #expect(result.metrics.triggerSummaries.first?.count == 3)
        #expect(abs((result.metrics.triggerSummaries.first?.share ?? 0) - 0.6) < 0.001)
        #expect(result.metrics.acuteMedicationSummaries.first?.name == "Sumatriptan")
        #expect(result.metrics.acuteMedicationSummaries.first?.count == 2)
        #expect(result.metrics.continuousMedicationSummaries.first?.name == "Metoprolol")
        #expect(result.metrics.continuousMedicationSummaries.first?.takenCount == 4)
        #expect(result.metrics.weatherSummary.entryCountWithWeather == 2)
        #expect(result.metrics.weatherSummary.extendedContextCount == 2)
        #expect(result.metrics.dailyIntensityTrend.count == 5)
        #expect(result.metrics.dailyIntensityTrend.last?.highestIntensity == 8)
    }

    @Test
    func insightAggregationReturnsStructuredEmptyStateInsteadOfFallbackValues() {
        let result = InsightEngine().evaluate(
            episodes: [],
            period: .sevenDays,
            referenceDate: fixedDate(),
            calendar: fixedCalendar()
        )

        #expect(result.emptyState?.reason == .noQualifiedEntries)
        #expect(result.emptyState?.availableEntryCount == 0)
        #expect(result.metrics == .empty)
        #expect(result.insights.isEmpty)
    }

    @Test
    func homeStateMapsDirectlyFromEntryCount() {
        #expect(mapToHomeState(entryCount: 0) == .empty)
        #expect(mapToHomeState(entryCount: 1) == .early)
        #expect(mapToHomeState(entryCount: 4) == .early)
        #expect(mapToHomeState(entryCount: 5) == .insights)
        #expect(mapToHomeState(entryCount: 42) == .insights)
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

private final class EpisodeRepositoryMock: EpisodeRepository, Sendable {
    private struct State: Sendable {
        var recentRecords: [EpisodeRecord] = []
        var monthRecords: [EpisodeRecord] = []
        var dayRecords: [EpisodeRecord] = []
        var loadedRecord: EpisodeRecord?
        var deletedRecords: [EpisodeRecord] = []
        var lastSavedDraft: EpisodeDraft?
        var lastWeatherSnapshot: WeatherSnapshotData?
        var lastHealthContext: HealthContextSnapshotData?
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    let savedDraftID = UUID()

    var recentRecords: [EpisodeRecord] {
        get { state.withLock(\.recentRecords) }
        set { state.withLock { $0.recentRecords = newValue } }
    }
    var monthRecords: [EpisodeRecord] {
        get { state.withLock(\.monthRecords) }
        set { state.withLock { $0.monthRecords = newValue } }
    }
    var dayRecords: [EpisodeRecord] {
        get { state.withLock(\.dayRecords) }
        set { state.withLock { $0.dayRecords = newValue } }
    }
    var loadedRecord: EpisodeRecord? {
        get { state.withLock(\.loadedRecord) }
        set { state.withLock { $0.loadedRecord = newValue } }
    }
    var deletedRecords: [EpisodeRecord] {
        get { state.withLock(\.deletedRecords) }
        set { state.withLock { $0.deletedRecords = newValue } }
    }
    var lastSavedDraft: EpisodeDraft? {
        state.withLock(\.lastSavedDraft)
    }
    var lastWeatherSnapshot: WeatherSnapshotData? {
        state.withLock(\.lastWeatherSnapshot)
    }
    var lastHealthContext: HealthContextSnapshotData? {
        state.withLock(\.lastHealthContext)
    }

    func fetchRecent() throws -> [EpisodeRecord] { state.withLock(\.recentRecords) }
    func fetchByDay(_ day: Date) throws -> [EpisodeRecord] { state.withLock(\.dayRecords) }
    func fetchByMonth(_ month: Date) throws -> [EpisodeRecord] { state.withLock(\.monthRecords) }
    func load(id: UUID) throws -> EpisodeRecord? { state.withLock(\.loadedRecord) }
    func save(draft: EpisodeDraft, weatherSnapshot: WeatherSnapshotData?, healthContext: HealthContextSnapshotData?) throws -> UUID {
        state.withLock {
            $0.lastSavedDraft = draft
            $0.lastWeatherSnapshot = weatherSnapshot
            $0.lastHealthContext = healthContext
        }
        return savedDraftID
    }
    func softDelete(id: UUID) throws {}
    func restore(id: UUID) throws {}
    func fetchDeleted() throws -> [EpisodeRecord] { state.withLock(\.deletedRecords) }
}

private final class MedicationCatalogRepositoryMock: MedicationCatalogRepository, Sendable {
    private struct State: Sendable {
        var definitions: [MedicationDefinitionRecord] = []
        var deletedDefinitions: [MedicationDefinitionRecord] = []
        var savedDrafts: [CustomMedicationDefinitionDraft] = []
        var deletedCatalogKeys: [String] = []
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    var definitions: [MedicationDefinitionRecord] {
        get { state.withLock(\.definitions) }
        set { state.withLock { $0.definitions = newValue } }
    }
    var deletedDefinitions: [MedicationDefinitionRecord] {
        get { state.withLock(\.deletedDefinitions) }
        set { state.withLock { $0.deletedDefinitions = newValue } }
    }
    var savedDrafts: [CustomMedicationDefinitionDraft] {
        state.withLock(\.savedDrafts)
    }
    var deletedCatalogKeys: [String] {
        state.withLock(\.deletedCatalogKeys)
    }

    func fetchDefinitions(searchText: String?) throws -> [MedicationDefinitionRecord] {
        state.withLock(\.definitions)
    }
    func saveCustomDefinition(_ draft: CustomMedicationDefinitionDraft) throws -> MedicationDefinitionRecord {
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
        state.withLock {
            $0.savedDrafts.append(draft)
            $0.definitions.append(record)
        }
        return record
    }
    func softDeleteCustomDefinition(catalogKey: String) throws {
        state.withLock {
            $0.deletedCatalogKeys.append(catalogKey)
        }
    }
    func fetchDeletedDefinitions() throws -> [MedicationDefinitionRecord] {
        state.withLock(\.deletedDefinitions)
    }
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
    medications: [MedicationRecord] = [],
    continuousMedicationChecks: [ContinuousMedicationCheckRecord] = [],
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
        medications: medications,
        continuousMedicationChecks: continuousMedicationChecks,
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

private func swiftSourceFiles(in relativePath: String) throws -> [URL] {
    let testFileURL = URL(fileURLWithPath: #filePath)
    let repositoryRoot = testFileURL
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let directory = repositoryRoot.appending(path: relativePath, directoryHint: .isDirectory)

    guard let enumerator = FileManager.default.enumerator(
        at: directory,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }

    return try enumerator.compactMap { item -> URL? in
        guard let url = item as? URL, url.pathExtension == "swift" else {
            return nil
        }

        let values = try url.resourceValues(forKeys: [.isRegularFileKey])
        return values.isRegularFile == true ? url : nil
    }
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
