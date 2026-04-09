import XCTest

final class AylluUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()

        let projectsTab = app.tabBars.buttons["Projects"]
        XCTAssertTrue(projectsTab.waitForExistence(timeout: 10))
    }

    // MARK: - Tab Navigation

    @MainActor
    func testTabNavigation() throws {
        app.tabBars.buttons["Map"].tap()
        XCTAssertTrue(app.navigationBars["Map"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Notes"].tap()
        XCTAssertTrue(app.navigationBars["Notes"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Projects"].tap()
        XCTAssertTrue(app.navigationBars["Projects"].waitForExistence(timeout: 3))
    }

    // MARK: - Project Creation

    @MainActor
    func testProjectCreationFlow() throws {
        let addButton = app.buttons["addProjectButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let nameField = app.textFields["projectNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText("Test Project")

        let saveButton = app.buttons["saveProjectButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3))
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()

        let projectCell = app.staticTexts["Test Project"]
        XCTAssertTrue(projectCell.waitForExistence(timeout: 5))
    }

    // MARK: - Project Detail Navigation

    @MainActor
    func testProjectDetailNavigation() throws {
        createTestProject(name: "Detail Test Project")

        let projectCell = app.staticTexts["Detail Test Project"]
        XCTAssertTrue(projectCell.waitForExistence(timeout: 5))
        projectCell.tap()

        let navBar = app.navigationBars["Detail Test Project"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 3))
    }

    // MARK: - Settings

    @MainActor
    func testSettingsView() throws {
        app.tabBars.buttons["Settings"].tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        // Verify interactive settings controls exist
        XCTAssertTrue(app.switches["Use True North"].waitForExistence(timeout: 5))
    }

    // MARK: - Helpers

    private func createTestProject(name: String) {
        let addButton = app.buttons["addProjectButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let nameField = app.textFields["projectNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText(name)

        app.buttons["saveProjectButton"].tap()

        // Wait for list to reappear with the new project
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
    }
}

// MARK: - Onboarding Tests

final class AylluOnboardingUITests: XCTestCase {
    @MainActor
    func testOnboardingFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "NO"]
        app.launch()

        // Page 1: Welcome
        XCTAssertTrue(app.staticTexts["Welcome to Ayllu"].waitForExistence(timeout: 10))

        // Tap Next through pages 1-4
        for pageIndex in 0..<4 {
            let nextButton = app.buttons["onboardingNextButton"]
            XCTAssertTrue(
                nextButton.waitForExistence(timeout: 5),
                "Next button not found on page \(pageIndex + 1)"
            )
            nextButton.tap()
        }

        // Page 5: Get Started
        let getStartedButton = app.buttons["onboardingGetStartedButton"]
        XCTAssertTrue(getStartedButton.waitForExistence(timeout: 5))
        getStartedButton.tap()

        // Verify we're now on the main app
        let projectsTab = app.tabBars.buttons["Projects"]
        XCTAssertTrue(projectsTab.waitForExistence(timeout: 5))
    }
}
