import Testing
@testable import MigraineTrackerCore

struct ExportSummaryMetricsTests {
    @Test
    func averageIntensityReturnsZeroForEmptyInput() {
        #expect(ExportSummaryMetrics.averageIntensity(for: []) == 0)
    }

    @Test
    func averageIntensityCalculatesMeanValue() {
        #expect(ExportSummaryMetrics.averageIntensity(for: [4, 6, 8]) == 6)
    }

    @Test
    func uniqueMedicationNamesDeduplicatesAndSorts() {
        let names = ExportSummaryMetrics.uniqueMedicationNames(
            from: [
                ["Ibuprofen", "Sumatriptan"],
                ["Sumatriptan", "Paracetamol"],
                [""]
            ]
        )

        #expect(names == ["Ibuprofen", "Paracetamol", "Sumatriptan"])
    }
}
