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
    func testPersistedJobRelaunchShowsAddShift() {
        let firstLaunch = XCUIApplication()
        firstLaunch.launchArguments.append(contentsOf: [
            "-ui-testing-reset-store",
            "-ui-testing-seed-job"
        ])
        firstLaunch.launch()

        let firstAddShiftScreen = firstLaunch.scrollViews["addShift.screen"]
        XCTAssertTrue(firstAddShiftScreen.waitForExistence(timeout: 5))
        firstLaunch.terminate()

        let secondLaunch = XCUIApplication()
        secondLaunch.launch()

        let secondAddShiftScreen = secondLaunch.scrollViews["addShift.screen"]
        XCTAssertTrue(secondAddShiftScreen.waitForExistence(timeout: 5))
        secondLaunch.terminate()
    }
}
