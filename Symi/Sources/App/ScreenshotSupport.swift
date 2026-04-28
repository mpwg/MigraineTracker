import CoreLocation
import SwiftData
import SwiftUI

struct AppLaunchConfiguration {
    let isScreenshotMode: Bool
    let isRunningTests: Bool
    let screenshotRoute: ScreenshotRoute?
    let screenshotSeedName: String

    static var current: AppLaunchConfiguration {
        AppLaunchConfiguration(
            arguments: ProcessInfo.processInfo.arguments,
            environment: ProcessInfo.processInfo.environment
        )
    }

    init(arguments: [String], environment: [String: String]) {
        let isFastlaneSnapshot = Self.boolValue(for: "-FASTLANE_SNAPSHOT", in: arguments) ?? false
        self.isScreenshotMode = isFastlaneSnapshot || arguments.contains("-ui_testing")
        self.isRunningTests = environment["XCTestConfigurationFilePath"] != nil
        self.screenshotRoute = Self.value(for: "-mt_screenshot_screen", in: arguments).flatMap(ScreenshotRoute.init(rawValue:))
        self.screenshotSeedName = Self.value(for: "-mt_screenshot_seed", in: arguments) ?? "default"
    }

    private static func value(for key: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: key), arguments.indices.contains(index + 1) else {
            return nil
        }

        return arguments[index + 1]
    }

    private static func boolValue(for key: String, in arguments: [String]) -> Bool? {
        guard let value = value(for: key, in: arguments) else {
            return nil
        }

        switch value.lowercased() {
        case "1", "true", "yes", "on":
            return true
        case "0", "false", "no", "off":
            return false
        default:
            return nil
        }
    }
}

enum ScreenshotRoute: String, CaseIterable {
    case home
    case newEntry = "new-entry"
    case insights
    case history
    case episodeDetail = "episode-detail"
    case export
    case privacyInfo = "privacy-info"
}

enum ScreenshotLocalization {
    static var isEnglish: Bool {
        Locale.current.language.languageCode?.identifier == "en"
    }

    static func text(de german: String, en english: String) -> String {
        isEnglish ? english : german
    }

    static func list(de german: [String], en english: [String]) -> [String] {
        isEnglish ? english : german
    }
}

struct ScreenshotSeed {
    let primaryEpisodeID: UUID
    let newEntryDate: Date
}

enum ScreenshotBootstrap {
    @MainActor
    static func makeEnvironment(seedName: String) throws -> (ModelContainer, AppContainer, AppLogStore, SyncCoordinator, ScreenshotSeed) {
        let schema = Schema(versionedSchema: SymiSchemaV6.self)
        let storeURL = FileManager.default.temporaryDirectory.appending(path: "Symi-Screenshots-\(UUID().uuidString).store")
        let configuration = ModelConfiguration(
            "default",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )

        let container = try ModelContainer(
            for: schema,
            migrationPlan: SymiMigrationPlan.self,
            configurations: [configuration]
        )

        MedicationCatalog.importSeedDataIfNeeded(into: container)

        let seed = try ScreenshotSeedFactory.populate(seedName: seedName, in: container)
        let appLogStore = AppLogStore()
        let healthContextStore = HealthContextStore()
        let syncCoordinator = SyncCoordinator(
            modelContainer: container,
            appLogStore: appLogStore,
            healthContextStore: healthContextStore
        )
        let appContainer = AppContainer(
            modelContainer: container,
            syncCoordinator: syncCoordinator,
            appLogStore: appLogStore,
            weatherService: ScreenshotWeatherService(),
            locationService: ScreenshotLocationService(),
            healthContextStore: healthContextStore
        )

        return (container, appContainer, appLogStore, syncCoordinator, seed)
    }
}

private enum ScreenshotSeedFactory {
    private static let primaryEpisodeID = UUID(uuidString: "7A2F5E3B-1BAA-4D19-8B8B-72A3B851FD11")!
    private static let secondaryEpisodeID = UUID(uuidString: "D89A45A0-D8CD-4FE2-A8F5-8A0FD5214BF4")!
    private static let tertiaryEpisodeID = UUID(uuidString: "7E7A5BFA-E4DB-44F8-A6E6-3076A8A1D1C5")!
    private static let quaternaryEpisodeID = UUID(uuidString: "5398D70C-6F4E-470B-AB63-46B8437E784B")!
    private static let quinaryEpisodeID = UUID(uuidString: "283C3C98-1E79-4304-9D42-11E093FB3089")!
    private static let senaryEpisodeID = UUID(uuidString: "6B8DBFB1-7A35-4D05-B287-AF45DD457E51")!

    @MainActor
    static func populate(seedName: String, in container: ModelContainer) throws -> ScreenshotSeed {
        guard seedName == "default" else {
            throw CocoaError(.featureUnsupported)
        }

        let context = container.mainContext
        let calendar = Calendar.current
        let now = Date()
        let todayAtNine = calendar.date(bySettingHour: 9, minute: 15, second: 0, of: now) ?? now
        let fourDaysAgo = calendar.date(byAdding: .day, value: -4, to: todayAtNine) ?? todayAtNine
        let eightDaysAgo = calendar.date(byAdding: .day, value: -8, to: todayAtNine) ?? todayAtNine
        let twelveDaysAgo = calendar.date(byAdding: .day, value: -12, to: todayAtNine) ?? todayAtNine
        let eighteenDaysAgo = calendar.date(byAdding: .day, value: -18, to: todayAtNine) ?? todayAtNine
        let twentyFourDaysAgo = calendar.date(byAdding: .day, value: -24, to: todayAtNine) ?? todayAtNine
        let sumatriptan = MedicationEntry(
            name: "Sumatriptan",
            category: .triptan,
            dosage: "50 mg",
            quantity: 1,
            takenAt: todayAtNine.addingTimeInterval(45 * 60),
            effectiveness: .good
        )
        let magnesium = MedicationEntry(
            name: "Magnesium",
            category: .other,
            dosage: "400 mg",
            quantity: 1,
            takenAt: fourDaysAgo.addingTimeInterval(30 * 60),
            effectiveness: .partial
        )
        let ibuprofen = MedicationEntry(
            name: "Ibuprofen",
            category: .nsar,
            dosage: "400 mg",
            quantity: 2,
            takenAt: twelveDaysAgo.addingTimeInterval(20 * 60),
            effectiveness: .partial,
            isRepeatDose: true
        )

        let primaryEpisode = Episode(
            id: primaryEpisodeID,
            startedAt: todayAtNine,
            endedAt: todayAtNine.addingTimeInterval(3.5 * 60 * 60),
            type: .migraine,
            intensity: 8,
            painLocation: ScreenshotLocalization.text(de: "links orbital", en: "left orbital"),
            painCharacter: ScreenshotLocalization.text(de: "pochend", en: "throbbing"),
            notes: ScreenshotLocalization.text(
                de: "Screen-Seed: Dunkler Raum, Wasser und kurze Pause haben geholfen.",
                en: "Screen seed: a dark room, water and a short break helped."
            ),
            symptoms: ScreenshotLocalization.list(de: ["Übelkeit", "Lichtempfindlichkeit", "Aura"], en: ["Nausea", "Light sensitivity", "Aura"]),
            triggers: ScreenshotLocalization.list(de: ["Wetter", "Stress"], en: ["Weather", "Stress"]),
            functionalImpact: ScreenshotLocalization.text(de: "Arbeit nur eingeschränkt möglich", en: "Work only possible with limitations"),
            menstruationStatus: .expected,
            medications: [sumatriptan]
        )
        let secondaryEpisode = Episode(
            id: secondaryEpisodeID,
            startedAt: fourDaysAgo,
            endedAt: fourDaysAgo.addingTimeInterval(2 * 60 * 60),
            type: .headache,
            intensity: 6,
            painLocation: ScreenshotLocalization.text(de: "beidseitig frontal", en: "bilateral frontal"),
            painCharacter: ScreenshotLocalization.text(de: "drückend", en: "pressing"),
            notes: ScreenshotLocalization.text(de: "Viel Bildschirmarbeit am Nachmittag.", en: "A lot of screen work in the afternoon."),
            symptoms: ScreenshotLocalization.list(de: ["Verspannung"], en: ["Tension"]),
            triggers: ScreenshotLocalization.list(de: ["Stress", "erhöhte Arbeitsbelastung"], en: ["Stress", "High workload"]),
            functionalImpact: ScreenshotLocalization.text(de: "Konzentration reduziert", en: "Reduced concentration"),
            menstruationStatus: .none,
            medications: [magnesium]
        )
        let tertiaryEpisode = Episode(
            id: tertiaryEpisodeID,
            startedAt: twelveDaysAgo,
            endedAt: twelveDaysAgo.addingTimeInterval(90 * 60),
            type: .unclear,
            intensity: 4,
            painLocation: ScreenshotLocalization.text(de: "Hinterkopf", en: "back of head"),
            painCharacter: ScreenshotLocalization.text(de: "dumpf", en: "dull"),
            notes: ScreenshotLocalization.text(de: "Kurzer Verlauf ohne weitere Auffälligkeiten.", en: "Short episode without other notable issues."),
            symptoms: ScreenshotLocalization.list(de: ["Müdigkeit"], en: ["Fatigue"]),
            triggers: ScreenshotLocalization.list(de: ["Schlafdauer"], en: ["Sleep duration"]),
            functionalImpact: ScreenshotLocalization.text(de: "Leicht eingeschränkt", en: "Slightly limited"),
            menstruationStatus: .unknown,
            medications: [ibuprofen]
        )
        let quaternaryEpisode = Episode(
            id: quaternaryEpisodeID,
            startedAt: eightDaysAgo,
            endedAt: eightDaysAgo.addingTimeInterval(2.5 * 60 * 60),
            type: .migraine,
            intensity: 7,
            painLocation: ScreenshotLocalization.text(de: "rechte Schläfe", en: "right temple"),
            painCharacter: ScreenshotLocalization.text(de: "pulsierend", en: "pulsating"),
            notes: ScreenshotLocalization.text(de: "Nach langem Arbeitsblock bewusst Pausen eingeplant.", en: "Planned breaks after a long work block."),
            symptoms: ScreenshotLocalization.list(de: ["Lichtempfindlichkeit"], en: ["Light sensitivity"]),
            triggers: ScreenshotLocalization.list(de: ["Stress", "erhöhte Arbeitsbelastung"], en: ["Stress", "High workload"]),
            functionalImpact: ScreenshotLocalization.text(de: "Ruhiger Nachmittag nötig", en: "Quiet afternoon needed"),
            menstruationStatus: .none,
            medications: []
        )
        let quinaryEpisode = Episode(
            id: quinaryEpisodeID,
            startedAt: eighteenDaysAgo.addingTimeInterval(7 * 60 * 60),
            endedAt: eighteenDaysAgo.addingTimeInterval(9 * 60 * 60),
            type: .headache,
            intensity: 5,
            painLocation: ScreenshotLocalization.text(de: "Stirn", en: "forehead"),
            painCharacter: ScreenshotLocalization.text(de: "drückend", en: "pressing"),
            notes: ScreenshotLocalization.text(de: "Nach Sport und Essen rasch besser geworden.", en: "Improved quickly after exercise and food."),
            symptoms: ScreenshotLocalization.list(de: ["Müdigkeit"], en: ["Fatigue"]),
            triggers: ScreenshotLocalization.list(de: ["Stress", "Sport"], en: ["Stress", "Exercise"]),
            functionalImpact: ScreenshotLocalization.text(de: "Kurze Pause reichte", en: "A short break was enough"),
            menstruationStatus: .none,
            medications: []
        )
        let senaryEpisode = Episode(
            id: senaryEpisodeID,
            startedAt: twentyFourDaysAgo.addingTimeInterval(12 * 60 * 60),
            endedAt: twentyFourDaysAgo.addingTimeInterval(15 * 60 * 60),
            type: .migraine,
            intensity: 8,
            painLocation: ScreenshotLocalization.text(de: "Schläfen", en: "temples"),
            painCharacter: ScreenshotLocalization.text(de: "pochend", en: "throbbing"),
            notes: ScreenshotLocalization.text(de: "Wetterwechsel und Zykluskontext notiert.", en: "Weather change and cycle context noted."),
            symptoms: ScreenshotLocalization.list(de: ["Übelkeit", "Geräuschempfindlichkeit"], en: ["Nausea", "Sound sensitivity"]),
            triggers: ScreenshotLocalization.list(de: ["Wetter", "Stress", "Regel"], en: ["Weather", "Stress", "Period"]),
            functionalImpact: ScreenshotLocalization.text(de: "Tagesplanung angepasst", en: "Adjusted daily plans"),
            menstruationStatus: .active,
            medications: []
        )

        let weatherSnapshot = WeatherSnapshot(
            snapshot: WeatherSnapshotData(
                recordedAt: todayAtNine,
                condition: ScreenshotLocalization.text(de: "Leichter Regen", en: "Light rain"),
                temperature: 16.3,
                humidity: 74,
                pressure: 1007,
                precipitation: 0.7,
                weatherCode: 61,
                source: "Apple Weather Demo"
            ),
            episode: primaryEpisode
        )
        primaryEpisode.weatherSnapshot = weatherSnapshot

        context.insert(primaryEpisode)
        context.insert(secondaryEpisode)
        context.insert(tertiaryEpisode)
        context.insert(quaternaryEpisode)
        context.insert(quinaryEpisode)
        context.insert(senaryEpisode)
        context.insert(sumatriptan)
        context.insert(magnesium)
        context.insert(ibuprofen)
        context.insert(weatherSnapshot)

        try context.save()

        return ScreenshotSeed(
            primaryEpisodeID: primaryEpisodeID,
            newEntryDate: calendar.date(bySettingHour: 7, minute: 40, second: 0, of: now) ?? now
        )
    }
}

struct ScreenshotRootView: View {
    let appContainer: AppContainer
    let configuration: AppLaunchConfiguration
    let seed: ScreenshotSeed
    private var features: AppFeatureDependencies { appContainer.featureDependencies }

    var body: some View {
        rootView
    }

    @ViewBuilder
    private var rootView: some View {
        switch configuration.screenshotRoute ?? .home {
        case .home:
            NavigationStack {
                HomeView(dependencies: features.home)
            }

        case .newEntry:
            EntryFlowCoordinatorView(dependencies: features.capture, initialStartedAt: seed.newEntryDate)

        case .insights:
            NavigationStack {
                InsightsView(dependencies: features.insights)
            }

        case .history:
            NavigationStack {
                HistoryView(dependencies: features.history)
            }

        case .episodeDetail:
            NavigationStack {
                EpisodeDetailView(dependencies: features.history, episodeID: seed.primaryEpisodeID)
            }

        case .export:
            NavigationStack {
                DataExportView(dependencies: features.dataExport)
            }

        case .privacyInfo:
            NavigationStack {
                ProductInformationView(mode: .standard)
            }
        }
    }

}

private struct ScreenshotWeatherService: WeatherService {
    func fetchWeather(for date: Date, location: CLLocation) async throws -> WeatherSnapshotData? {
        if ProcessInfo.processInfo.arguments.contains("-mt_disable_weather") {
            return nil
        }

        return WeatherSnapshotData(
            recordedAt: date,
            condition: "Leichter Regen",
            temperature: 16.3,
            humidity: 74,
            pressure: 1007,
            precipitation: 0.7,
            weatherCode: 61,
            source: "Apple Weather Demo"
        )
    }
}

@MainActor
private final class ScreenshotLocationService: LocationService {
    func requestApproximateLocation() async throws -> CLLocation {
        CLLocation(latitude: 48.2082, longitude: 16.3738)
    }
}
