import Foundation
import Testing
@testable import MigraineTracker

struct AppSectionParityTests {
    @Test
    @MainActor
    func allCoreSectionsAreAvailableOnIOSAndMacOS() {
        let requiredSections: Set<AppSection> = [.home, .capture, .history, .syncAndExport, .settings]

        for section in requiredSections {
            #expect(section.availability.iOS)
            #expect(section.availability.macOS)
            #expect(section.availability.unavailableReason == nil)
        }
    }

    @Test
    @MainActor
    func iosTabsCoverAllSharedSections() {
        let tabs = Set(AppTab.allCases.map { $0.section })
        #expect(tabs == Set(AppSection.allCases))
    }
}
