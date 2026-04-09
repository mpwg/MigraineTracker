import Foundation

struct MedicationCatalogEntry: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let category: MedicationCategory
    let suggestedDosage: String
    let note: String
}

struct MedicationCatalogGroup: Identifiable, Codable {
    let id: String
    let title: String
    let footer: String?
    let entries: [MedicationCatalogEntry]
}

enum MedicationCatalog {
    private static let resourceName = "medication-catalog.at"
    private static let resourceExtension = "json5"

    static let austrianCommonGroups: [MedicationCatalogGroup] = loadAustrianCommonGroups()

    private static func loadAustrianCommonGroups(bundle: Bundle = .main) -> [MedicationCatalogGroup] {
        let url = bundle.url(
            forResource: resourceName,
            withExtension: resourceExtension
        ) ?? bundle.url(
            forResource: resourceName,
            withExtension: resourceExtension,
            subdirectory: "Data"
        )

        guard let url else {
            assertionFailure("Medication catalog JSON fehlt im App-Bundle.")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.allowsJSON5 = true
            return try decoder.decode([MedicationCatalogGroup].self, from: data)
        } catch {
            assertionFailure("Medication catalog JSON konnte nicht geladen werden: \(error)")
            return []
        }
    }
}
