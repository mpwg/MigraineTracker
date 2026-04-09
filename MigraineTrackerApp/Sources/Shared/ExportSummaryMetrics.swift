import Foundation

enum ExportSummaryMetrics {
    static func averageIntensity(for intensities: [Int]) -> Double {
        guard !intensities.isEmpty else {
            return 0
        }

        return Double(intensities.reduce(0, +)) / Double(intensities.count)
    }

    static func uniqueMedicationNames(from medicationNames: [[String]]) -> [String] {
        Array(Set(medicationNames.flatMap { $0 }))
            .filter { !$0.isEmpty }
            .sorted()
    }
}
