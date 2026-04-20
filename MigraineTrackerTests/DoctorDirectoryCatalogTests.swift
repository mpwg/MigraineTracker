import Foundation
import SwiftData
import Testing
@testable import MigraineTracker

@MainActor
struct DoctorDirectoryCatalogTests {
    @Test
    func importedEntriesContainStateAndAddressData() throws {
        let payload = try loadPayload()
        let entries = payload.entries

        #expect(entries.count > 2000)
        #expect(entries.contains(where: { $0.state == "Wien" }))
        #expect(entries.contains(where: { !$0.specialty.isEmpty && !$0.street.isEmpty }))
    }

    @Test
    func importSeedDataIsIdempotent() throws {
        let payload = try loadPayload()
        let uniqueIDs = Set(payload.entries.map(\.id))

        #expect(payload.entries.count > 2000)
        #expect(payload.entries.count == uniqueIDs.count)
    }

    private func loadPayload() throws -> DoctorDirectoryCatalogPayload {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("MigraineTracker")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Data")
            .appendingPathComponent("oegk-doctor-directory.at.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(DoctorDirectoryCatalogPayload.self, from: data)
    }
}
