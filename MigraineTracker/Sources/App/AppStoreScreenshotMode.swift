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
                specialty: "Neurologie",
                street: "Lindenhofgasse 12",
                city: "Wien",
                state: "Wien",
                postalCode: "1010",
                phone: "01 2345678",
                email: "ordination.clara.heiden@example.com",
                notes: "Beispielkontakt für App-Store-Screenshots.",
                sourceRaw: DoctorSource.manual.rawValue
            )

            let doctorTwo = Doctor(
                name: "Dr. Mira Sonnberg",
                specialty: "Allgemeinmedizin",
                street: "Auenweg 5",
                city: "Wien",
                state: "Wien",
                postalCode: "1070",
                phone: "01 8765432",
                email: "ordination.mira.sonnberg@example.com",
                notes: "Anonymisierte Demo-Daten.",
                sourceRaw: DoctorSource.manual.rawValue
            )

            let appointment = DoctorAppointment(
                scheduledAt: calendar.date(bySettingHour: 9, minute: 15, second: 0, of: today.addingTimeInterval(2 * 24 * 60 * 60)) ?? today,
                endsAt: calendar.date(bySettingHour: 9, minute: 45, second: 0, of: today.addingTimeInterval(2 * 24 * 60 * 60)),
                practiceName: "Ordination Dr. Clara Heiden",
                addressText: "Lindenhofgasse 12, 1010 Wien",
                note: "Verlaufsgespräch und Anpassung des Akutplans.",
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
            painLocation: "rechte Schläfe",
            painCharacter: "pochend",
            notes: "Beispieldaten für den App Store. Nach einer ruhigen Pause wurde es besser.",
            functionalImpact: "Arbeit in ruhiger Umgebung fortgesetzt",
            menstruationStatus: .unknown,
            selectedSymptoms: ["Übelkeit", "Lichtempfindlichkeit"],
            selectedTriggers: ["Stress", "Bildschirmzeit"],
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
            condition: "Leicht bewölkt",
            temperature: 17.8,
            humidity: 62,
            pressure: 1016,
            precipitation: 0.0,
            weatherCode: 2,
            source: "Beispielwetter"
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
            painLocation: "rechte Schläfe",
            painCharacter: "pochend",
            notes: "Beispieldaten für App-Store-Screenshots.",
            symptoms: ["Übelkeit", "Lichtempfindlichkeit"],
            triggers: ["Stress", "Bildschirmzeit"],
            functionalImpact: "Ruhiger Vormittag mit Pausen",
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
            painLocation: "Stirn",
            painCharacter: "dumpf",
            notes: "Nach Wasser und kurzer Pause abgeklungen.",
            symptoms: ["Geräuschempfindlichkeit"],
            triggers: ["Schlafmangel"],
            functionalImpact: "Kurze Pause am Nachmittag",
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
            painLocation: "links frontal",
            painCharacter: "pulsierend",
            notes: "Rückzug in einen abgedunkelten Raum.",
            symptoms: ["Aura", "Lichtempfindlichkeit", "Übelkeit"],
            triggers: ["Stress"],
            functionalImpact: "Termine verschoben",
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
            painLocation: "Nacken",
            painCharacter: "ziehend",
            notes: "Beobachtet und ohne Medikament dokumentiert.",
            symptoms: ["Kiefer-/Aufbissschmerz"],
            triggers: ["Bildschirmzeit"],
            functionalImpact: "Späterer Feierabend",
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
                groupTitle: "Beispielmedikamente",
                groupFooter: "Diese anonymisierten Medikamentnamen dienen ausschließlich der Screenshot-Erstellung.",
                name: "Paracetamol",
                category: .paracetamol,
                suggestedDosage: "500 mg",
                sortOrder: 0,
                isCustom: false
            ),
            MedicationDefinition(
                catalogKey: "screenshot:support",
                groupID: "screenshot-medications",
                groupTitle: "Beispielmedikamente",
                groupFooter: "Diese anonymisierten Medikamentnamen dienen ausschließlich der Screenshot-Erstellung.",
                name: "Ibuprofen",
                category: .nsar,
                suggestedDosage: "400 mg",
                sortOrder: 1,
                isCustom: false
            ),
            MedicationDefinition(
                catalogKey: "screenshot:reserve",
                groupID: "screenshot-medications",
                groupTitle: "Beispielmedikamente",
                groupFooter: "Diese anonymisierten Medikamentnamen dienen ausschließlich der Screenshot-Erstellung.",
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
                specialty: "Neurologie",
                street: "Lindenhofgasse 12",
                city: "Wien",
                state: "Wien",
                postalCode: "1010",
                sourceLabel: "Musterverzeichnis für App-Store-Screenshots",
                sourceURL: "https://example.com/app-store-screenshots"
            ),
            DoctorDirectoryEntry(
                id: "screenshot-doctor-lea",
                name: "Dr. Mira Sonnberg",
                specialty: "Allgemeinmedizin",
                street: "Auenweg 5",
                city: "Wien",
                state: "Wien",
                postalCode: "1070",
                sourceLabel: "Musterverzeichnis für App-Store-Screenshots",
                sourceURL: "https://example.com/app-store-screenshots"
            ),
            DoctorDirectoryEntry(
                id: "screenshot-doctor-noah",
                name: "Dr. Jonas Erlach",
                specialty: "Schmerzambulanz",
                street: "Parkring 8",
                city: "Graz",
                state: "Steiermark",
                postalCode: "8010",
                sourceLabel: "Musterverzeichnis für App-Store-Screenshots",
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
