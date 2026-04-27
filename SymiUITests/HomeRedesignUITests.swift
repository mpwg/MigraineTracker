import XCTest

@MainActor
final class HomeRedesignUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testHomeSupportsDarkModeLargeTypeAndCoreAccessibilityLabels() {
        let app = launchHome(
            extraArguments: [
                "-AppleInterfaceStyle", "Dark",
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL",
            ]
        )

        let calendar = app.descendants(matching: .any)["home-calendar"]
        XCTAssertTrue(calendar.waitForExistence(timeout: 6))
        XCTAssertTrue(accessibilityElement(containing: "Monatskalender", in: app).exists)
        XCTAssertTrue(accessibilityElement(containing: "heute", in: app).exists)
        XCTAssertFalse(accessibilityElement(containing: "ausgewählt", in: app).exists)
        XCTAssertMinimumTouchTarget(app.buttons["home-calendar-previous-month"])
        XCTAssertMinimumTouchTarget(app.buttons["home-calendar-next-month"])

        let quickEntry = app.descendants(matching: .any)["home-quick-entry"]
        scrollUntilVisible(quickEntry, in: app)
        XCTAssertTrue(quickEntry.exists)
        XCTAssertMinimumTouchTarget(quickEntry)
        XCTAssertTrue(accessibilityElement(containing: "Eintrag erstellen", in: app).exists)
        XCTAssertFalse(app.sliders["home-feeling-slider"].exists)

        scrollUntilVisible(app.descendants(matching: .any)["home-patterns-section"], in: app)
        XCTAssertTrue(app.descendants(matching: .any)["home-patterns-section"].exists)

        attachScreenshot(named: "home-redesign-dark-large-type", app: app)
    }

    private func launchHome(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui_testing",
            "-mt_screenshot_screen",
            "home",
            "-mt_screenshot_seed",
            "default",
        ]
        app.launchArguments += extraArguments
        app.launch()
        return app
    }

    private func accessibilityElement(containing text: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .containing(NSPredicate(format: "label CONTAINS %@", text))
            .firstMatch
    }

    private func accessibilityElement(valueContaining text: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .containing(NSPredicate(format: "value CONTAINS %@", text))
            .firstMatch
    }

    private func scrollUntilVisible(_ element: XCUIElement, in app: XCUIApplication) {
        let scrollView = app.scrollViews.firstMatch

        for _ in 0 ..< 5 where !element.isHittable {
            scrollView.swipeUp()
        }
    }

    private func XCTAssertMinimumTouchTarget(
        _ element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.exists, file: file, line: line)
        XCTAssertGreaterThanOrEqual(element.frame.width, 44, file: file, line: line)
        XCTAssertGreaterThanOrEqual(element.frame.height, 44, file: file, line: line)
    }

    private func attachScreenshot(named name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
