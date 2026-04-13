//
//  MigraineTrackerUITestsLaunchTests.swift
//  MigraineTrackerUITests
//
//  Created by Matthias Wallner-Géhri on 11.04.26.
//

import XCTest

final class MigraineTrackerUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
        app.activate()
        snapshot("0Launch")
        app/*@START_MENU_TOKEN@*/.buttons["Migräneanfall hinzufügen"]/*[[".buttons",".containing(.staticText, identifier: \"Migräneanfall hinzufügen\")",".containing(.image, identifier: \"plus.circle.fill\")",".groups.buttons[\"Migräneanfall hinzufügen\"]",".buttons[\"Migräneanfall hinzufügen\"]"],[[[-1,4],[-1,3],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.firstMatch.click()
        snapshot("1AddMigräne")
        app.buttons["Abbrechen"].firstMatch.click()

        app/*@START_MENU_TOKEN@*/.buttons["Einstellungen"]/*[[".groups[\"Einstellungen\"].buttons",".groups.buttons[\"Einstellungen\"]",".buttons[\"Einstellungen\"]"],[[[-1,2],[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.firstMatch.click()
        snapshot("2Settings")
        app.terminate()

    }
}
