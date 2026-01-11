import XCTest

final class speaktypeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchAndNavigation() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Verify Sidebar exists (macOS List maps to Outline)
        let sidebar = app.outlines.firstMatch
        // Wait up to 10s for UI to stabilize (increased for robustness)
        if !sidebar.waitForExistence(timeout: 10.0) {
            print("🚨 Sidebar NOT found! App Hierarchy:\n\(app.debugDescription)")
            XCTFail("Sidebar should exist (Outline)")
        }
        
        // Navigate to Settings
        // On macOS, text is often exposed directly. We look for "Settings" static text.
        let settingsText = app.staticTexts["Settings"]
        
        if settingsText.waitForExistence(timeout: 5.0) {
             settingsText.click()
             
             // Verify we are on Settings View
             let settingsContent = app.staticTexts["Startup Behavior"]
             XCTAssertTrue(settingsContent.waitForExistence(timeout: 5.0), "Should find Settings content")
        }
    }
}
