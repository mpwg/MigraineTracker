import XCTest

@MainActor
final class MigraineTrackerScreenshotTests: XCTestCase {
    private struct Screen {
        let route: String
        let germanSnapshotName: String
        let englishSnapshotName: String

        func snapshotName(for language: String) -> String {
            language.localizedCaseInsensitiveContains("de") ? germanSnapshotName : englishSnapshotName
        }
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureMainStoreScreens() throws {
        let screens: [Screen] = [
            .init(route: "home", germanSnapshotName: "01-startseite", englishSnapshotName: "01-home"),
            .init(route: "new-entry", germanSnapshotName: "02-neuer-eintrag", englishSnapshotName: "02-new-entry"),
            .init(route: "history", germanSnapshotName: "03-tagebuch", englishSnapshotName: "03-diary"),
            .init(route: "episode-detail", germanSnapshotName: "04-eintragsdetail", englishSnapshotName: "04-entry-detail"),
            .init(route: "export", germanSnapshotName: "05-export", englishSnapshotName: "05-export"),
            .init(route: "doctors", germanSnapshotName: "06-aerzteliste", englishSnapshotName: "06-doctors"),
            .init(route: "doctor-detail", germanSnapshotName: "07-arztdetail", englishSnapshotName: "07-doctor-detail"),
            .init(route: "doctor-add", germanSnapshotName: "08-arzt-hinzufuegen", englishSnapshotName: "08-add-doctor"),
            .init(route: "appointment-flow", germanSnapshotName: "09-termin-flow", englishSnapshotName: "09-appointment-flow"),
            .init(route: "privacy-info", germanSnapshotName: "10-datenschutz", englishSnapshotName: "10-privacy")
        ]

        for screen in screens {
            let app = XCUIApplication()
            setupSnapshot(app, waitForAnimations: false)
            app.launchArguments += [
                "-mt_screenshot_screen",
                screen.route,
                "-mt_screenshot_seed",
                "default"
            ]
            app.launch()
            waitForStableLayout()
            snapshot(screen.snapshotName(for: Snapshot.deviceLanguage), waitForLoadingIndicator: false)
            app.terminate()
        }
        assert(true)
    }

    private func waitForStableLayout() {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.2))
    }
}
