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
            .init(
                route: "home",
                germanSnapshotName: "01a-home-dunkel-grosse-schrift",
                englishSnapshotName: "01a-home-dark-large-type",
                extraArguments: [
                    "-AppleInterfaceStyle", "Dark",
                    "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"
                ]
            ),
            .init(route: "new-entry", germanSnapshotName: "02-in-sekunden-eintragen", englishSnapshotName: "02-log-in-seconds"),
            .init(route: "history", germanSnapshotName: "03-erkenne-deine-muster", englishSnapshotName: "03-recognize-patterns"),
            .init(route: "episode-detail", germanSnapshotName: "04-alles-im-blick", englishSnapshotName: "04-everything-in-view"),
            .init(route: "privacy-info", germanSnapshotName: "05-deine-daten-gehoeren-dir", englishSnapshotName: "05-your-data-belongs-to-you"),
            .init(route: "export", germanSnapshotName: "06-export", englishSnapshotName: "06-export")
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

    private func waitForStableLayout() {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.2))
    }
}
