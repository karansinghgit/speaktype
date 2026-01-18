import XCTest

final class speaktypeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchAndNavigation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        
        // Wait for app to fully load
        sleep(2)
        
        // Navigate to Settings - look for the link directly
        let settingsLink = app.links["Settings"]
        XCTAssertTrue(settingsLink.waitForExistence(timeout: 5.0), "Settings link should exist")
        
        settingsLink.click()
        
        // Verify we are on Settings View
        let settingsContent = app.staticTexts["SpeakType Shortcuts"]
        XCTAssertTrue(settingsContent.waitForExistence(timeout: 5.0), "Should find Settings content")
    }
    
    func testSidebarNavigation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        
        // Wait for app to fully load
        sleep(2)
        
        // Define sidebar items to test - these should appear as NavigationLinks
        let items = ["Dashboard", "Transcribe Audio", "History", "AI Models", "Permissions", "Settings"]
        
        for item in items {
            let link = app.links[item]
            XCTAssertTrue(link.exists, "Link for '\(item)' should exist")
            
            if link.exists {
                link.click()
                // Just verify we can click without crashing
                sleep(1)
            }
        }
    }
}

