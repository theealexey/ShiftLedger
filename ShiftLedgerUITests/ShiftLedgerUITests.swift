import Foundation
import XCTest

final class ShiftLedgerUITests: XCTestCase {
    private struct ShiftTime {
        let hour: Int
        let minute: Int
        let meridiem: String
    }

    private enum ScrollDirection {
        case towardTop
        case towardBottom
    }

    // MARK: - Existing coverage

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

    // MARK: - SL-476

    @MainActor
    func testFixedPerShiftPaycheckWorkflowPersistsEditsAndDeletes() throws {
        let app = makeApplication(resetStore: true)
        app.launch()

        try completeFixedPerShiftOnboarding(in: app)
        try assertOverviewExists(in: app)

        attachScreenshot(
            named: "01-overview-empty-after-onboarding",
            from: app
        )

        let firstStart = ShiftTime(hour: 8, minute: 0, meridiem: "AM")
        let firstEnd = ShiftTime(hour: 9, minute: 0, meridiem: "AM")
        let secondStart = ShiftTime(hour: 10, minute: 0, meridiem: "AM")
        let secondEnd = ShiftTime(hour: 11, minute: 0, meridiem: "AM")

        try addShift(
            start: firstStart,
            end: firstEnd,
            in: app
        )

        try assertShiftCount(
            1,
            expectedHeroAmount: "1.00",
            in: app
        )

        try addShift(
            start: secondStart,
            end: secondEnd,
            in: app
        )

        try assertShiftCount(
            2,
            expectedHeroAmount: "2.01",
            in: app
        )

        attachScreenshot(
            named: "02-overview-two-shifts",
            from: app
        )

        app.terminate()

        let relaunchedApp = makeApplication()
        relaunchedApp.launch()

        try assertOverviewExists(in: relaunchedApp)

        try requireCondition(
            relaunchedApp.staticTexts["jobSetup.step1.title"].exists == false,
            message: "Persisted Job must bypass onboarding"
        )

        try assertShiftCount(
            2,
            expectedHeroAmount: "2.01",
            in: relaunchedApp
        )

        attachScreenshot(
            named: "03-overview-after-relaunch",
            from: relaunchedApp
        )

        try verifyPaycheckResult(in: relaunchedApp)

        let editedCardIdentifier = try editOneShift(
            in: relaunchedApp,
            newStart: ShiftTime(
                hour: 12,
                minute: 0,
                meridiem: "PM"
            ),
            newEnd: ShiftTime(
                hour: 1,
                minute: 0,
                meridiem: "PM"
            )
        )

        try assertShiftCount(
            2,
            expectedHeroAmount: "2.01",
            in: relaunchedApp
        )

        let editedCard = try requireElement(
            relaunchedApp.buttons[editedCardIdentifier],
            message: "Edited Shift must preserve its persisted identifier"
        )

        let editedLabel = normalizedWhitespace(editedCard.label)

        try requireCondition(
            editedLabel.contains("12:00"),
            message:
                "Edited Shift must expose 12:00 start. "
                + "Observed: \(editedCard.label)"
        )

        try requireCondition(
            editedLabel.contains("1:00 PM"),
            message:
                "Edited Shift must expose 1:00 PM end. "
                + "Observed: \(editedCard.label)"
        )

        attachScreenshot(
            named: "06-overview-after-edit",
            from: relaunchedApp
        )

        let deletedIdentifier =
            try deleteShiftWithCancellationThenConfirmation(
                cardIdentifier: editedCardIdentifier,
                in: relaunchedApp
            )

        try assertShiftCount(
            1,
            expectedHeroAmount: "1.00",
            in: relaunchedApp
        )

        try assertButtonDoesNotExist(
            identifier: deletedIdentifier,
            in: relaunchedApp,
            message: "Confirmed Delete must remove the exact Shift card"
        )

        attachScreenshot(
            named: "07-overview-after-delete",
            from: relaunchedApp
        )

        relaunchedApp.terminate()

        let finalRelaunch = makeApplication()
        finalRelaunch.launch()

        try assertOverviewExists(in: finalRelaunch)

        try assertShiftCount(
            1,
            expectedHeroAmount: "1.00",
            in: finalRelaunch
        )

        try assertButtonDoesNotExist(
            identifier: deletedIdentifier,
            in: finalRelaunch,
            message: "Deleted Shift must not return after relaunch"
        )

        attachScreenshot(
            named: "08-overview-after-delete-relaunch",
            from: finalRelaunch
        )

        finalRelaunch.terminate()
    }

    // MARK: - Onboarding

    @MainActor
    private func completeFixedPerShiftOnboarding(
        in app: XCUIApplication
    ) throws {
        attachScreenshot(named: "00-onboarding-initial", from: app)

        let workTypeName = try scrollToHittable(
            requerying: {
                app.textFields["jobSetup.workTypeName"]
            },
            in: app,
            direction: .towardBottom,
            message: "Work Type name field must be reachable"
        )

        attachScreenshot(named: "00-onboarding-work-type-reachable", from: app)

        workTypeName.tap()
        workTypeName.typeText("Runtime shift")

        // Production JobSetupView.textFieldShouldReturn calls endEditing(true).
        workTypeName.typeText("\n")

        try requireKeyboardHidden(
            in: app,
            message: "Work Type keyboard must dismiss after Return"
        )

        let perShift = try requireElement(
            app.buttons["Per shift"],
            message: "Per shift pay basis must exist"
        )

        let reachablePerShift = try scrollToHittable(
            perShift,
            in: app,
            direction: .towardBottom,
            message: "Per shift pay basis must be reachable"
        )

        reachablePerShift.tap()

        let amount = try requireElement(
            app.textFields["Pay per shift"],
            message: "Pay per shift field must exist"
        )

        let reachableAmount = try scrollToHittable(
            amount,
            in: app,
            direction: .towardBottom,
            message: "Pay per shift field must be reachable"
        )

        reachableAmount.tap()
        reachableAmount.typeText("1.004")

        // decimalPad has no Return button.
        // Move first-responder back to the normal text field, then use its
        // real production Return handling to end editing.
        let reachableWorkTypeName = try scrollToHittable(
            workTypeName,
            in: app,
            direction: .towardTop,
            message:
                "Work Type name field must be reachable to dismiss decimal keyboard"
        )

        reachableWorkTypeName.tap()
        reachableWorkTypeName.typeText("\n")

        try requireKeyboardHidden(
            in: app,
            message: "Decimal keyboard must be dismissed before Currency"
        )

        let currency = try requireElement(
            app.buttons["Currency"],
            message: "Currency button must exist"
        )

        let reachableCurrency = try scrollToHittable(
            currency,
            in: app,
            direction: .towardBottom,
            message: "Currency button must be reachable"
        )

        reachableCurrency.tap()

        let search = try requireElement(
            app.searchFields.firstMatch,
            message: "Currency search field must exist"
        )

        _ = try requireHittable(
            search,
            message: "Currency search field must be hittable"
        )

        search.tap()
        search.typeText("EUR")

        let euro = try requireElement(
            app.cells["EUR, Euro"],
            message: "EUR currency row must exist"
        )

        _ = try requireHittable(
            euro,
            message: "EUR currency row must be hittable"
        )

        euro.tap()

        let firstContinue = try requireElement(
            app.buttons["Continue"],
            message: "Step 1 Continue must exist"
        )

        _ = try requireHittable(
            firstContinue,
            message: "Step 1 Continue must be hittable"
        )

        firstContinue.tap()

        let calendarMonth = try requireElement(
            app.buttons["Calendar month"],
            message: "Calendar month option must exist"
        )

        let reachableCalendarMonth = try scrollToHittable(
            calendarMonth,
            in: app,
            direction: .towardBottom,
            message: "Calendar month option must be reachable"
        )

        reachableCalendarMonth.tap()

        let secondContinue = try requireElement(
            app.buttons["Continue"],
            message: "Step 2 Continue must exist"
        )

        _ = try requireHittable(
            secondContinue,
            message: "Step 2 Continue must be hittable"
        )

        secondContinue.tap()

        let start = try requireElement(
            app.buttons["Start"],
            message: "Job Setup Start must exist"
        )

        _ = try requireHittable(
            start,
            message: "Job Setup Start must be hittable"
        )

        start.tap()
    }

    // MARK: - Add Shift

    @MainActor
    private func addShift(
        start: ShiftTime,
        end: ShiftTime,
        in app: XCUIApplication
    ) throws {
        let addShift = try scrollToHittable(
            requerying: {
                app.buttons["overview.addShift"]
            },
            in: app,
            direction: .towardBottom,
            message: "Overview Add Shift must be reachable"
        )

        addShift.tap()

        _ = try requireElement(
            app.scrollViews["addShift.screen"],
            message: "Add Shift screen must appear"
        )

        let startRow = try scrollToHittable(
            requerying: {
                app.buttons["addShift.start"]
            },
            in: app,
            direction: .towardBottom,
            message: "Add Shift Start row must be reachable"
        )

        try select(
            start,
            for: startRow,
            in: app
        )

        let endRow = try scrollToHittable(
            requerying: {
                app.buttons["addShift.end"]
            },
            in: app,
            direction: .towardBottom,
            message: "Add Shift End row must be reachable"
        )

        try select(
            end,
            for: endRow,
            in: app
        )

        let save = try requireElement(
            app.navigationBars.buttons["Save"],
            message: "Add Shift Save must exist"
        )

        _ = try requireHittable(
            save,
            message: "Add Shift Save must be hittable"
        )

        save.tap()

        try assertOverviewExists(in: app)
    }

    // MARK: - Paycheck

    @MainActor
    private func verifyPaycheckResult(
        in app: XCUIApplication
    ) throws {
        let checkPaycheck = try scrollToHittable(
            requerying: {
                app.buttons["overview.checkPaycheck"]
            },
            in: app,
            direction: .towardBottom,
            message: "Check Paycheck must be reachable"
        )

        checkPaycheck.tap()

        _ = try requireElement(
            app.otherElements["actualGrossEntry.screen"],
            message: "Actual Gross screen must appear"
        )

        let amount = try scrollToHittable(
            requerying: {
                app.textFields["actualGrossEntry.amount.input"]
            },
            in: app,
            direction: .towardBottom,
            message: "Actual Gross input must be reachable"
        )

        amount.tap()
        amount.typeText("2.010")

        let compare = try scrollToHittable(
            requerying: {
                app.buttons["actualGrossEntry.compare"]
            },
            in: app,
            direction: .towardBottom,
            message:
                "Compare must remain reachable while decimal keyboard is visible"
        )

        compare.tap()

        _ = try requireElement(
            app.otherElements["paycheckResult.screen"],
            message: "Paycheck Result screen must appear"
        )

        let breakdownAmounts = breakdownAmountElements(in: app)

        try requireCondition(
            breakdownAmounts.count == 2,
            message:
                "Expected 2 breakdown rows. "
                + "Observed: \(breakdownAmounts.count)"
        )

        for index in 0 ... 1 {
            try assertContainsAmount(
                "1.004",
                in: app.staticTexts[
                    "paycheckResult.breakdown.row.\(index).rate"
                ],
                message:
                    "Breakdown row \(index) rate must contain 1.004"
            )

            try assertContainsAmount(
                "1.004",
                in: app.staticTexts[
                    "paycheckResult.breakdown.row.\(index).amount"
                ],
                message:
                    "Breakdown row \(index) contribution must contain 1.004"
            )
        }

        try assertContainsAmount(
            "2.008",
            in: app.staticTexts["paycheckResult.expected.value"],
            message: "Expected must contain 2.008"
        )

        try assertContainsAmount(
            "2.010",
            in: app.staticTexts["paycheckResult.actual.value"],
            message: "Actual must contain 2.010"
        )

        let difference = try requireElement(
            app.staticTexts["paycheckResult.difference.value"],
            message: "Difference must exist"
        )

        let normalizedDifference =
            normalizedAmountLabel(difference.label)

        try requireCondition(
            normalizedDifference.contains("0.002"),
            message:
                "Difference must contain 0.002. "
                + "Observed: \(difference.label)"
        )

        try requireCondition(
            difference.label.contains("+"),
            message:
                "Positive Difference must preserve +. "
                + "Observed: \(difference.label)"
        )

        attachScreenshot(
            named: "04-paycheck-result-top",
            from: app
        )

        let done = try requireElement(
            app.buttons["paycheckResult.done"],
            message: "Result Done must exist"
        )

        let reachableDone = try scrollToHittable(
            done,
            in: app,
            direction: .towardBottom,
            message: "Result Done must be reachable"
        )

        attachScreenshot(
            named: "05-paycheck-result-bottom",
            from: app
        )

        reachableDone.tap()

        try assertOverviewExists(in: app)
    }

    // MARK: - Edit

    @MainActor
    private func editOneShift(
        in app: XCUIApplication,
        newStart: ShiftTime,
        newEnd: ShiftTime
    ) throws -> String {
        let identifier = try firstShiftCardIdentifier(in: app)

        try openEdit(
            forCardIdentifier: identifier,
            in: app
        )

        let startRow = try scrollToHittable(
            requerying: {
                app.buttons["editShift.start"]
            },
            in: app,
            direction: .towardBottom,
            message: "Edit Shift Start row must be reachable"
        )

        try select(
            newStart,
            for: startRow,
            in: app
        )

        let endRow = try scrollToHittable(
            requerying: {
                app.buttons["editShift.end"]
            },
            in: app,
            direction: .towardBottom,
            message: "Edit Shift End row must be reachable"
        )

        try select(
            newEnd,
            for: endRow,
            in: app
        )

        let save = try requireElement(
            app.buttons["editShift.save"],
            message: "Edit Shift Save must exist"
        )

        _ = try requireHittable(
            save,
            message: "Edit Shift Save must be hittable"
        )

        save.tap()

        try assertOverviewExists(in: app)

        return identifier
    }

    // MARK: - Delete

    @MainActor
    private func deleteShiftWithCancellationThenConfirmation(
        cardIdentifier: String,
        in app: XCUIApplication
    ) throws -> String {
        try openEdit(
            forCardIdentifier: cardIdentifier,
            in: app
        )

        let delete = try scrollToHittable(
            requerying: {
                app.buttons["editShift.delete"]
            },
            in: app,
            direction: .towardBottom,
            message: "Delete Shift must be reachable"
        )

        delete.tap()

        let cancel = try requireElement(
            app.alerts.buttons["Cancel"],
            message: "Delete alert must expose Cancel"
        )

        cancel.tap()

        _ = try requireElement(
            app.scrollViews["editShift.screen"],
            message: "Cancel must keep Edit Shift open"
        )

        let deleteAgain = try scrollToHittable(
            requerying: {
                app.buttons["editShift.delete"]
            },
            in: app,
            direction: .towardBottom,
            message: "Delete must remain reachable after cancellation"
        )

        deleteAgain.tap()

        let confirm = try requireElement(
            app.alerts.buttons["Delete Shift"],
            message: "Delete confirmation must expose Delete Shift"
        )

        confirm.tap()

        try assertOverviewExists(in: app)

        return cardIdentifier
    }

    // MARK: - Picker

    @MainActor
    private func select(
        _ time: ShiftTime,
        for row: XCUIElement,
        in app: XCUIApplication
    ) throws {
        _ = try requireHittable(
            row,
            message: "Shift date/time row must be hittable"
        )

        row.tap()

        let picker = try requireElement(
            app.datePickers.firstMatch,
            message: "Date/time picker must appear"
        )

        let wheels = picker.pickerWheels.allElementsBoundByIndex

        try requireCondition(
            wheels.count == 4,
            message:
                "Expected 4 picker wheels; observed \(wheels.count)"
        )

        wheels[1].adjust(
            toPickerWheelValue: String(time.hour)
        )

        wheels[2].adjust(
            toPickerWheelValue: String(
                format: "%02d",
                time.minute
            )
        )

        wheels[3].adjust(
            toPickerWheelValue: time.meridiem
        )

        let done = try requireElement(
            app.navigationBars.buttons["Done"],
            message: "Picker Done must exist"
        )

        _ = try requireHittable(
            done,
            message: "Picker Done must be hittable"
        )

        done.tap()
    }

    // MARK: - Overview

    @MainActor
    private func assertOverviewExists(
        in app: XCUIApplication
    ) throws {
        _ = try requireElement(
            app.otherElements["overview.screen"],
            message: "Overview must exist"
        )
    }

    @MainActor
    private func assertShiftCount(
        _ expected: Int,
        expectedHeroAmount: String,
        in app: XCUIApplication
    ) throws {
        let count = try requireElement(
            app.descendants(matching: .any)[
                "overview.shiftHistory.title"
            ],
            message: "Overview Shift count must exist"
        )

        let expectedLabel = "Shifts · \(expected)"

        try requireCondition(
            normalizedWhitespace(count.label) == expectedLabel,
            message:
                "Expected '\(expectedLabel)'; "
                + "observed '\(count.label)'"
        )

        let cards = shiftCards(in: app)

        try requireCondition(
            cards.count == expected,
            message:
                "Expected \(expected) Shift cards; "
                + "observed \(cards.count)"
        )

        let hero = try requireElement(
            app.staticTexts["overview.expectedGross.amount"],
            message: "Expected Gross hero must exist"
        )

        try requireCondition(
            normalizedAmountLabel(hero.label)
                .hasSuffix(expectedHeroAmount),
            message:
                "Expected hero \(expectedHeroAmount); "
                + "observed '\(hero.label)'"
        )
    }

    // MARK: - Shift identity

    @MainActor
    private func firstShiftCardIdentifier(
        in app: XCUIApplication
    ) throws -> String {
        let first = try XCTUnwrap(
            shiftCards(in: app).first,
            "Expected at least one persisted Shift card"
        )

        return try XCTUnwrap(
            first.identifier.isEmpty
                ? nil
                : first.identifier,
            "Shift card must expose a stable identifier"
        )
    }

    @MainActor
    private func openEdit(
        forCardIdentifier cardIdentifier: String,
        in app: XCUIApplication
    ) throws {
        let card = try scrollToHittable(
            requerying: {
                app.buttons[cardIdentifier]
            },
            in: app,
            direction: .towardTop,
            message: "Shift card \(cardIdentifier) must be reachable"
        )

        if String(describing: card.value).contains("Expanded") == false {
            _ = try requireHittable(
                card,
                message: "Collapsed Shift card must be hittable"
            )

            card.tap()

            let expanded = XCTNSPredicateExpectation(
                predicate: NSPredicate(
                    format: "value CONTAINS[c] %@",
                    "Expanded"
                ),
                object: card
            )

            try requireCondition(
                XCTWaiter.wait(for: [expanded], timeout: 5) == .completed,
                message: "Shift card \(cardIdentifier) must become Expanded"
            )
        }

        let expandedCard = try requireElement(
            app.buttons[cardIdentifier],
            message: "Expanded Shift card \(cardIdentifier) must remain present"
        )

        try requireCondition(
            String(describing: expandedCard.value).contains("Expanded"),
            message: "Shift card \(cardIdentifier) must remain Expanded"
        )

        let checkPaycheck = try scrollToHittable(
            requerying: {
                app.buttons["overview.checkPaycheck"]
            },
            in: app,
            direction: .towardBottom,
            message: "Check Paycheck must be reachable below the expanded Shift card"
        )

        let cardValueBeforeTap = String(describing: expandedCard.value)
        let cardFrame = expandedCard.frame
        let checkPaycheckFrame = checkPaycheck.frame
        let editX = checkPaycheckFrame.midX
        let editY = checkPaycheckFrame.minY - 24 - 30

        try requireCondition(
            !checkPaycheckFrame.isEmpty,
            message: "Check Paycheck must have a non-empty frame"
        )

        try requireCondition(
            app.frame.contains(CGPoint(x: editX, y: editY)),
            message: "Calculated Edit point must be within the application frame"
        )

        try requireCondition(
            cardValueBeforeTap.contains("Expanded"),
            message: "Shift card \(cardIdentifier) must remain Expanded before tapping Edit"
        )

        let appOrigin = app.coordinate(
            withNormalizedOffset: CGVector(dx: 0, dy: 0)
        )

        appOrigin.withOffset(
            CGVector(dx: editX, dy: editY)
        ).tap()

        _ = try requireElement(
            app.scrollViews["editShift.screen"],
            message:
                "Edit Shift screen must appear after tapping the expanded card Edit control. "
                + "card=\(cardIdentifier), value=\(cardValueBeforeTap), "
                + "cardFrame=\(cardFrame), checkPaycheckFrame=\(checkPaycheckFrame), "
                + "editPoint=(\(editX), \(editY))"
        )
    }

    @MainActor
    private func shiftCards(
        in app: XCUIApplication
    ) -> [XCUIElement] {
        app.buttons
            .matching(
                NSPredicate(
                    format: "identifier MATCHES %@",
                    "^overview\\.shift\\.[0-9A-Fa-f-]{36}$"
                )
            )
            .allElementsBoundByIndex
    }

    // MARK: - Result assertions

    @MainActor
    private func breakdownAmountElements(
        in app: XCUIApplication
    ) -> [XCUIElement] {
        app.staticTexts
            .matching(
                NSPredicate(
                    format: "identifier MATCHES %@",
                    "^paycheckResult\\.breakdown\\.row\\.[0-9]+\\.amount$"
                )
            )
            .allElementsBoundByIndex
    }

    @MainActor
    private func assertContainsAmount(
        _ amount: String,
        in element: XCUIElement,
        message: String
    ) throws {
        let element = try requireElement(
            element,
            message: message
        )

        try requireCondition(
            normalizedAmountLabel(element.label)
                .contains(amount),
            message:
                "\(message). Observed: '\(element.label)'"
        )
    }

    // MARK: - Keyboard

    @MainActor
    private func requireKeyboardHidden(
        in app: XCUIApplication,
        message: String
    ) throws {
        let keyboard = app.keyboards.firstMatch

        if keyboard.exists == false {
            return
        }

        try requireCondition(
            keyboard.waitForNonExistence(timeout: 2),
            message: message
        )
    }

    // MARK: - Scrolling

    @MainActor
    private func scrollToHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        direction: ScrollDirection,
        message: String
    ) throws -> XCUIElement {
        _ = try requireElement(
            element,
            message: message
        )

        if element.isHittable {
            return element
        }

        let scrollView = app.scrollViews.firstMatch

        for _ in 0 ..< 6 {
            if element.isHittable {
                return element
            }

            switch direction {
            case .towardTop:
                if scrollView.exists {
                    scrollView.swipeDown()
                } else {
                    app.swipeDown()
                }

            case .towardBottom:
                if scrollView.exists {
                    scrollView.swipeUp()
                } else {
                    app.swipeUp()
                }
            }
        }

        return try requireHittable(
            element,
            message: message
        )
    }

    @MainActor
    private func scrollToHittable(
        requerying query: () -> XCUIElement,
        in app: XCUIApplication,
        direction: ScrollDirection,
        message: String
    ) throws -> XCUIElement {
        var element = try requireElement(query(), message: message)

        if element.isHittable {
            return element
        }

        let scrollView = app.scrollViews.firstMatch

        for _ in 0 ..< 6 {
            switch direction {
            case .towardTop:
                if scrollView.exists {
                    scrollView.swipeDown()
                } else {
                    app.swipeDown()
                }

            case .towardBottom:
                if scrollView.exists {
                    scrollView.swipeUp()
                } else {
                    app.swipeUp()
                }
            }

            element = try requireElement(query(), message: message)
            if element.isHittable {
                return element
            }
        }

        return try requireHittable(element, message: message)
    }

    // MARK: - Requirements

    @MainActor
    private func requireElement(
        _ element: XCUIElement,
        timeout: TimeInterval = 5,
        message: String
    ) throws -> XCUIElement {
        let exists = element.waitForExistence(
            timeout: timeout
        )

        return try XCTUnwrap(
            exists ? element : nil,
            message
        )
    }

    @MainActor
    private func requireHittable(
        _ element: XCUIElement,
        message: String
    ) throws -> XCUIElement {
        try XCTUnwrap(
            element.isHittable ? element : nil,
            message
        )
    }

    @MainActor
    private func requireCondition(
        _ condition: @autoclosure () -> Bool,
        message: String
    ) throws {
        _ = try XCTUnwrap(
            condition() ? true : nil,
            message
        )
    }

    @MainActor
    private func assertButtonDoesNotExist(
        identifier: String,
        in app: XCUIApplication,
        message: String
    ) throws {
        let element = app.buttons[identifier]

        try requireCondition(
            element.waitForNonExistence(timeout: 5),
            message: message
        )
    }

    // MARK: - Application

    @MainActor
    private func makeApplication(
        resetStore: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()

        app.launchArguments = [
            "-AppleLanguages",
            "(en)",
            "-AppleLocale",
            "en_US",
            // Locale alone does not override the simulator's 24-hour preference.
            "-AppleICUForce24HourTime",
            "NO",
            "-AppleICUForce12HourTime",
            "YES"
        ]

        if resetStore {
            app.launchArguments.append(
                "-ui-testing-reset-store"
            )
        }

        return app
    }

    // MARK: - Screenshots

    @MainActor
    private func attachScreenshot(
        named name: String,
        from app: XCUIApplication
    ) {
        let attachment = XCTAttachment(
            screenshot: app.screenshot()
        )

        attachment.name = name
        attachment.lifetime = .keepAlways

        add(attachment)
    }

    // MARK: - Normalization

    private func normalizedWhitespace(
        _ text: String
    ) -> String {
        text
            .replacingOccurrences(
                of: "\u{202F}",
                with: " "
            )
            .replacingOccurrences(
                of: "\u{00A0}",
                with: " "
            )
            .replacingOccurrences(
                of: "\u{2009}",
                with: " "
            )
    }

    private func normalizedAmountLabel(
        _ text: String
    ) -> String {
        normalizedWhitespace(text)
            .replacingOccurrences(
                of: ",",
                with: "."
            )
    }
}
