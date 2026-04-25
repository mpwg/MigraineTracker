import CoreLocation
import SwiftData
import SwiftUI
import UIKit

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
        let schema = Schema(versionedSchema: SymiSchemaV5.self)
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
        let syncCoordinator = SyncCoordinator(modelContainer: container, appLogStore: appLogStore)
        let appContainer = AppContainer(
            modelContainer: container,
            syncCoordinator: syncCoordinator,
            appLogStore: appLogStore,
            weatherService: ScreenshotWeatherService(),
            locationService: ScreenshotLocationService()
        )

        return (container, appContainer, appLogStore, syncCoordinator, seed)
    }
}

private enum ScreenshotSeedFactory {
    private static let primaryEpisodeID = UUID(uuidString: "7A2F5E3B-1BAA-4D19-8B8B-72A3B851FD11")!
    private static let secondaryEpisodeID = UUID(uuidString: "D89A45A0-D8CD-4FE2-A8F5-8A0FD5214BF4")!
    private static let tertiaryEpisodeID = UUID(uuidString: "7E7A5BFA-E4DB-44F8-A6E6-3076A8A1D1C5")!

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
        let twelveDaysAgo = calendar.date(byAdding: .day, value: -12, to: todayAtNine) ?? todayAtNine
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
            triggers: ScreenshotLocalization.list(de: ["Wetterumschwung", "Schlafmangel"], en: ["Weather change", "Lack of sleep"]),
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
            triggers: ["Stress"],
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
            triggers: ScreenshotLocalization.list(de: ["Zu wenig Wasser"], en: ["Too little water"]),
            functionalImpact: ScreenshotLocalization.text(de: "Leicht eingeschränkt", en: "Slightly limited"),
            menstruationStatus: .unknown,
            medications: [ibuprofen]
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

    var body: some View {
        rootView
            .task {
                configureMacCatalystWindowIfNeeded()
            }
    }

    @ViewBuilder
    private var rootView: some View {
        switch configuration.screenshotRoute ?? .home {
        case .home:
            NavigationStack {
                HomeView(appContainer: appContainer)
            }

        case .newEntry:
            NavigationStack {
                EpisodeEditorView(appContainer: appContainer, initialStartedAt: seed.newEntryDate)
            }

        case .history:
            NavigationStack {
                HistoryView(appContainer: appContainer)
            }

        case .episodeDetail:
            NavigationStack {
                EpisodeDetailView(appContainer: appContainer, episodeID: seed.primaryEpisodeID)
            }

        case .export:
            NavigationStack {
                DataExportView(appContainer: appContainer)
            }

        case .privacyInfo:
            NavigationStack {
                ProductInformationView(mode: .standard)
            }
        }
    }

    private func configureMacCatalystWindowIfNeeded() {
        #if targetEnvironment(macCatalyst)
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            return
        }

        let size = CGSize(width: 1280, height: 800)
        scene.sizeRestrictions?.minimumSize = size
        scene.sizeRestrictions?.maximumSize = size
        #endif
    }
}

private struct ScreenshotWeatherService: WeatherService {
    func fetchWeather(for date: Date, location: CLLocation) async throws -> WeatherSnapshotData? {
        WeatherSnapshotData(
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
