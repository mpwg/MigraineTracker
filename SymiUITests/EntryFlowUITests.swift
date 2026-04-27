import XCTest

@MainActor
final class EntryFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCompleteFiveStepFlowSavesEntry() {
        let app = launchEntryFlow()

        XCTAssertTrue(step("headache", in: app).waitForExistence(timeout: 6))
        assertHeadacheStepMatchesReference(in: app)
        attachScreenshot(named: "entry-flow-01-headache", app: app)
        app.buttons["entry-flow-next"].tap()

        XCTAssertTrue(step("medication", in: app).waitForExistence(timeout: 3))
        assertMedicationStepMatchesReference(in: app)
        attachScreenshot(named: "entry-flow-02-medication", app: app)
        app.buttons["entry-medication-Ibuprofen"].tap()
        app.buttons["entry-flow-next"].tap()

        XCTAssertTrue(step("triggers", in: app).waitForExistence(timeout: 3))
        assertTriggersStepMatchesReference(in: app)
        attachScreenshot(named: "entry-flow-03-triggers", app: app)
        app.buttons["entry-trigger-Stress"].tap()
        app.buttons["entry-trigger-Wetter"].tap()
        app.buttons["entry-flow-next"].tap()

        XCTAssertTrue(step("note", in: app).waitForExistence(timeout: 3))
        assertNoteStepMatchesReference(in: app)
        attachScreenshot(named: "entry-flow-04-note", app: app)
        app.buttons["entry-feeling-Müde"].tap()
        app.buttons["entry-flow-next"].tap()

        XCTAssertTrue(step("review", in: app).waitForExistence(timeout: 3))
        assertReviewStepMatchesReference(in: app)
        attachScreenshot(named: "entry-flow-05-review", app: app)
        XCTAssertTrue(app.staticTexts["4/10 · Mittel"].exists)
        XCTAssertTrue(app.staticTexts["Ort: Schläfen"].exists)
        XCTAssertTrue(staticText(containing: "Ibuprofen", in: app).exists)
        XCTAssertTrue(staticText(containing: "Stress, Wetter", in: app).exists)
        XCTAssertTrue(app.staticTexts["Gefühl: Müde"].exists)

        app.buttons["entry-flow-save"].tap()
        XCTAssertTrue(app.alerts["Eintrag gespeichert"].waitForExistence(timeout: 6))
    }

    func testHeadacheOnlyDirectSaveFromFirstStep() {
        let app = launchEntryFlow()

        XCTAssertTrue(step("headache", in: app).waitForExistence(timeout: 6))
        app.buttons["entry-flow-save-headache-only"].tap()

        XCTAssertTrue(app.alerts["Eintrag gespeichert"].waitForExistence(timeout: 6))
    }

    func testOptionalStepsCanBeSkippedAndStillSavedWithoutWeather() {
        let app = launchEntryFlow(extraArguments: ["-mt_disable_weather"])

        XCTAssertTrue(step("headache", in: app).waitForExistence(timeout: 6))
        app.buttons["entry-flow-next"].tap()

        XCTAssertTrue(step("medication", in: app).waitForExistence(timeout: 3))
        app.buttons["entry-flow-skip"].tap()

        XCTAssertTrue(step("triggers", in: app).waitForExistence(timeout: 3))
        app.buttons["entry-flow-skip"].tap()

        XCTAssertTrue(step("note", in: app).waitForExistence(timeout: 3))
        app.buttons["entry-flow-skip"].tap()

        XCTAssertTrue(step("review", in: app).waitForExistence(timeout: 3))
        app.buttons["entry-flow-save"].tap()

        XCTAssertTrue(app.alerts["Eintrag gespeichert"].waitForExistence(timeout: 6))
    }

    func testBackNavigationKeepsDraftSelection() {
        let app = launchEntryFlow()

        XCTAssertTrue(step("headache", in: app).waitForExistence(timeout: 6))
        let templeButton = app.buttons["entry-location-Schläfen"]
        app.buttons["entry-flow-next"].tap()

        XCTAssertTrue(step("medication", in: app).waitForExistence(timeout: 3))
        app.buttons["entry-flow-back"].tap()

        XCTAssertTrue(step("headache", in: app).waitForExistence(timeout: 3))
        XCTAssertEqual(templeButton.value as? String, "Ausgewählt")
    }

    func testCancelInTheMiddleReturnsToFreshHeadacheStep() {
        let app = launchEntryFlow()

        XCTAssertTrue(step("headache", in: app).waitForExistence(timeout: 6))
        app.buttons["entry-flow-next"].tap()

        XCTAssertTrue(step("medication", in: app).waitForExistence(timeout: 3))
        app.buttons["entry-flow-cancel"].tap()

        XCTAssertTrue(step("headache", in: app).waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["entry-location-Schläfen"].value as? String, "Ausgewählt")
    }

    func testAccessibilitySizeDarkModeAndTouchTargets() {
        let app = launchEntryFlow(
            extraArguments: [
                "-AppleInterfaceStyle", "Dark",
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"
            ]
        )

        XCTAssertTrue(step("headache", in: app).waitForExistence(timeout: 6))
        XCTAssertMinimumTouchTarget(app.buttons["entry-flow-next"])
        XCTAssertMinimumTouchTarget(app.buttons["entry-flow-save-headache-only"])
        XCTAssertMinimumTouchTarget(app.buttons["entry-location-Schläfen"])
    }

    private func launchEntryFlow(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui_testing",
            "-mt_screenshot_screen",
            "new-entry",
            "-mt_screenshot_seed",
            "default"
        ]
        app.launchArguments += extraArguments
        app.launch()
        return app
    }

    private func step(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["entry-flow-step-\(id)"]
    }

    private func staticText(containing text: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func assertHeadacheStepMatchesReference(in app: XCUIApplication) {
        XCTAssertVisibleText("Kopfschmerz", in: app)
        XCTAssertVisibleText("Wie stark ist es gerade?", in: app)
        XCTAssertVisibleText("Mittel", in: app)
        XCTAssertVisibleText("Wo spürst du den Schmerz?", in: app)
        XCTAssertVisibleText("Wann tritt es auf?", in: app)
        XCTAssertTrue(app.buttons["entry-location-Schläfen"].exists)
        XCTAssertEqual(app.buttons["entry-location-Schläfen"].value as? String, "Ausgewählt")
        XCTAssertTrue(app.buttons["entry-started-at-now"].exists)
        XCTAssertTrue(app.buttons["entry-flow-next"].exists)
        XCTAssertTrue(app.buttons["entry-flow-save-headache-only"].exists)
        XCTAssertVisibleText("von 5", in: app)
    }

    private func assertMedicationStepMatchesReference(in app: XCUIApplication) {
        XCTAssertVisibleText("Medikation", in: app)
        XCTAssertVisibleText("Hast du etwas genommen?", in: app)
        XCTAssertVisibleText("Welche Medikation?", in: app)
        XCTAssertVisibleText("Dosierung", in: app)
        XCTAssertVisibleText("Wann hast du es eingenommen?", in: app)
        XCTAssertTrue(app.buttons["entry-medication-Ibuprofen"].exists)
        XCTAssertTrue(app.buttons["entry-medication-Triptan"].exists)
        XCTAssertTrue(app.buttons["entry-dosage-400 mg"].exists)
        XCTAssertTrue(app.buttons["entry-flow-skip"].exists)
        XCTAssertVisibleText("von 5", in: app)
    }

    private func assertTriggersStepMatchesReference(in app: XCUIApplication) {
        XCTAssertVisibleText("Auslöser", in: app)
        XCTAssertVisibleText("Was könnte eine Rolle gespielt haben?", in: app)
        XCTAssertVisibleText("Wähle alle passenden aus.", in: app)
        XCTAssertTrue(app.buttons["entry-trigger-Stress"].exists)
        XCTAssertTrue(app.buttons["entry-trigger-Wetter"].exists)
        XCTAssertTrue(app.buttons["entry-trigger-Schlaf"].exists)
        XCTAssertTrue(app.buttons["entry-trigger-Ernährung"].exists)
        XCTAssertVisibleText("Du kannst mehrere auswählen.", in: app)
        XCTAssertVisibleText("von 5", in: app)
    }

    private func assertNoteStepMatchesReference(in app: XCUIApplication) {
        XCTAssertVisibleText("Notiz", in: app)
        XCTAssertVisibleText("Was möchtest du festhalten?", in: app)
        XCTAssertVisibleText("Was hat geholfen?", in: app)
        XCTAssertVisibleText("Was war heute anders?", in: app)
        XCTAssertVisibleText("Wie fühlst du dich gerade?", in: app)
        XCTAssertTrue(app.buttons["entry-feeling-Müde"].exists)
        XCTAssertTrue(app.switches["entry-note-link-toggle"].exists)
        XCTAssertTrue(app.buttons["entry-flow-skip"].exists)
        XCTAssertVisibleText("von 5", in: app)
    }

    private func assertReviewStepMatchesReference(in app: XCUIApplication) {
        XCTAssertVisibleText("Eintrag prüfen", in: app)
        XCTAssertVisibleText("Alles bereit zum Speichern.", in: app)
        XCTAssertVisibleText("Kopfschmerz", in: app)
        XCTAssertVisibleText("Medikation", in: app)
        XCTAssertVisibleText("Auslöser", in: app)
        XCTAssertVisibleText("Notiz", in: app)
        XCTAssertVisibleText("Dein Eintrag hilft dir, Muster besser zu erkennen.", in: app)
        XCTAssertTrue(app.buttons["entry-flow-save"].exists)
        XCTAssertTrue(app.buttons["entry-flow-edit"].exists)
        XCTAssertVisibleText("von 5", in: app)
    }

    private func XCTAssertVisibleText(
        _ text: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(staticText(containing: text, in: app).exists, "Missing visible text: \(text)", file: file, line: line)
    }

    private func attachScreenshot(named name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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
}
