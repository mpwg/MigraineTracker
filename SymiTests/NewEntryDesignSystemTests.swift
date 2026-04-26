import Testing
@testable import Symi

@MainActor
struct NewEntryDesignSystemTests {
    @Test
    func stepCatalogContainsStableFiveStepFlow() {
        #expect(NewEntryStepCatalog.steps.map(\.id) == [
            .headache,
            .medication,
            .triggers,
            .note,
            .review
        ])
    }

    @Test
    func stepCatalogDefinesGermanCopySymbolsAndColorTokens() {
        let expected: [NewEntryStepID: (String, String, String, NewEntryStepColorToken)] = [
            .headache: ("Kopfschmerz", "Wie stark ist es gerade?", "waveform.path.ecg", .coral),
            .medication: ("Medikation", "Was hast du genommen?", "pills.fill", .sageTeal),
            .triggers: ("Auslöser", "Was könnte eine Rolle gespielt haben?", "brain.head.profile", .blue),
            .note: ("Notiz", "Was fällt dir auf?", "note.text", .warmAmber),
            .review: ("Eintrag prüfen", "Kurz ansehen und speichern.", "checkmark.seal.fill", .purple)
        ]

        for step in NewEntryStepCatalog.steps {
            let expectation = expected[step.id]
            #expect(step.title == expectation?.0)
            #expect(step.subline == expectation?.1)
            #expect(step.symbolName == expectation?.2)
            #expect(step.colorToken == expectation?.3)
        }
    }

    @Test
    func everyStepHasUniqueSymbolAndColorToken() {
        let symbols = Set(NewEntryStepCatalog.steps.map(\.symbolName))
        let colorTokens = Set(NewEntryStepCatalog.steps.map(\.colorToken))

        #expect(symbols.count == NewEntryStepCatalog.steps.count)
        #expect(colorTokens.count == NewEntryStepCatalog.steps.count)
    }
}
