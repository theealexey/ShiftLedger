import XCTest

final class ShiftLedgerUITests: XCTestCase {
    @MainActor
    func testFreshLaunchShowsJobSetup() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing-reset-store")
        app.launch()

        let onboardingTitle = app.staticTexts["jobSetup.payBasis.title"]
        XCTAssertTrue(onboardingTitle.waitForExistence(timeout: 5))
    }
}
