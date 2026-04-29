import XCTest

@MainActor
final class SymiScreenshotTests: XCTestCase {
    private enum ScreenshotSelection {
        static let environmentKey = "SYMI_SCREENSHOT_PAGES"

        static let storeScreens: [Screen] = [
            .init(route: "home", germanSnapshotName: "01-mehr-gute-tage", englishSnapshotName: "01-more-good-days"),
            .init(route: "new-entry", germanSnapshotName: "02-in-sekunden-eintragen", englishSnapshotName: "02-log-in-seconds"),
            .init(route: "insights", germanSnapshotName: "03-erkenne-deine-muster", englishSnapshotName: "03-recognize-patterns"),
            .init(route: "history", germanSnapshotName: "04-alles-im-blick", englishSnapshotName: "04-everything-in-view"),
            .init(route: "privacy-info", germanSnapshotName: "05-deine-daten-gehoeren-dir", englishSnapshotName: "05-your-data-belongs-to-you")
        ]

        static let allScreens: [Screen] = storeScreens + [
            .init(route: "episode-detail", germanSnapshotName: "06-episode-im-detail", englishSnapshotName: "06-episode-details"),
            .init(route: "export", germanSnapshotName: "07-bericht-exportieren", englishSnapshotName: "07-export-report")
        ]

        static func screens(from environment: [String: String] = ProcessInfo.processInfo.environment) throws -> [Screen] {
            let rawSelection = environment[environmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let rawSelection, !rawSelection.isEmpty else {
                return storeScreens
            }

            switch rawSelection.lowercased() {
            case "store", "main", "default":
                return storeScreens
            case "all", "alle":
                return allScreens
            default:
                return try screens(matching: rawSelection)
            }
        }

        private static func screens(matching rawSelection: String) throws -> [Screen] {
            let requestedIdentifiers = rawSelection
                .split { character in
                    character == "," || character == ";" || character.isWhitespace
                }
                .map { String($0).lowercased() }
            guard !requestedIdentifiers.isEmpty else {
                return storeScreens
            }

            let screensByIdentifier = allScreens.reduce(into: [String: Screen]()) { result, screen in
                screen.identifiers.forEach { identifier in
                    result[identifier] = screen
                }
            }

            let selectedScreens = requestedIdentifiers.compactMap { screensByIdentifier[$0] }
            let missingIdentifiers = requestedIdentifiers.filter { screensByIdentifier[$0] == nil }

            if !missingIdentifiers.isEmpty {
                throw NSError(
                    domain: "SymiScreenshotTests",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Unbekannte Screenshot-Seiten: \(missingIdentifiers.joined(separator: ", ")). Erlaubt sind store, all oder: \(allScreens.map(\.route).joined(separator: ", "))."
                    ]
                )
            }

            return selectedScreens
        }
    }

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

        var identifiers: [String] {
            [
                route,
                germanSnapshotName,
                englishSnapshotName,
                germanSnapshotName.replacingOccurrences(of: #"^\d+-"#, with: "", options: .regularExpression),
                englishSnapshotName.replacingOccurrences(of: #"^\d+-"#, with: "", options: .regularExpression)
            ].map { $0.lowercased() }
        }
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureMainStoreScreens() throws {
        let screens = try ScreenshotSelection.screens()

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
        XCTAssertTrue(app.descendants(matching: .any)["entry-flow-subtitle-headache"].exists)
        XCTAssertTrue(app.buttons["entry-flow-save-headache-only"].exists)
    }

    private func waitForStableLayout() {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.2))
    }
}
