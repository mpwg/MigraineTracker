import Foundation
import SwiftData

enum AppStoreScreenshotMode {
    private static let enabledKeys = [
        "APP_STORE_SCREENSHOTS",
        "FASTLANE_SNAPSHOT"
    ]

    static var isEnabled: Bool {
        let environment = ProcessInfo.processInfo.environment
        let arguments = Set(ProcessInfo.processInfo.arguments)

        for key in enabledKeys {
            if let value = environment[key], isTruthy(value) {
                return true
            }

            if arguments.contains(key) || arguments.contains("-\(key)") {
                return true
            }
        }

        return false
    }

    static func storeURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("app-store-screenshots.store")
    }

    static func resetStoreIfNeeded() throws {
        guard isEnabled else {
            return
        }

        let storeURL = storeURL()
        let basePath = storeURL.path
        let paths = [
            basePath,
            "\(basePath)-shm",
            "\(basePath)-wal"
        ]

        for path in paths where FileManager.default.fileExists(atPath: path) {
            try FileManager.default.removeItem(atPath: path)
        }
    }

    static func seed(into container: ModelContainer) {
        guard isEnabled else {
            return
        }

        let context = ModelContext(container)

        do {
            let existingEpisodes = try context.fetch(FetchDescriptor<Episode>())
            let existingDoctors = try context.fetch(FetchDescriptor<Doctor>())
            let existingAppointments = try context.fetch(FetchDescriptor<DoctorAppointment>())
            let existingDefinitions = try context.fetch(FetchDescriptor<MedicationDefinition>())
            let existingDirectoryEntries = try context.fetch(FetchDescriptor<DoctorDirectoryEntry>())

            for appointment in existingAppointments {
                context.delete(appointment)
            }

            for doctor in existingDoctors {
                context.delete(doctor)
            }

            for episode in existingEpisodes {
                context.delete(episode)
            }

            for definition in existingDefinitions {
                context.delete(definition)
            }

            for entry in existingDirectoryEntries {
                context.delete(entry)
            }

            let calendar = Calendar(identifier: .gregorian)
            let today = calendar.startOfDay(for: .now)
            let medications = sampleMedicationDefinitions()
            let directoryEntries = sampleDoctorDirectoryEntries()

            let doctorOne = Doctor(
                name: "Dr. Clara Heiden",
                specialty: ScreenshotLocalization.text(de: "Neurologie", en: "Neurology"),
                street: "Lindenhofgasse 12",
                city: "Wien",
                state: "Wien",
                postalCode: "1010",
                phone: "01 2345678",
                email: "ordination.clara.heiden@example.com",
                notes: ScreenshotLocalization.text(de: "Beispielkontakt für App-Store-Screenshots.", en: "Sample contact for App Store screenshots."),
                sourceRaw: DoctorSource.manual.rawValue
            )

            let doctorTwo = Doctor(
                name: "Dr. Mira Sonnberg",
                specialty: ScreenshotLocalization.text(de: "Allgemeinmedizin", en: "General medicine"),
                street: "Auenweg 5",
                city: "Wien",
                state: "Wien",
                postalCode: "1070",
                phone: "01 8765432",
                email: "ordination.mira.sonnberg@example.com",
                notes: ScreenshotLocalization.text(de: "Anonymisierte Demo-Daten.", en: "Anonymized demo data."),
                sourceRaw: DoctorSource.manual.rawValue
            )

            let appointment = DoctorAppointment(
                scheduledAt: calendar.date(bySettingHour: 9, minute: 15, second: 0, of: today.addingTimeInterval(2 * 24 * 60 * 60)) ?? today,
                endsAt: calendar.date(bySettingHour: 9, minute: 45, second: 0, of: today.addingTimeInterval(2 * 24 * 60 * 60)),
                practiceName: ScreenshotLocalization.text(de: "Ordination Dr. Clara Heiden", en: "Practice Dr. Clara Heiden"),
                addressText: "Lindenhofgasse 12, 1010 Wien",
                note: ScreenshotLocalization.text(de: "Verlaufsgespräch und Anpassung des Akutplans.", en: "Follow-up discussion and adjustment of the acute plan."),
                reminderEnabled: true,
                reminderLeadTimeMinutes: 24 * 60,
                notificationStatusRaw: AppointmentReminderStatus.scheduled.rawValue,
                doctor: doctorOne
            )

            let episodes = sampleEpisodes(relativeTo: today, calendar: calendar)

            context.insert(doctorOne)
            context.insert(doctorTwo)
            context.insert(appointment)

            for medication in medications {
                context.insert(medication)
            }

            for entry in directoryEntries {
                context.insert(entry)
            }

            for episode in episodes {
                context.insert(episode)
            }

            try context.save()
        } catch {
            assertionFailure("Screenshot-Daten konnten nicht vorbereitet werden: \(error)")
        }
    }

    static func sampleDraft(initialStartedAt: Date?) -> EpisodeDraft {
        let calendar = Calendar(identifier: .gregorian)
        let startedAt = initialStartedAt ?? calendar.date(bySettingHour: 7, minute: 40, second: 0, of: .now) ?? .now

        return EpisodeDraft(
            id: nil,
            type: .migraine,
            intensity: 6,
            startedAt: startedAt,
            endedAtEnabled: false,
            endedAt: startedAt,
            painLocation: ScreenshotLocalization.text(de: "rechte Schläfe", en: "right temple"),
            painCharacter: ScreenshotLocalization.text(de: "pochend", en: "throbbing"),
            notes: ScreenshotLocalization.text(
                de: "Beispieldaten für den App Store. Nach einer ruhigen Pause wurde es besser.",
                en: "Sample App Store data. It improved after a quiet break."
            ),
            functionalImpact: ScreenshotLocalization.text(de: "Arbeit in ruhiger Umgebung fortgesetzt", en: "Work continued in a quiet environment"),
            menstruationStatus: .unknown,
            selectedSymptoms: Set(ScreenshotLocalization.list(de: ["Übelkeit", "Lichtempfindlichkeit"], en: ["Nausea", "Light sensitivity"])),
            selectedTriggers: Set(ScreenshotLocalization.list(de: ["Stress", "Bildschirmzeit"], en: ["Stress", "Screen time"])),
            medications: [
                MedicationSelectionDraft(
                    selectionKey: MedicationSelectionDraft.makeSelectionKey(
                        name: "Paracetamol",
                        category: .paracetamol,
                        dosage: "500 mg"
                    ),
                    name: "Paracetamol",
                    category: .paracetamol,
                    dosage: "500 mg",
                    quantity: 1
                )
            ]
        )
    }

    static func sampleWeatherSnapshot(for startedAt: Date) -> WeatherSnapshotData {
        WeatherSnapshotData(
            recordedAt: startedAt,
            condition: ScreenshotLocalization.text(de: "Leicht bewölkt", en: "Partly cloudy"),
            temperature: 17.8,
            humidity: 62,
            pressure: 1016,
            precipitation: 0.0,
            weatherCode: 2,
            source: ScreenshotLocalization.text(de: "Beispielwetter", en: "Sample weather")
        )
    }

    private static func sampleEpisodes(relativeTo today: Date, calendar: Calendar) -> [Episode] {
        let todayMorning = calendar.date(bySettingHour: 7, minute: 40, second: 0, of: today) ?? today
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: todayMorning) ?? todayMorning
        let eightDaysAgo = calendar.date(byAdding: .day, value: -8, to: todayMorning) ?? todayMorning
        let fifteenDaysAgo = calendar.date(byAdding: .day, value: -15, to: todayMorning) ?? todayMorning

        let episodeOne = Episode(
            startedAt: todayMorning,
            endedAt: calendar.date(byAdding: .hour, value: 3, to: todayMorning),
            type: .migraine,
            intensity: 6,
            painLocation: ScreenshotLocalization.text(de: "rechte Schläfe", en: "right temple"),
            painCharacter: ScreenshotLocalization.text(de: "pochend", en: "throbbing"),
            notes: ScreenshotLocalization.text(de: "Beispieldaten für App-Store-Screenshots.", en: "Sample data for App Store screenshots."),
            symptoms: ScreenshotLocalization.list(de: ["Übelkeit", "Lichtempfindlichkeit"], en: ["Nausea", "Light sensitivity"]),
            triggers: ScreenshotLocalization.list(de: ["Stress", "Bildschirmzeit"], en: ["Stress", "Screen time"]),
            functionalImpact: ScreenshotLocalization.text(de: "Ruhiger Vormittag mit Pausen", en: "Quiet morning with breaks"),
            medications: [
                MedicationEntry(
                    name: "Paracetamol",
                    category: .paracetamol,
                    dosage: "500 mg",
                    takenAt: calendar.date(byAdding: .minute, value: 20, to: todayMorning) ?? todayMorning,
                    effectiveness: .good,
                    reliefStartedAt: calendar.date(byAdding: .minute, value: 70, to: todayMorning)
                )
            ]
        )
        episodeOne.weatherSnapshot = WeatherSnapshot(snapshot: sampleWeatherSnapshot(for: todayMorning), episode: episodeOne)

        let episodeTwo = Episode(
            startedAt: threeDaysAgo,
            endedAt: calendar.date(byAdding: .hour, value: 2, to: threeDaysAgo),
            type: .headache,
            intensity: 4,
            painLocation: ScreenshotLocalization.text(de: "Stirn", en: "forehead"),
            painCharacter: ScreenshotLocalization.text(de: "dumpf", en: "dull"),
            notes: ScreenshotLocalization.text(de: "Nach Wasser und kurzer Pause abgeklungen.", en: "Settled after water and a short break."),
            symptoms: ScreenshotLocalization.list(de: ["Geräuschempfindlichkeit"], en: ["Sound sensitivity"]),
            triggers: ScreenshotLocalization.list(de: ["Schlafmangel"], en: ["Lack of sleep"]),
            functionalImpact: ScreenshotLocalization.text(de: "Kurze Pause am Nachmittag", en: "Short break in the afternoon"),
            medications: [
                MedicationEntry(
                    name: "Ibuprofen",
                    category: .nsar,
                    dosage: "400 mg",
                    takenAt: calendar.date(byAdding: .minute, value: 15, to: threeDaysAgo) ?? threeDaysAgo,
                    effectiveness: .good
                )
            ]
        )
        episodeTwo.weatherSnapshot = WeatherSnapshot(snapshot: sampleWeatherSnapshot(for: threeDaysAgo), episode: episodeTwo)

        let episodeThree = Episode(
            startedAt: eightDaysAgo,
            endedAt: calendar.date(byAdding: .hour, value: 5, to: eightDaysAgo),
            type: .migraine,
            intensity: 8,
            painLocation: ScreenshotLocalization.text(de: "links frontal", en: "left frontal"),
            painCharacter: ScreenshotLocalization.text(de: "pulsierend", en: "pulsating"),
            notes: ScreenshotLocalization.text(de: "Rückzug in einen abgedunkelten Raum.", en: "Retreated to a darkened room."),
            symptoms: ScreenshotLocalization.list(de: ["Aura", "Lichtempfindlichkeit", "Übelkeit"], en: ["Aura", "Light sensitivity", "Nausea"]),
            triggers: ["Stress"],
            functionalImpact: ScreenshotLocalization.text(de: "Termine verschoben", en: "Appointments postponed"),
            medications: [
                MedicationEntry(
                    name: "Metoclopramid",
                    category: .antiemetic,
                    dosage: "10 mg",
                    takenAt: calendar.date(byAdding: .minute, value: 25, to: eightDaysAgo) ?? eightDaysAgo,
                    effectiveness: .partial,
                    reliefStartedAt: calendar.date(byAdding: .minute, value: 90, to: eightDaysAgo)
                )
            ]
        )
        episodeThree.weatherSnapshot = WeatherSnapshot(snapshot: sampleWeatherSnapshot(for: eightDaysAgo), episode: episodeThree)

        let episodeFour = Episode(
            startedAt: fifteenDaysAgo,
            endedAt: calendar.date(byAdding: .hour, value: 1, to: fifteenDaysAgo),
            type: .unclear,
            intensity: 3,
            painLocation: ScreenshotLocalization.text(de: "Nacken", en: "neck"),
            painCharacter: ScreenshotLocalization.text(de: "ziehend", en: "pulling"),
            notes: ScreenshotLocalization.text(de: "Beobachtet und ohne Medikament dokumentiert.", en: "Observed and documented without medication."),
            symptoms: ScreenshotLocalization.list(de: ["Kiefer-/Aufbissschmerz"], en: ["Jaw/bite pain"]),
            triggers: ScreenshotLocalization.list(de: ["Bildschirmzeit"], en: ["Screen time"]),
            functionalImpact: ScreenshotLocalization.text(de: "Späterer Feierabend", en: "Later finish to the workday"),
            medications: []
        )
        episodeFour.weatherSnapshot = WeatherSnapshot(snapshot: sampleWeatherSnapshot(for: fifteenDaysAgo), episode: episodeFour)

        return [episodeOne, episodeTwo, episodeThree, episodeFour]
    }

    private static func sampleMedicationDefinitions() -> [MedicationDefinition] {
        [
            MedicationDefinition(
                catalogKey: "screenshot:acute",
                groupID: "screenshot-medications",
                groupTitle: ScreenshotLocalization.text(de: "Beispielmedikamente", en: "Sample Medications"),
                groupFooter: ScreenshotLocalization.text(
                    de: "Diese anonymisierten Medikamentnamen dienen ausschließlich der Screenshot-Erstellung.",
                    en: "These anonymized medication names are only used to create screenshots."
                ),
                name: "Paracetamol",
                category: .paracetamol,
                suggestedDosage: "500 mg",
                sortOrder: 0,
                isCustom: false
            ),
            MedicationDefinition(
                catalogKey: "screenshot:support",
                groupID: "screenshot-medications",
                groupTitle: ScreenshotLocalization.text(de: "Beispielmedikamente", en: "Sample Medications"),
                groupFooter: ScreenshotLocalization.text(
                    de: "Diese anonymisierten Medikamentnamen dienen ausschließlich der Screenshot-Erstellung.",
                    en: "These anonymized medication names are only used to create screenshots."
                ),
                name: "Ibuprofen",
                category: .nsar,
                suggestedDosage: "400 mg",
                sortOrder: 1,
                isCustom: false
            ),
            MedicationDefinition(
                catalogKey: "screenshot:reserve",
                groupID: "screenshot-medications",
                groupTitle: ScreenshotLocalization.text(de: "Beispielmedikamente", en: "Sample Medications"),
                groupFooter: ScreenshotLocalization.text(
                    de: "Diese anonymisierten Medikamentnamen dienen ausschließlich der Screenshot-Erstellung.",
                    en: "These anonymized medication names are only used to create screenshots."
                ),
                name: "Metoclopramid",
                category: .antiemetic,
                suggestedDosage: "10 mg",
                sortOrder: 2,
                isCustom: false
            )
        ]
    }

    private static func sampleDoctorDirectoryEntries() -> [DoctorDirectoryEntry] {
        [
            DoctorDirectoryEntry(
                id: "screenshot-doctor-anna",
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
                id: "screenshot-doctor-lea",
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
                id: "screenshot-doctor-noah",
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

    private static func isTruthy(_ value: String) -> Bool {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "y", "on":
            true
        default:
            false
        }
    }
}
