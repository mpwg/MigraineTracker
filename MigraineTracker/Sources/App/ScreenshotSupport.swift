import CoreLocation
import SwiftData
import SwiftUI
import UIKit

struct AppLaunchConfiguration {
    let isScreenshotMode: Bool
    let screenshotRoute: ScreenshotRoute?
    let screenshotSeedName: String

    static var current: AppLaunchConfiguration {
        AppLaunchConfiguration(arguments: ProcessInfo.processInfo.arguments)
    }

    init(arguments: [String]) {
        let isFastlaneSnapshot = Self.boolValue(for: "-FASTLANE_SNAPSHOT", in: arguments) ?? false
        self.isScreenshotMode = isFastlaneSnapshot || arguments.contains("-ui_testing")
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
    case doctors
    case doctorDetail = "doctor-detail"
    case doctorAdd = "doctor-add"
    case appointmentFlow = "appointment-flow"
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
    let primaryDoctorID: UUID
    let newEntryDate: Date
}

enum ScreenshotBootstrap {
    @MainActor
    static func makeEnvironment(seedName: String) throws -> (ModelContainer, AppContainer, AppLogStore, SyncCoordinator, ScreenshotSeed) {
        let schema = Schema(versionedSchema: MigraineTrackerSchemaV4.self)
        let storeURL = FileManager.default.temporaryDirectory.appending(path: "MigraineTracker-Screenshots-\(UUID().uuidString).store")
        let configuration = ModelConfiguration(
            "default",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )

        let container = try ModelContainer(
            for: schema,
            migrationPlan: MigraineTrackerMigrationPlan.self,
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
            locationService: ScreenshotLocationService(),
            notificationService: ScreenshotNotificationService()
        )

        return (container, appContainer, appLogStore, syncCoordinator, seed)
    }
}

private enum ScreenshotSeedFactory {
    private static let primaryEpisodeID = UUID(uuidString: "7A2F5E3B-1BAA-4D19-8B8B-72A3B851FD11")!
    private static let secondaryEpisodeID = UUID(uuidString: "D89A45A0-D8CD-4FE2-A8F5-8A0FD5214BF4")!
    private static let tertiaryEpisodeID = UUID(uuidString: "7E7A5BFA-E4DB-44F8-A6E6-3076A8A1D1C5")!
    private static let primaryDoctorID = UUID(uuidString: "3C598CA0-CFE2-4E89-91C3-9C41DF8672F2")!
    private static let secondaryDoctorID = UUID(uuidString: "F6F2725D-5AA7-42B4-95AC-0BFB38E7776C")!
    private static let primaryAppointmentID = UUID(uuidString: "60B740D7-6DE7-4D4E-A5C0-6CA3BA7F7E50")!
    private static let secondaryAppointmentID = UUID(uuidString: "0B4F1B36-29D6-4354-BF4F-327099F46724")!

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
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: now) ?? now
        let nextMonth = calendar.date(byAdding: .day, value: 24, to: now) ?? now

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
                source: "Open-Meteo Demo"
            ),
            episode: primaryEpisode
        )
        primaryEpisode.weatherSnapshot = weatherSnapshot

        let doctor = Doctor(
            id: primaryDoctorID,
            createdAt: calendar.date(byAdding: .month, value: -4, to: now) ?? now,
            updatedAt: now,
            name: "Dr. Clara Heiden",
            specialty: ScreenshotLocalization.text(de: "Neurologie", en: "Neurology"),
            street: "Lindenhofgasse 12",
            city: "Wien",
            state: "Wien",
            postalCode: "1010",
            phone: "+43 1 000 12 34",
            email: "ordination.heiden@example.com",
            notes: ScreenshotLocalization.text(de: "Fiktive Beispielärztin für Migräneprophylaxe.", en: "Fictional sample doctor for migraine prevention."),
            sourceRaw: DoctorSource.oegkDirectory.rawValue
        )
        let secondDoctor = Doctor(
            id: secondaryDoctorID,
            createdAt: calendar.date(byAdding: .month, value: -2, to: now) ?? now,
            updatedAt: now,
            name: "Dr. Mira Sonnberg",
            specialty: ScreenshotLocalization.text(de: "Allgemeinmedizin", en: "General medicine"),
            street: "Auenweg 5",
            city: "Wien",
            state: "Wien",
            postalCode: "1070",
            phone: "+43 1 000 56 78",
            email: "praxis.sonnberg@example.com",
            notes: ScreenshotLocalization.text(de: "Fiktiver Beispielkontakt für Verlaufskontrollen.", en: "Fictional sample contact for follow-up visits."),
            sourceRaw: DoctorSource.manual.rawValue
        )

        let primaryAppointment = DoctorAppointment(
            id: primaryAppointmentID,
            createdAt: now,
            updatedAt: now,
            scheduledAt: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: nextWeek) ?? nextWeek,
            endsAt: calendar.date(bySettingHour: 14, minute: 45, second: 0, of: nextWeek),
            practiceName: "Ordination Dr. Clara Heiden",
            addressText: "Lindenhofgasse 12, 1010 Wien",
            note: ScreenshotLocalization.text(de: "Gespräch zu Triggern und Prophylaxe.", en: "Discussion about triggers and prevention."),
            reminderEnabled: true,
            reminderLeadTimeMinutes: 24 * 60,
            notificationStatusRaw: AppointmentReminderStatus.scheduled.rawValue,
            notificationRequestID: "screen-primary-appointment",
            doctor: doctor
        )
        let secondAppointment = DoctorAppointment(
            id: secondaryAppointmentID,
            createdAt: now,
            updatedAt: now,
            scheduledAt: calendar.date(bySettingHour: 9, minute: 30, second: 0, of: nextMonth) ?? nextMonth,
            endsAt: nil,
            practiceName: ScreenshotLocalization.text(de: "Praxis Dr. Mira Sonnberg", en: "Practice Dr. Mira Sonnberg"),
            addressText: "Auenweg 5, 1070 Wien",
            note: ScreenshotLocalization.text(de: "Kontrolle Blutdruck und Begleitmedikation.", en: "Blood pressure and accompanying medication check."),
            reminderEnabled: true,
            reminderLeadTimeMinutes: 120,
            notificationStatusRaw: AppointmentReminderStatus.authorized.rawValue,
            notificationRequestID: "screen-secondary-appointment",
            doctor: secondDoctor
        )

        context.insert(primaryEpisode)
        context.insert(secondaryEpisode)
        context.insert(tertiaryEpisode)
        context.insert(sumatriptan)
        context.insert(magnesium)
        context.insert(ibuprofen)
        context.insert(weatherSnapshot)
        context.insert(doctor)
        context.insert(secondDoctor)
        context.insert(primaryAppointment)
        context.insert(secondAppointment)
        for entry in sampleDoctorDirectoryEntries() {
            context.insert(entry)
        }

        try context.save()

        return ScreenshotSeed(
            primaryEpisodeID: primaryEpisodeID,
            primaryDoctorID: primaryDoctorID,
            newEntryDate: calendar.date(bySettingHour: 7, minute: 40, second: 0, of: now) ?? now
        )
    }

    private static func sampleDoctorDirectoryEntries() -> [DoctorDirectoryEntry] {
        [
            DoctorDirectoryEntry(
                id: "screenshot-doctor-clara-heiden",
                name: "Dr. Clara Heiden",
                specialty: ScreenshotLocalization.text(de: "Neurologie", en: "Neurology"),
                street: "Lindenhofgasse 12",
                city: "Wien",
                state: "Wien",
                postalCode: "1010",
                sourceLabel: ScreenshotLocalization.text(de: "Musterverzeichnis für App-Store-Screenshots", en: "Sample directory for App Store screenshots"),
                sourceURL: "https://example.com/app-store-screenshots"
            ),
            DoctorDirectoryEntry(
                id: "screenshot-doctor-mira-sonnberg",
                name: "Dr. Mira Sonnberg",
                specialty: ScreenshotLocalization.text(de: "Allgemeinmedizin", en: "General medicine"),
                street: "Auenweg 5",
                city: "Wien",
                state: "Wien",
                postalCode: "1070",
                sourceLabel: ScreenshotLocalization.text(de: "Musterverzeichnis für App-Store-Screenshots", en: "Sample directory for App Store screenshots"),
                sourceURL: "https://example.com/app-store-screenshots"
            ),
            DoctorDirectoryEntry(
                id: "screenshot-doctor-jonas-erlach",
                name: "Dr. Jonas Erlach",
                specialty: ScreenshotLocalization.text(de: "Schmerzambulanz", en: "Pain clinic"),
                street: "Parkring 8",
                city: "Graz",
                state: "Steiermark",
                postalCode: "8010",
                sourceLabel: ScreenshotLocalization.text(de: "Musterverzeichnis für App-Store-Screenshots", en: "Sample directory for App Store screenshots"),
                sourceURL: "https://example.com/app-store-screenshots"
            )
        ]
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

        case .doctors:
            NavigationStack {
                ScreenshotDoctorsListView(appContainer: appContainer)
            }

        case .doctorDetail:
            NavigationStack {
                DoctorDetailView(appContainer: appContainer, doctorID: seed.primaryDoctorID)
            }

        case .doctorAdd:
            NavigationStack {
                DoctorAddFlowView(
                    appContainer: appContainer,
                    startMode: .oegkDirectory,
                    initialSearchText: ScreenshotLocalization.text(de: "Neurologie", en: "Neurology")
                )
            }

        case .appointmentFlow:
            NavigationStack {
                ScreenshotAppointmentFlowView(appContainer: appContainer, doctorID: seed.primaryDoctorID)
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

private struct ScreenshotDoctorsListView: View {
    let appContainer: AppContainer

    @State private var doctors: [DoctorRecord]

    init(appContainer: AppContainer) {
        self.appContainer = appContainer
        _doctors = State(initialValue: (try? appContainer.doctorRepository.fetchAll()) ?? [])
    }

    var body: some View {
        List {
            Section {
                Label("Arzt hinzufügen", systemImage: "cross.case.fill")
                    .brandGroupedRow()
            } footer: {
                Text("Die Liste zeigt Beispieldaten für den Screenshot-Modus.")
            }

            Section("Meine Ärzte") {
                ForEach(doctors) { doctor in
                    NavigationLink {
                        DoctorDetailView(appContainer: appContainer, doctorID: doctor.id)
                    } label: {
                        DoctorSummaryRow(doctor: doctor)
                    }
                }
            }
        }
        .navigationTitle("Ärzte")
        .brandGroupedScreen()
        .refreshable {
            doctors = (try? appContainer.doctorRepository.fetchAll()) ?? []
        }
    }
}

private struct ScreenshotAppointmentFlowView: View {
    let appContainer: AppContainer
    let doctorID: UUID

    @State private var doctor: DoctorRecord?

    init(appContainer: AppContainer, doctorID: UUID) {
        self.appContainer = appContainer
        self.doctorID = doctorID
        _doctor = State(initialValue: try? appContainer.doctorRepository.load(id: doctorID))
    }

    var body: some View {
        Group {
            if let doctor {
                AppointmentEditorView(appContainer: appContainer, doctor: doctor, appointmentID: nil)
            } else {
                ContentUnavailableView("Arzt nicht gefunden", systemImage: "exclamationmark.triangle")
            }
        }
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
            source: "Open-Meteo Demo"
        )
    }
}

@MainActor
private final class ScreenshotLocationService: LocationService {
    func requestApproximateLocation() async throws -> CLLocation {
        CLLocation(latitude: 48.2082, longitude: 16.3738)
    }
}

private final class ScreenshotNotificationService: NotificationService {
    func scheduleAppointmentReminder(for appointment: AppointmentRecord, doctor: DoctorRecord) async -> ReminderSchedulingResult {
        ReminderSchedulingResult(status: .scheduled, requestID: "screenshot-reminder-\(appointment.id.uuidString)")
    }

    func removePendingNotification(requestID: String) async {
    }
}
