import Testing
@testable import Symi

@MainActor
struct PainIntensityLevelTests {
    @Test
    func usesCentralBoundaryBuckets() {
        let expectations = [
            PainIntensityExpectation(intensity: 0, level: .none, displayLabel: "Nicht bewertet", contextText: nil, storedIntensity: 0),
            PainIntensityExpectation(intensity: 1, level: .low, displayLabel: "Leicht", contextText: "Leichter Verlauf", storedIntensity: 2),
            PainIntensityExpectation(intensity: 3, level: .low, displayLabel: "Leicht", contextText: "Leichter Verlauf", storedIntensity: 2),
            PainIntensityExpectation(intensity: 4, level: .medium, displayLabel: "Mittel", contextText: "Mittlerer Verlauf", storedIntensity: 5),
            PainIntensityExpectation(intensity: 6, level: .medium, displayLabel: "Mittel", contextText: "Mittlerer Verlauf", storedIntensity: 5),
            PainIntensityExpectation(intensity: 7, level: .high, displayLabel: "Stark", contextText: "Starker Verlauf", storedIntensity: 8),
            PainIntensityExpectation(intensity: 8, level: .high, displayLabel: "Stark", contextText: "Starker Verlauf", storedIntensity: 8),
            PainIntensityExpectation(intensity: 9, level: .veryHigh, displayLabel: "Sehr stark", contextText: "Sehr starker Verlauf", storedIntensity: 10),
            PainIntensityExpectation(intensity: 10, level: .veryHigh, displayLabel: "Sehr stark", contextText: "Sehr starker Verlauf", storedIntensity: 10),
            PainIntensityExpectation(intensity: 11, level: .none, displayLabel: "Nicht bewertet", contextText: nil, storedIntensity: 0)
        ]

        for expectation in expectations {
            let level = PainIntensityLevel(intensity: expectation.intensity)

            #expect(level == expectation.level)
            #expect(level.displayLabel == expectation.displayLabel)
            #expect(level.contextText == expectation.contextText)
            #expect(level.storedIntensity == expectation.storedIntensity)
            #expect(level.metadata.storedIntensity == expectation.storedIntensity)
            #expect(level.contains(intensity: expectation.intensity))
        }
    }

    @Test
    func parsesLegacyStorageValues() {
        let expectations: [(String, PainIntensityLevel)] = [
            ("leicht", .low),
            ("Leicht", .low),
            ("mittel", .medium),
            ("Mittel", .medium),
            ("stark", .high),
            ("Stark", .high),
            ("very_high", .veryHigh),
            ("sehrStark", .veryHigh),
            ("Sehr stark", .veryHigh),
            ("Sehr Stark", .veryHigh),
            ("unknown", .none)
        ]

        for expectation in expectations {
            #expect(PainIntensityLevel(storageValue: expectation.0) == expectation.1)
        }
    }

    @Test
    func metadataProvidesDistinctSelectableVisualValues() {
        let metadata = PainIntensityLevel.selectableCases.map(\.metadata)

        #expect(Set(metadata.map(\.colorToken)).count == PainIntensityLevel.selectableCases.count)
        #expect(Set(metadata.map(\.faceExpression)).count == PainIntensityLevel.selectableCases.count)
        #expect(PainIntensityLevel.low.metadata.colorToken == .low)
        #expect(PainIntensityLevel.medium.metadata.colorToken == .medium)
        #expect(PainIntensityLevel.high.metadata.colorToken == .high)
        #expect(PainIntensityLevel.veryHigh.metadata.colorToken == .veryHigh)
        #expect(ColorToken.Pain.token(for: .low).colorHex == 0xA7B8B2)
        #expect(ColorToken.Pain.token(for: .medium).colorHex == 0xE7C29D)
        #expect(ColorToken.Pain.token(for: .high).colorHex == 0xF19A7A)
        #expect(ColorToken.Pain.token(for: .veryHigh).colorHex == 0xE3746A)
        #expect(PainIntensityLevel.low.metadata.faceExpression == .calm)
        #expect(PainIntensityLevel.medium.metadata.faceExpression == .neutral)
        #expect(PainIntensityLevel.high.metadata.faceExpression == .strained)
        #expect(PainIntensityLevel.veryHigh.metadata.faceExpression == .intense)
    }
}

private struct PainIntensityExpectation {
    let intensity: Int
    let level: PainIntensityLevel
    let displayLabel: String
    let contextText: String?
    let storedIntensity: Int
}
