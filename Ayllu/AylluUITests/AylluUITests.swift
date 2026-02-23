import XCTest

final class AylluUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    @MainActor
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        // Verify app launches successfully
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}
