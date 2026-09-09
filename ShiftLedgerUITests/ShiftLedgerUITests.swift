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

    @MainActor
    func testPersistedJobRelaunchShowsOverview() {
        let firstLaunch = XCUIApplication()
        firstLaunch.launchArguments.append(contentsOf: [
            "-ui-testing-reset-store",
            "-ui-testing-seed-job"
        ])
        firstLaunch.launch()

        let firstOverviewScreen = firstLaunch.otherElements["overview.screen"]
        XCTAssertTrue(firstOverviewScreen.waitForExistence(timeout: 5))
        firstLaunch.terminate()

        let secondLaunch = XCUIApplication()
        secondLaunch.launch()

        let secondOverviewScreen = secondLaunch.otherElements["overview.screen"]
        XCTAssertTrue(secondOverviewScreen.waitForExistence(timeout: 5))
        secondLaunch.terminate()
    }
}
