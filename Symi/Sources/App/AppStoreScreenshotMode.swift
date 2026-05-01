import Foundation
import SwiftData

#if DEBUG
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
            let existingDefinitions = try context.fetch(FetchDescriptor<MedicationDefinition>())

            for episode in existingEpisodes {
                context.delete(episode)
            }

            for definition in existingDefinitions {
                context.delete(definition)
            }

            let calendar = Calendar(identifier: .gregorian)
            let today = calendar.startOfDay(for: .now)
            let medications = sampleMedicationDefinitions()
            let episodes = sampleEpisodes(relativeTo: today, calendar: calendar)

            for medication in medications {
                context.insert(medication)
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
            selectedSymptoms: Set(["Übelkeit", "Lichtempfindlichkeit"]),
            selectedTriggers: Set(["Stress", "Bildschirmzeit"]),
            medications: [
                MedicationSelectionDraft(
                    selectionKey: MedicationSelectionKey.make(
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
            functionalImpact: "Tagesplanung angepasst",
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

    private static func isTruthy(_ value: String) -> Bool {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "y", "on":
            true
        default:
            false
        }
    }
}
#else
enum AppStoreScreenshotMode {
    static var isEnabled: Bool {
        false
    }

    static func resetStoreIfNeeded() throws {}

    static func seed(into container: ModelContainer) {}

    static func sampleDraft(initialStartedAt: Date?) -> EpisodeDraft {
        preconditionFailure("Screenshot mode is unavailable in Release builds.")
    }

    static func sampleWeatherSnapshot(for startedAt: Date) -> WeatherSnapshotData {
        preconditionFailure("Screenshot mode is unavailable in Release builds.")
    }
}
#endif
