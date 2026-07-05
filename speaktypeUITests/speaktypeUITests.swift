import XCTest

final class speaktypeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        return app
    }

    /// Every sidebar destination opens and shows content unique to that screen.
    /// Markers are texts each screen renders unconditionally, so the assertions
    /// hold on a fresh install (no models, no history).
    func testSidebarNavigation() throws {
        let app = launchApp()

        let destinations: [(button: String, marker: String)] = [
            ("Transcribe Audio", "Drop audio or video file here"),
            ("History", "History"),
            ("Statistics", "Statistics"),
            ("AI Models", "CURRENTLY USING"),
            ("Settings", "Primary Hotkey"),
            ("Dashboard", "Recent transcriptions"),
        ]

        for (button, marker) in destinations {
            let sidebarButton = app.buttons[button]
            XCTAssertTrue(
                sidebarButton.waitForExistence(timeout: 5.0),
                "Sidebar button '\(button)' should exist"
            )
            sidebarButton.click()

            XCTAssertTrue(
                app.staticTexts[marker].waitForExistence(timeout: 5.0),
                "'\(button)' screen should show '\(marker)'"
            )
        }
    }

    /// The Settings screen's tab bar switches between General, Audio, and
    /// Permissions content.
    func testSettingsTabs() throws {
        let app = launchApp()

        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5.0))
        settingsButton.click()

        XCTAssertTrue(
            app.staticTexts["Primary Hotkey"].waitForExistence(timeout: 5.0),
            "General tab should be selected by default"
        )

        app.buttons["Audio"].click()
        XCTAssertTrue(
            app.buttons["Refresh Devices"].waitForExistence(timeout: 5.0),
            "Audio tab should show the device list controls"
        )

        app.buttons["Permissions"].click()
        XCTAssertTrue(
            app.staticTexts["App Permissions"].waitForExistence(timeout: 5.0),
            "Permissions tab should show the permissions list"
        )
    }
}
