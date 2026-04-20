import Foundation
import SwiftData

struct DoctorDirectoryCatalogPayload: Decodable {
    struct Metadata: Decodable {
        let title: String
        let sourceURL: String
        let sourcePDF: String
        let entryCount: Int
    }

    let metadata: Metadata
    let entries: [DoctorDirectorySeedEntry]
}

struct DoctorDirectorySeedEntry: Identifiable, Codable {
    let id: String
    let name: String
    let specialty: String
    let street: String
    let city: String
    let state: String
    let postalCode: String?
    let sourceLabel: String
    let sourceURL: String
}

enum DoctorDirectoryCatalog {
    private static let resourceName = "oegk-doctor-directory.at"
    private static let resourceExtension = "json"

    static func importSeedDataIfNeeded(into container: ModelContainer) {
        let context = ModelContext(container)
        let payload = loadCatalogPayload()
        let existingEntries = (try? context.fetch(FetchDescriptor<DoctorDirectoryEntry>())) ?? []
        let existingByID = Dictionary(uniqueKeysWithValues: existingEntries.map { ($0.id, $0) })

        for seed in payload.entries {
            if let existing = existingByID[seed.id] {
                existing.name = seed.name
                existing.specialty = seed.specialty
                existing.street = seed.street
                existing.city = seed.city
                existing.state = seed.state
                existing.postalCode = seed.postalCode
                existing.sourceLabel = seed.sourceLabel
                existing.sourceURL = seed.sourceURL
            } else {
                context.insert(
                    DoctorDirectoryEntry(
                        id: seed.id,
                        name: seed.name,
                        specialty: seed.specialty,
                        street: seed.street,
                        city: seed.city,
                        state: seed.state,
                        postalCode: seed.postalCode,
                        sourceLabel: seed.sourceLabel,
                        sourceURL: seed.sourceURL
                    )
                )
            }
        }

        do {
            try context.save()
        } catch {
            assertionFailure("Doctor directory konnte nicht in SwiftData importiert werden: \(error)")
        }
    }

    private static func loadCatalogPayload(bundle: Bundle = .main) -> DoctorDirectoryCatalogPayload {
        let bundles = [bundle, Bundle(for: DoctorDirectoryBundleLocator.self)]
        let url = bundles.lazy.compactMap { candidate in
            candidate.url(
                forResource: resourceName,
                withExtension: resourceExtension
            ) ?? candidate.url(
                forResource: resourceName,
                withExtension: resourceExtension,
                subdirectory: "Data"
            )
        }.first ?? sourceTreeFallbackURL()

        guard let url else {
            assertionFailure("Doctor directory JSON fehlt im App-Bundle.")
            return .init(
                metadata: .init(title: "", sourceURL: "", sourcePDF: "", entryCount: 0),
                entries: []
            )
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(DoctorDirectoryCatalogPayload.self, from: data)
        } catch {
            assertionFailure("Doctor directory JSON konnte nicht geladen werden: \(error)")
            return .init(
                metadata: .init(title: "", sourceURL: "", sourcePDF: "", entryCount: 0),
                entries: []
            )
        }
    }

    private static func sourceTreeFallbackURL() -> URL? {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources")
            .appendingPathComponent("Data")
            .appendingPathComponent("\(resourceName).\(resourceExtension)")
    }
}

private final class DoctorDirectoryBundleLocator {}
