import Testing
@testable import Symi

@MainActor
struct EpisodeOptionCatalogTests {
    @Test
    func painLocationMetadataDefinesEntryFlowOptions() {
        let visibleLocations = PainLocationOption.entryFlowCases

        #expect(visibleLocations.map(\.displayLabel) == ["Stirn", "Schläfen", "Einseitig", "Überall"])
        #expect(PainLocationOption.allCases.map(\.displayLabel) == ["Stirn", "Schläfen", "Nacken", "Einseitig", "Überall"])
        #expect(PainLocationOption.forehead.metadata.imageName == "PainLocationForehead")
        #expect(PainLocationOption.temples.metadata.imageName == "PainLocationTemples")
        #expect(PainLocationOption.neck.metadata.imageName == "PainLocationNeck")
        #expect(!PainLocationOption.neck.metadata.isVisibleInEntryFlow)
    }

    @Test
    func painLocationParsesStorageAndLegacyValues() {
        let expectations: [(String, PainLocationOption)] = [
            ("forehead", .forehead),
            ("Stirn", .forehead),
            ("Schläfen", .temples),
            ("Nacken", .neck),
            ("Einseitig", .oneSided),
            ("links frontal", .oneSided),
            ("Überall", .everywhere),
            ("Oberkopf", .everywhere)
        ]

        for expectation in expectations {
            #expect(PainLocationOption(storageValue: expectation.0) == expectation.1)
        }
    }

    @Test
    func symptomAndTriggerCatalogsProvideStableDisplayValues() {
        #expect(EpisodeSymptomOption.allCases.map(\.displayLabel) == [
            "Übelkeit",
            "Lichtempfindlichkeit",
            "Geräuschempfindlichkeit",
            "Aura",
            "Kiefer-/Aufbissschmerz",
            "Pochen, Pulsieren"
        ])
        #expect(EpisodeTriggerOption.allCases.map(\.displayLabel) == [
            "Wetter",
            "Stress",
            "Erhöhte Arbeitsbelastung",
            "Regel",
            "Schlafdauer",
            "Sport",
            "Ernährung",
            "Bildschirmzeit",
            "Bewegung",
            "Flüssigkeit"
        ])
        #expect(EpisodeTriggerOption.entryFlowCases.map(\.displayLabel) == [
            "Stress",
            "Wetter",
            "Schlafdauer",
            "Ernährung",
            "Bildschirmzeit",
            "Regel",
            "Bewegung",
            "Flüssigkeit"
        ])
        #expect(EpisodeTriggerOption.sleepDuration.symbolName == "moon")
        #expect(EpisodeTriggerOption.period.symbolName == "drop")
        #expect(EpisodeTriggerOption(storageValue: "Schlaf") == .sleepDuration)
        #expect(EpisodeTriggerOption(storageValue: "Zyklus") == .period)
    }
}
