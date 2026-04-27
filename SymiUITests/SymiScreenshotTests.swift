import XCTest

@MainActor
final class SymiScreenshotTests: XCTestCase {
    private struct Screen {
        let route: String
        let germanSnapshotName: String
        let englishSnapshotName: String
        let extraArguments: [String]

        init(
            route: String,
            germanSnapshotName: String,
            englishSnapshotName: String,
            extraArguments: [String] = []
        ) {
            self.route = route
            self.germanSnapshotName = germanSnapshotName
            self.englishSnapshotName = englishSnapshotName
            self.extraArguments = extraArguments
        }

        func snapshotName(for language: String) -> String {
            language.localizedCaseInsensitiveContains("de") ? germanSnapshotName : englishSnapshotName
        }
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureMainStoreScreens() throws {
        let screens: [Screen] = [
            .init(route: "home", germanSnapshotName: "01-mehr-gute-tage", englishSnapshotName: "01-more-good-days"),
            .init(route: "new-entry", germanSnapshotName: "02-in-sekunden-eintragen", englishSnapshotName: "02-log-in-seconds"),
            .init(route: "insights", germanSnapshotName: "03-erkenne-deine-muster", englishSnapshotName: "03-recognize-patterns"),
            .init(route: "history", germanSnapshotName: "04-alles-im-blick", englishSnapshotName: "04-everything-in-view"),
            .init(route: "privacy-info", germanSnapshotName: "05-deine-daten-gehoeren-dir", englishSnapshotName: "05-your-data-belongs-to-you")
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
            app.launchArguments += screen.extraArguments
            app.launch()
            waitForStableLayout()
            snapshot(screen.snapshotName(for: Snapshot.deviceLanguage), waitForLoadingIndicator: false)
            app.terminate()
        }
        assert(true)
    }

    func testDefaultSeedShowsScaleFirstNewEntryFlow() throws {
        let app = XCUIApplication()
        setupSnapshot(app, waitForAnimations: false)
        app.launchArguments += [
            "-mt_screenshot_screen",
            "new-entry",
            "-mt_screenshot_seed",
            "default",
            "-mt_disable_weather"
        ]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["entry-flow-step-headache"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.descendants(matching: .any)["entry-intensity-card"].exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Wie stark ist es gerade?")).firstMatch.exists)
        XCTAssertTrue(app.buttons["entry-flow-save-headache-only"].exists)
    }

    private func waitForStableLayout() {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.2))
    }
}
