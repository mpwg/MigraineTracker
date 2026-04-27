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
            .medication: ("Medikation", "Hast du etwas genommen?", "pills.fill", .sageTeal),
            .triggers: ("Auslöser", "Was könnte eine Rolle gespielt haben?", "brain.head.profile", .blue),
            .note: ("Notiz", "Was möchtest du festhalten?", "note.text", .warmAmber),
            .review: ("Eintrag prüfen", "Alles bereit zum Speichern.", "checkmark.seal.fill", .purple)
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

    @Test
    func symiColorTokensMatchInputFlowBasisColors() {
        #expect(SymiColors.primaryPetrol.hexString == "#0F3D3E")
        #expect(SymiColors.sage.hexString == "#8ECDB8")
        #expect(SymiColors.coral.hexString == "#FF8A7A")
        #expect(SymiColors.warmBackground.hexString == "#F6F4EF")
        #expect(SymiColors.card.hexString == "#FFFFFF")
        #expect(SymiColors.textPrimary.hexString == "#1C1C1E")
        #expect(SymiColors.textSecondary.hexString == "#6B6B6E")
    }

    @Test
    func stepThemesMapFlowStepsToExpectedAccentTokens() {
        let expected: [NewEntryStepID: InputFlowStepTheme] = [
            .headache: .pain,
            .medication: .medication,
            .triggers: .trigger,
            .note: .note,
            .review: .review
        ]

        for step in NewEntryStepCatalog.steps {
            #expect(step.theme == expected[step.id, default: .pain])
        }
    }

    @Test
    func stepAccentTokensUseDesignSystemColors() {
        let expected: [NewEntryStepColorToken: String] = [
            .coral: "#FF8A7A",
            .sageTeal: "#8ECDB8",
            .blue: "#4A78D9",
            .warmAmber: "#D18A2B",
            .purple: "#8A65D6"
        ]

        for token in NewEntryStepColorToken.allCases {
            #expect(token.lightColorValue.hexString == expected[token, default: ""])
        }
    }
}
