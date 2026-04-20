import Foundation
import SwiftData

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

    static func importSeedDataIfNeeded(into container: ModelContainer) {
        let context = ModelContext(container)
        let groups = loadAustrianCommonGroups()
        let existingDefinitions = (try? context.fetch(FetchDescriptor<MedicationDefinition>())) ?? []
        let definitionsByKey = Dictionary(uniqueKeysWithValues: existingDefinitions.map { ($0.catalogKey, $0) })

        var sortOrder = 0

        for group in groups {
            for entry in group.entries {
                let catalogKey = "seed:\(group.id):\(entry.id)"

                if let definition = definitionsByKey[catalogKey] {
                    definition.groupID = group.id
                    definition.groupTitle = group.title
                    definition.groupFooter = group.footer
                    definition.name = entry.name
                    definition.category = entry.category
                    definition.suggestedDosage = entry.suggestedDosage
                    definition.sortOrder = sortOrder
                    definition.isCustom = false
                } else {
                    let definition = MedicationDefinition(
                        catalogKey: catalogKey,
                        groupID: group.id,
                        groupTitle: group.title,
                        groupFooter: group.footer,
                        name: entry.name,
                        category: entry.category,
                        suggestedDosage: entry.suggestedDosage,
                        sortOrder: sortOrder,
                        isCustom: false
                    )
                    context.insert(definition)
                }

                sortOrder += 1
            }
        }

        do {
            try context.save()
        } catch {
            assertionFailure("Medication catalog konnte nicht in SwiftData importiert werden: \(error)")
        }
    }

    private static func loadAustrianCommonGroups(bundle: Bundle = .main) -> [MedicationCatalogGroup] {
        let bundles = [bundle, Bundle(for: ResourceBundleLocator.self)]
        let url = bundles.lazy.compactMap { candidate in
            candidate.url(
                forResource: resourceName,
                withExtension: resourceExtension
            ) ?? candidate.url(
                forResource: resourceName,
                withExtension: resourceExtension,
                subdirectory: "Data"
            )
        }.first

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

private final class ResourceBundleLocator {}
