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

    @MainActor
    func testSettingsEnglish() throws {
        try verifySettings(language: "en", locale: "en_US", title: "Settings", currency: "Currency",
                           history: "Pay Rate History", size: "L", screenshot: "SL543-en-light")
    }

    @MainActor
    func testSettingsRussian() throws {
        try verifySettings(language: "ru", locale: "ru_RU", title: "Настройки", currency: "Валюта",
                           history: "История ставок", size: "L", screenshot: "SL543-ru-dark")
    }

    @MainActor
    func testSettingsRussianAXXXL() throws {
        try verifySettings(language: "ru", locale: "ru_RU", title: "Настройки", currency: "Валюта",
                           history: "История ставок", size: "AccessibilityXXXL", screenshot: "SL543-ru-dark-axxxl")
    }

    @MainActor
    private func verifySettings(language: String, locale: String, title: String, currency: String,
                                history: String, size: String, screenshot: String) throws {
        let app = isolatedApplication()
        app.launchArguments = [
            "-ui-testing-seed-job", "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale, "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategory\(size)"
        ]
        app.launch()
        let tab = app.tabBars.buttons[title]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
        let currencyRow = app.staticTexts["settings.currency"]
        XCTAssertEqual(currencyRow.label, currency)
        let code = try XCTUnwrap(currencyRow.value as? String)
        XCTAssertEqual(code, "EUR")
        let zone = try XCTUnwrap(app.staticTexts["settings.timeZone"].value as? String)
        XCTAssertEqual(zone, "Europe/Moscow")
        let scroll = app.scrollViews["settings.scroll"]
        attachScreenshot(named: screenshot, from: app)
        let rates = app.buttons["settings.rates"]
        for _ in 0..<4 where !rates.isHittable { scroll.swipeUp() }
        XCTAssertTrue(rates.isHittable)
        XCTAssertGreaterThanOrEqual(rates.frame.height, 44)
        rates.tap()
        XCTAssertTrue(app.navigationBars[history].waitForExistence(timeout: 5))
        if size == "AccessibilityXXXL" { attachScreenshot(named: "SL543-rate-history", from: app) }
        app.navigationBars[history].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
        XCTAssertTrue(tab.isSelected)
    }

    @MainActor
    func testBottomNavigationRussian() {
        let app = launchRussianTabs(size: "L")
        let tabs = app.tabBars.firstMatch
        guard tabs.waitForExistence(timeout: 10) else { return XCTFail("Tab bar unavailable") }
        XCTAssertEqual(tabs.buttons.allElementsBoundByIndex.map(\.label), ["Главная", "Смены", "Архив", "Настройки"])
        XCTAssertFalse(app.buttons["overview.more"].exists)
        let actions = app.scrollViews["overview.pageScroll"]
        let add = app.buttons["overview.addShift"]
        let check = app.buttons["overview.checkPaycheck"]
        for _ in 0..<8 where !add.isHittable || !check.isHittable { actions.swipeUp() }
        XCTAssertTrue(add.isHittable)
        XCTAssertTrue(check.isHittable)
        XCTAssertLessThanOrEqual(add.frame.maxY, tabs.frame.minY + 1)
        attachScreenshot(named: "SL546-home", from: app)

        tabs.buttons["Смены"].tap()
        XCTAssertTrue(tabs.buttons["Смены"].isSelected)
        let rows = app.descendants(matching: .any).matching(NSPredicate(format:
            "identifier MATCHES %@", "overview[.]shift[.][0-9A-Fa-f-]{36}"))
        XCTAssertGreaterThan(rows.count, 0)
        attachScreenshot(named: "SL546-shifts", from: app)
        tabs.buttons["Архив"].tap()
        XCTAssertTrue(app.tables["archive.jobs.list"].waitForExistence(timeout: 5))
        attachScreenshot(named: "SL546-archive", from: app)
        tabs.buttons["Настройки"].tap()
        XCTAssertTrue(app.buttons["settings.workTypes"].exists)
        XCTAssertTrue(app.switches["settings.appLock"].exists)
        XCTAssertFalse(app.buttons["settings.archivedJobs"].exists)
        attachScreenshot(named: "SL546-settings", from: app)
        tabs.buttons["Смены"].tap()
        XCTAssertGreaterThan(rows.count, 0)
        XCTAssertEqual(tabs.buttons.allElementsBoundByIndex.map(\.label), ["Главная", "Смены", "Архив", "Настройки"])
    }

    @MainActor
    func testBottomNavigationRussianAXXXL() {
        let app = launchRussianTabs(size: "AccessibilityXXXL")
        let tabs = app.tabBars.firstMatch
        guard tabs.waitForExistence(timeout: 10) else { return XCTFail("Tab bar unavailable") }
        for title in ["Смены", "Архив", "Настройки", "Главная"] {
            let item = tabs.buttons[title]
            XCTAssertTrue(item.isHittable)
            item.tap()
            XCTAssertTrue(item.isSelected)
        }
        attachScreenshot(named: "SL546-AXXXL", from: app)
    }

    @MainActor
    func testHomeAndSettingsAccessibilityAtBottom() {
        let app = launchRussianTabs(size: "AccessibilityXXXL")
        let tabs = app.tabBars.firstMatch
        guard tabs.waitForExistence(timeout: 10) else { return XCTFail("Tab bar unavailable") }
        let scroll = app.scrollViews["overview.pageScroll"]
        let add = app.buttons["overview.addShift"]
        for _ in 0..<10 where !add.isHittable || add.frame.maxY > tabs.frame.minY { scroll.swipeUp() }
        XCTAssertTrue(add.isHittable)
        XCTAssertLessThanOrEqual(add.frame.maxY, tabs.frame.minY + 1)
        add.tap()
        XCTAssertTrue(app.scrollViews["addShift.screen"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        let check = app.buttons["overview.checkPaycheck"]
        for _ in 0..<6 where !check.isHittable || check.frame.maxY > tabs.frame.minY { scroll.swipeUp() }
        XCTAssertTrue(check.isHittable)
        XCTAssertLessThanOrEqual(check.frame.maxY, tabs.frame.minY + 1)
        attachScreenshot(named: "SL546-review-home-ax", from: app)
        check.tap()
        XCTAssertTrue(app.otherElements["actualGrossEntry.screen"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()

        tabs.buttons["Настройки"].tap()
        let settingsScroll = app.scrollViews["settings.scroll"]
        let version = app.staticTexts["settings.version"]
        for _ in 0..<10 where !version.isHittable || version.frame.maxY > tabs.frame.minY { settingsScroll.swipeUp() }
        XCTAssertTrue(version.isHittable)
        XCTAssertLessThanOrEqual(version.frame.maxY, tabs.frame.minY + 1)
        attachScreenshot(named: "SL546-review-settings-ax", from: app)
    }

    @MainActor
    func testEnglishTabsStayDarkWhenSystemIsLight() {
        let app = isolatedApplication()
        app.launchArguments = ["-ui-testing-seed-job", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let tabs = app.tabBars.firstMatch
        guard tabs.waitForExistence(timeout: 10) else { return XCTFail("Tab bar unavailable") }
        XCTAssertEqual(tabs.buttons.allElementsBoundByIndex.map(\.label), ["Home", "Shifts", "Archive", "Settings"])
        attachScreenshot(named: "SL546-review-en-light-system", from: app)
    }

    @MainActor
    private func launchRussianTabs(size: String) -> XCUIApplication {
        let app = isolatedApplication()
        app.launchArguments = [
            "-ui-testing-seed-job", "-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategory\(size)"
        ]
        app.launch()
        return app
    }

    @MainActor
    func testSL558NumericDateForms() throws {
        let en = makeApplication(resetStore: true)
        en.launchArguments.append("-ui-testing-seed-job")
        en.launch()
        try addShift(start: ShiftTime(hour: 8, minute: 0, meridiem: "AM"),
                     end: ShiftTime(hour: 11, minute: 0, meridiem: "AM"), in: en)
        let recent = en.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.recentShift.")).firstMatch
        XCTAssertTrue(recent.waitForExistence(timeout: 10))
        let identifier = recent.identifier
        recent.tap()
        XCTAssertTrue(en.scrollViews["editShift.screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(en.buttons["editShift.start"].isHittable)
        attachScreenshot(named: "SL558-en-edit", from: en)
        en.navigationBars.buttons.firstMatch.tap()
        let add = try scrollToHittable(requerying: { en.buttons["overview.addShift"] }, in: en,
                                       direction: .towardBottom, message: "Add Shift must be reachable")
        add.tap()
        XCTAssertTrue(en.scrollViews["addShift.screen"].waitForExistence(timeout: 5))
        try select(ShiftTime(hour: 8, minute: 0, meridiem: "AM"), for: en.buttons["addShift.start"], in: en)
        attachScreenshot(named: "SL558-en-add", from: en)
        en.terminate()

        let ru = launchRussianTabs(size: "L")
        let ruRecent = ru.buttons[identifier]
        XCTAssertTrue(ruRecent.waitForExistence(timeout: 10))
        ruRecent.tap()
        XCTAssertTrue(ru.scrollViews["editShift.screen"].waitForExistence(timeout: 5))
        attachScreenshot(named: "SL558-ru-edit", from: ru)
        ru.navigationBars.buttons.firstMatch.tap()
        let ruAdd = try scrollToHittable(requerying: { ru.buttons["overview.addShift"] }, in: ru,
                                         direction: .towardBottom, message: "Add Shift must be reachable")
        ruAdd.tap()
        XCTAssertTrue(ru.scrollViews["addShift.screen"].waitForExistence(timeout: 5))
        ru.buttons["addShift.start"].tap()
        let done = ru.navigationBars.buttons["Готово"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        attachScreenshot(named: "SL558-ru-add", from: ru)
        ru.terminate()
    }

    @MainActor
    func testSL558UnpaidBreakDatesPersist() throws {
        let app = isolatedApplication()
        app.launchArguments = ["-ui-testing-reset-store", "-ui-testing-seed-job",
                               "-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU",
                               "-AppleICUForce24HourTime", "NO", "-AppleICUForce12HourTime", "YES"]
        app.launch()
        let add = try scrollToHittable(requerying: { app.buttons["overview.addShift"] }, in: app,
                                       direction: .towardBottom, message: "Add Shift must be reachable")
        add.tap()
        XCTAssertTrue(app.scrollViews["addShift.screen"].waitForExistence(timeout: 5))
        func setTime(_ identifier: String, hour: String, minute: String) throws {
            let row = try scrollToHittable(requerying: { app.buttons[identifier] }, in: app,
                                           direction: .towardBottom, message: "Date row must be reachable")
            row.tap()
            let picker = try requireElement(app.datePickers.firstMatch, message: "Date picker must appear")
            let wheels = picker.pickerWheels.allElementsBoundByIndex
            try requireCondition(wheels.count == 4, message: "Expected four picker wheels; got \(wheels.count)")
            wheels[1].adjust(toPickerWheelValue: hour)
            wheels[2].adjust(toPickerWheelValue: minute)
            wheels[3].adjust(toPickerWheelValue: "AM")
            let done = app.navigationBars.buttons["Готово"]
            XCTAssertTrue(done.waitForExistence(timeout: 5))
            done.tap()
        }
        try setTime("addShift.start", hour: "8", minute: "00")
        try setTime("addShift.end", hour: "11", minute: "00")
        let toggle = app.switches["addShift.unpaidBreak"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        try setTime("addShift.breakStart", hour: "9", minute: "00")
        try setTime("addShift.breakEnd", hour: "9", minute: "30")
        let start = app.buttons["addShift.breakStart"]
        let end = app.buttons["addShift.breakEnd"]
        XCTAssertTrue(start.isHittable && end.isHittable)
        let startValue = try XCTUnwrap(start.value as? String)
        let endValue = try XCTUnwrap(end.value as? String)
        attachScreenshot(named: "SL558-ru-break-add", from: app)
        app.navigationBars.buttons["Сохранить"].tap()
        let recent = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.recentShift.")).firstMatch
        XCTAssertTrue(recent.waitForExistence(timeout: 10))
        recent.tap()
        XCTAssertTrue(app.scrollViews["editShift.screen"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.switches["editShift.unpaidBreak"].value as? String, "1")
        let editStart = try scrollToHittable(requerying: { app.buttons["editShift.breakStart"] }, in: app,
                                             direction: .towardBottom, message: "Edit break start must be reachable")
        let editEnd = app.buttons["editShift.breakEnd"]
        XCTAssertTrue(editEnd.isHittable)
        XCTAssertEqual(editStart.value as? String, startValue)
        XCTAssertEqual(editEnd.value as? String, endValue)
        attachScreenshot(named: "SL558-ru-break-edit", from: app)
    }

    @MainActor
    func testSL565ExpandedUnpaidBreak() throws {
        let seed = isolatedApplication()
        seed.launchArguments = ["-ui-testing-reset-store", "-ui-testing-seed-job", "-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU", "-AppleICUForce24HourTime", "NO", "-AppleICUForce12HourTime", "YES"]
        seed.launch()
        try scrollToHittable(requerying: { seed.buttons["overview.addShift"] }, in: seed, direction: .towardBottom, message: "Add shift").tap()
        func setTime(_ identifier: String, hour: String, minute: String) throws {
            try scrollToHittable(requerying: { seed.buttons[identifier] }, in: seed, direction: .towardBottom, message: identifier).tap()
            let picker = try requireElement(seed.datePickers.firstMatch, message: "Date picker")
            let wheels = picker.pickerWheels.allElementsBoundByIndex
            try requireCondition(wheels.count == 4, message: "Expected four wheels")
            wheels[1].adjust(toPickerWheelValue: hour)
            wheels[2].adjust(toPickerWheelValue: minute)
            wheels[3].adjust(toPickerWheelValue: "AM")
            seed.navigationBars.buttons["Готово"].tap()
        }
        try setTime("addShift.start", hour: "8", minute: "00")
        try setTime("addShift.end", hour: "11", minute: "00")
        seed.switches["addShift.unpaidBreak"].tap()
        try setTime("addShift.breakStart", hour: "9", minute: "00")
        try setTime("addShift.breakEnd", hour: "9", minute: "30")
        seed.navigationBars.buttons["Сохранить"].tap()
        XCTAssertTrue(seed.buttons["overview.addShift"].waitForExistence(timeout: 10))
        seed.terminate()

        for (language, locale, size, tab) in [("ru", "ru_RU", "L", "Смены"), ("ru", "ru_RU", "AccessibilityXXXL", "Смены"), ("en", "en_US", "L", "Shifts")] {
            let app = isolatedApplication()
            app.launchArguments = ["-ui-testing-seed-job", "-AppleLanguages", "(\(language))", "-AppleLocale", locale, "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategory\(size)"]
            app.launch()
            let shifts = app.tabBars.buttons[tab]
            XCTAssertTrue(shifts.waitForExistence(timeout: 10))
            shifts.tap()
            let card = app.buttons.matching(NSPredicate(format: "identifier MATCHES %@", "overview[.]shift[.][0-9A-Fa-f-]{36}")).firstMatch
            XCTAssertTrue(card.waitForExistence(timeout: 10))
            let identifier = card.identifier
            attachScreenshot(named: "SL565-\(language)-\(size)-collapsed", from: app)
            card.tap()
            XCTAssertTrue(app.buttons[identifier + ".edit"].waitForExistence(timeout: 5))
            XCTAssertTrue(card.isSelected)
            let description = card.label
            for part in (language == "ru" ? ["08:00", "11:00", "09:00", "09:30", "2 ч 30 мин", "30 мин", "250", "100"] : ["8:00", "11:00", "9:00", "9:30", "2 h 30 min", "30 min", "250", "100"]) {
                XCTAssertTrue(description.contains(part), "Missing \(part) in \(description)")
            }
            XCTAssertEqual(card.value as? String, language == "ru" ? "Развернута" : "Expanded")
            let breakTitle = language == "ru" ? "Неоплачиваемый перерыв" : "Unpaid break"
            XCTAssertEqual(description.components(separatedBy: breakTitle).count - 1, 1)
            attachScreenshot(named: "SL565-\(language)-\(size)-expanded", from: app)
            if size == "AccessibilityXXXL" {
                let edit = try scrollToHittable(requerying: { app.buttons[identifier + ".edit"] }, in: app, direction: .towardBottom, message: "Edit must be reachable")
                XCTAssertTrue(edit.isHittable)
                attachScreenshot(named: "SL565-ru-AXXXL-details", from: app)
            }
            let visibleCard = try scrollToHittable(requerying: { app.buttons[identifier] }, in: app, direction: .towardTop, message: "Card must be reachable")
            visibleCard.tap()
            XCTAssertFalse(app.buttons[identifier + ".edit"].exists)
            visibleCard.tap()
            XCTAssertTrue(app.buttons[identifier + ".edit"].waitForExistence(timeout: 5))
            app.terminate()
        }
    }

    @MainActor
    func testSL566ExpandedWorkTypeAndExactContribution() throws {
        let name = "Production equipment inspection and preventive maintenance"
        let exact = "1.00412345678901234567890123456789"
        let app = makeApplication(resetStore: true)
        app.launch()
        try completeFixedPerShiftOnboarding(in: app, name: name, pay: exact)
        try addShift(start: ShiftTime(hour: 8, minute: 0, meridiem: "AM"),
                     end: ShiftTime(hour: 9, minute: 0, meridiem: "AM"), in: app)
        try addShift(start: ShiftTime(hour: 10, minute: 0, meridiem: "AM"),
                     end: ShiftTime(hour: 11, minute: 0, meridiem: "AM"), in: app)

        app.tabBars.buttons["Shifts"].tap()
        let cards = app.buttons.matching(
            NSPredicate(format: "identifier MATCHES %@", "overview[.]shift[.][0-9A-Fa-f-]{36}")
        )
        let newest = try requireElement(cards.element(boundBy: 0), message: "Newest persisted Shift")
        let older = try requireElement(cards.element(boundBy: 1), message: "Older persisted Shift")
        let newestID = newest.identifier
        let olderID = older.identifier
        XCTAssertEqual(newest.value as? String, "Collapsed")
        XCTAssertFalse(newest.label.contains(name))
        attachScreenshot(named: "SL566-en-L-collapsed", from: app)
        newest.tap()
        XCTAssertTrue(app.buttons[newestID + ".edit"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons[newestID].value as? String, "Expanded")
        XCTAssertTrue(app.buttons[newestID].label.contains("Work type: " + name))
        XCTAssertTrue(app.buttons[newestID].label.contains("Exact contribution: €" + exact))
        attachScreenshot(named: "SL566-en-L-fixed-exact", from: app)

        try scrollToHittable(requerying: { app.buttons[olderID] }, in: app, direction: .towardBottom,
                             message: "Older Shift must be reachable").tap()
        XCTAssertTrue(app.buttons[olderID + ".edit"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons[newestID + ".edit"].exists)
        XCTAssertEqual(app.buttons[olderID].value as? String, "Expanded")
        app.terminate()

        let russian = isolatedApplication()
        russian.launchArguments = ["-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU",
                                   "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        russian.launch()
        russian.tabBars.buttons["Смены"].tap()
        let shifted = try scrollToHittable(requerying: { russian.buttons[newestID] }, in: russian,
                                           direction: .towardBottom, message: "Same persisted Shift in RU")
        shifted.tap()
        let expanded = russian.buttons[newestID]
        XCTAssertEqual(expanded.value as? String, "Развернута")
        XCTAssertTrue(expanded.label.contains("Вид работы: " + name))
        let localizedExact = exact.replacingOccurrences(of: ".", with: ",")
        XCTAssertTrue(expanded.label.contains(localizedExact + "\u{00A0}€"))
        attachScreenshot(named: "SL566-ru-AXXXL-work-type", from: russian)
        let edit = try scrollToHittable(requerying: { russian.buttons[newestID + ".edit"] }, in: russian,
                                       direction: .towardBottom, message: "Edit below the expanded fields")
        XCTAssertTrue(edit.isHittable)
        attachScreenshot(named: "SL566-ru-AXXXL-exact-edit", from: russian)
    }

    @MainActor
    func testSL566PersistedMinuteShowsExactHourlyContribution() throws {
        let seed = makeApplication(resetStore: true)
        seed.launchArguments.append("-ui-testing-seed-job")
        seed.launch()
        try addShift(start: ShiftTime(hour: 8, minute: 0, meridiem: "AM"),
                     end: ShiftTime(hour: 8, minute: 1, meridiem: "AM"), in: seed)
        seed.terminate()

        let russian = launchRussianTabs(size: "L")
        russian.tabBars.buttons["Смены"].tap()
        let row = try requireElement(russian.buttons.matching(
            NSPredicate(format: "identifier MATCHES %@", "overview[.]shift[.][0-9A-Fa-f-]{36}")
        ).firstMatch, message: "Persisted one-minute Shift")
        let identifier = row.identifier
        row.tap()
        XCTAssertTrue(russian.buttons[identifier + ".edit"].waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Вид работы: Вид работы без названия"))
        XCTAssertTrue(row.label.contains("1,6666666666666666666666666666666666666\u{00A0}SEK"))
        XCTAssertTrue(row.label.contains("100,00\u{00A0}SEK"))
        attachScreenshot(named: "SL566-ru-L-hourly-exact", from: russian)
    }

    @MainActor
    func testSL559DeleteButtonAccessibilityAndAlert() throws {
        let en = makeApplication(resetStore: true)
        en.launchArguments.append("-ui-testing-seed-job")
        en.launch()
        try addShift(start: ShiftTime(hour: 8, minute: 0, meridiem: "AM"),
                     end: ShiftTime(hour: 11, minute: 0, meridiem: "AM"), in: en)
        let recent = en.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.recentShift.")).firstMatch
        XCTAssertTrue(recent.waitForExistence(timeout: 10))
        let identifier = recent.identifier
        en.terminate()
        let app = launchRussianTabs(size: "AccessibilityXXXL")
        let shift = app.buttons[identifier]
        XCTAssertTrue(shift.waitForExistence(timeout: 10))
        let visible = try scrollToHittable(requerying: { app.buttons[identifier] }, in: app,
                                           direction: .towardBottom, message: "Recent shift must be reachable")
        visible.tap()
        let scroll = app.scrollViews["editShift.screen"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        let delete = app.buttons["editShift.delete"]
        for _ in 0..<8 where !delete.isHittable { scroll.swipeUp() }
        XCTAssertTrue(delete.isHittable)
        attachScreenshot(named: "SL559-ru-axxxl-delete", from: app)
        delete.tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        attachScreenshot(named: "SL559-ru-delete-confirmation", from: app)
        XCTAssertTrue(app.alerts.buttons["Отмена"].exists)
        app.alerts.buttons["Отмена"].tap()
        XCTAssertTrue(scroll.exists)
        app.terminate()
    }

    @MainActor
    func testSL562DeleteConfirmationRemainsReadable() throws {
        let seed = makeApplication(resetStore: true)
        seed.launchArguments.append("-ui-testing-seed-job")
        seed.launch()
        try addShift(start: ShiftTime(hour: 8, minute: 0, meridiem: "AM"),
                     end: ShiftTime(hour: 11, minute: 0, meridiem: "AM"), in: seed)
        let recent = seed.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "home.recentShift.")
        ).firstMatch
        XCTAssertTrue(recent.waitForExistence(timeout: 10))
        let identifier = recent.identifier
        seed.terminate()

        let scenarios = [
            (language: "ru", locale: "ru_RU", size: "L",
             message: "Смена исчезнет из истории и расчёта зарплаты.",
             cancel: "Отмена", confirm: "Удалить смену"),
            (language: "ru", locale: "ru_RU", size: "AccessibilityXXXL",
             message: "Смена исчезнет из истории и расчёта зарплаты.",
             cancel: "Отмена", confirm: "Удалить смену"),
            (language: "en", locale: "en_US", size: "AccessibilityXXXL",
             message: "Removes it from history and expected pay.",
             cancel: "Cancel", confirm: "Delete Shift")
        ]

        for scenario in scenarios {
            let app = isolatedApplication()
            app.launchArguments = [
                "-ui-testing-seed-job",
                "-AppleLanguages", "(\(scenario.language))",
                "-AppleLocale", scenario.locale,
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategory\(scenario.size)"
            ]
            app.launch()
            let shift = try scrollToHittable(
                requerying: { app.buttons[identifier] },
                in: app,
                direction: .towardBottom,
                message: "Seeded Shift must be reachable"
            )
            shift.tap()
            let scroll = try requireElement(
                app.scrollViews["editShift.screen"],
                message: "Edit Shift must open"
            )
            let delete = app.buttons["editShift.delete"]
            for _ in 0..<8 where !delete.isHittable { scroll.swipeUp() }
            XCTAssertTrue(delete.isHittable)
            delete.tap()

            let alert = try requireElement(app.alerts.firstMatch, message: "Confirmation must appear")
            let message = try requireElement(
                alert.staticTexts[scenario.message],
                message: "Confirmation must expose the complete warning"
            )
            let cancel = try requireElement(
                alert.buttons[scenario.cancel],
                message: "Cancel must remain reachable"
            )
            let confirm = try requireElement(
                alert.buttons[scenario.confirm],
                message: "Destructive confirmation must remain reachable"
            )
            attachScreenshot(
                named: "SL562-\(scenario.language)-\(scenario.size)-confirmation",
                from: app
            )
            XCTAssertTrue(alert.frame.contains(message.frame))
            XCTAssertTrue(cancel.isHittable)
            XCTAssertTrue(confirm.isHittable)
            cancel.tap()
            XCTAssertTrue(app.scrollViews["editShift.screen"].exists)
            XCTAssertTrue(app.buttons[identifier].exists == false)
            app.terminate()
        }
    }

    @MainActor
    func testSL563ShiftHistoryUsesScopeTitleAndTotalCounter() throws {
        let seed = makeApplication(resetStore: true)
        seed.launchArguments.append("-ui-testing-seed-job")
        seed.launch()
        for (start, end) in [
            (ShiftTime(hour: 8, minute: 0, meridiem: "AM"), ShiftTime(hour: 9, minute: 0, meridiem: "AM")),
            (ShiftTime(hour: 10, minute: 0, meridiem: "AM"), ShiftTime(hour: 11, minute: 0, meridiem: "AM")),
            (ShiftTime(hour: 1, minute: 0, meridiem: "PM"), ShiftTime(hour: 2, minute: 0, meridiem: "PM"))
        ] {
            try addShift(
                start: start,
                end: end,
                in: seed
            )
        }
        XCTAssertEqual(seed.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "home.recentShift.")
        ).count, 3)
        seed.terminate()

        let scenarios = [
            (language: "ru", locale: "ru_RU", size: "L", tab: "Смены", navigation: "Все смены", total: "Всего"),
            (language: "en", locale: "en_US", size: "L", tab: "Shifts", navigation: "All shifts", total: "Total"),
            (language: "ru", locale: "ru_RU", size: "AccessibilityXXXL", tab: "Смены", navigation: "Все смены", total: "Всего")
        ]

        for scenario in scenarios {
            let app = isolatedApplication()
            app.launchArguments = [
                "-ui-testing-seed-job",
                "-AppleLanguages", "(\(scenario.language))",
                "-AppleLocale", scenario.locale,
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategory\(scenario.size)"
            ]
            app.launch()
            let tabs = try requireElement(app.tabBars.firstMatch, message: "Tab bar must exist")
            let shifts = try requireElement(tabs.buttons[scenario.tab], message: "Shifts tab must exist")
            shifts.tap()
            XCTAssertTrue(shifts.isSelected)
            XCTAssertTrue(tabs.buttons[scenario.tab].exists)

            let navigation = try requireElement(
                app.navigationBars[scenario.navigation],
                message: "Shifts navigation title must use the complete history scope"
            )
            let counterTitle = try requireElement(
                app.staticTexts["overview.shiftCount.label"],
                message: "Internal history counter title must exist"
            )
            let counterValue = try requireElement(
                app.staticTexts["overview.shiftCount.value"],
                message: "Internal history count must exist"
            )
            _ = try requireElement(
                app.staticTexts["overview.receipt.historyScope"],
                message: "History scope subtitle must remain visible"
            )
            XCTAssertEqual(counterTitle.label, scenario.total)
            XCTAssertEqual(counterValue.label, "3")
            XCTAssertEqual(app.buttons.matching(
                NSPredicate(format: "identifier MATCHES %@", "overview[.]shift[.][0-9A-Fa-f-]{36}")
            ).count, 3)
            if scenario.size == "AccessibilityXXXL" {
                XCTAssertFalse(counterTitle.frame.intersects(counterValue.frame))
            }
            attachScreenshot(named: "SL563-\(scenario.language)-\(scenario.size)-shifts", from: app)

            tabs.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.staticTexts["overview.navigation.brand"].exists)
            XCTAssertFalse(navigation.exists)
            app.terminate()
        }
    }

    @MainActor
    func testSL561UnpaidBreakSwitchLayout() throws {
        let seed = makeApplication(resetStore: true)
        seed.launchArguments.append("-ui-testing-seed-job")
        seed.launch()
        try addShift(start: ShiftTime(hour: 8, minute: 0, meridiem: "AM"),
                     end: ShiftTime(hour: 11, minute: 0, meridiem: "AM"), in: seed)
        let recent = seed.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.recentShift.")).firstMatch
        XCTAssertTrue(recent.waitForExistence(timeout: 10))
        let identifier = recent.identifier
        seed.terminate()

        for (language, locale, size, form) in [
            ("ru", "ru_RU", "L", "addShift"),
            ("ru", "ru_RU", "AccessibilityXXXL", "addShift"),
            ("ru", "ru_RU", "AccessibilityXXXL", "editShift"),
            ("en", "en_US", "AccessibilityXXXL", "editShift")
        ] {
            let app = isolatedApplication()
            app.launchArguments = [
                "-ui-testing-seed-job", "-AppleLanguages", "(\(language))", "-AppleLocale", locale,
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategory\(size)"
            ]
            app.launch()
            let entry = form == "addShift" ? app.buttons["overview.addShift"] : app.buttons[identifier]
            try scrollToHittable(entry, in: app, direction: .towardBottom, message: "Open \(form)").tap()

            let scroll = app.scrollViews["\(form).screen"]
            XCTAssertTrue(scroll.waitForExistence(timeout: 5))
            let toggle = app.switches["\(form).unpaidBreak"]
            XCTAssertTrue(toggle.waitForExistence(timeout: 5))
            for _ in 0..<6 where !toggle.isHittable { scroll.swipeUp() }
            attachScreenshot(named: "SL561-\(language)-\(size)-\(form)", from: app)
            let window = app.windows.firstMatch
            XCTAssertTrue(toggle.isHittable)
            XCTAssertGreaterThanOrEqual(toggle.frame.minX, window.frame.minX + 23.5)
            XCTAssertLessThanOrEqual(toggle.frame.maxX, window.frame.maxX - 23.5)
            XCTAssertEqual(toggle.value as? String, "0")
            toggle.tap()
            XCTAssertEqual(toggle.value as? String, "1")
            XCTAssertTrue(app.buttons["\(form).breakStart"].exists)
            for _ in 0..<6 where !toggle.isHittable { scroll.swipeDown() }
            XCTAssertTrue(toggle.isHittable)
            toggle.tap()
            XCTAssertEqual(toggle.value as? String, "0")
            XCTAssertFalse(app.buttons["\(form).breakStart"].exists)
            app.terminate()
        }
    }

    // MARK: - Existing coverage

    @MainActor
    func testFreshLaunchShowsJobSetup() {
        let app = isolatedApplication()
        app.launchArguments.append("-ui-testing-reset-store")
        app.launch()

        let onboardingTitle = app.staticTexts["jobSetup.payBasis.title"]
        XCTAssertTrue(onboardingTitle.waitForExistence(timeout: 5))
    }

    @MainActor
    func testPersistedJobRelaunchShowsOverview() {
        let firstLaunch = isolatedApplication()
        firstLaunch.launchArguments.append(contentsOf: [
            "-ui-testing-reset-store",
            "-ui-testing-seed-job"
        ])
        firstLaunch.launch()

        let firstOverviewScreen = firstLaunch.otherElements["overview.screen"]
        XCTAssertTrue(firstOverviewScreen.waitForExistence(timeout: 5))
        firstLaunch.terminate()

        let secondLaunch = isolatedApplication()
        secondLaunch.launch()

        let secondOverviewScreen = secondLaunch.otherElements["overview.screen"]
        XCTAssertTrue(secondOverviewScreen.waitForExistence(timeout: 5))
        secondLaunch.terminate()
    }

    @MainActor
    func testHomeCompositionRuntime() throws {
        let app = makeApplication(resetStore: true)
        app.launchArguments.append("-ui-testing-seed-job")
        app.launch()
        let shortcut = app.buttons["home.savedShifts"]
        XCTAssertTrue(shortcut.waitForExistence(timeout: 10))
        XCTAssertEqual(shortcut.value as? String, "0")
        XCTAssertFalse(app.buttons["overview.checkPaycheck"].isEnabled)
        attachScreenshot(named: "SL547-en-empty", from: app)

        try addShift(start: ShiftTime(hour: 8, minute: 0, meridiem: "AM"),
                     end: ShiftTime(hour: 11, minute: 0, meridiem: "AM"), in: app)
        XCTAssertEqual(shortcut.value as? String, "1")
        let recent = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.recentShift.")).firstMatch
        XCTAssertTrue(recent.waitForExistence(timeout: 5))
        let id = recent.identifier.replacingOccurrences(of: "home.recentShift.", with: "")
        attachScreenshot(named: "SL547-en-populated", from: app)
        shortcut.tap()
        XCTAssertTrue(app.tabBars.buttons["Shifts"].isSelected)
        XCTAssertTrue(app.buttons["overview.shift.\(id)"].exists)
        app.tabBars.buttons["Home"].tap()
        recent.tap()
        XCTAssertTrue(app.scrollViews["editShift.screen"].waitForExistence(timeout: 5))
        app.terminate()

        for size in ["L", "AccessibilityXXXL"] {
            let ru = launchRussianTabs(size: size)
            let scroll = ru.scrollViews["overview.pageScroll"]
            let tabBar = ru.tabBars.firstMatch
            XCTAssertTrue(ru.buttons["home.recentShift.\(id)"].waitForExistence(timeout: 10))
            attachScreenshot(named: "SL547-ru-\(size)-home", from: ru)
            let add = ru.buttons["overview.addShift"]
            let check = ru.buttons["overview.checkPaycheck"]
            for _ in 0..<8 where !add.isHittable || add.frame.maxY > tabBar.frame.minY { scroll.swipeUp() }
            XCTAssertTrue(add.isHittable)
            XCTAssertLessThanOrEqual(add.frame.maxY, tabBar.frame.minY + 1)
            attachScreenshot(named: "SL547-ru-\(size)-actions", from: ru)
            add.tap()
            XCTAssertTrue(ru.scrollViews["addShift.screen"].waitForExistence(timeout: 5))
            ru.navigationBars.buttons.firstMatch.tap()
            for _ in 0..<8 where !check.isHittable || check.frame.maxY > tabBar.frame.minY { scroll.swipeUp() }
            XCTAssertTrue(check.isHittable)
            XCTAssertLessThanOrEqual(check.frame.maxY, tabBar.frame.minY + 1)
            check.tap()
            XCTAssertTrue(ru.otherElements["actualGrossEntry.screen"].waitForExistence(timeout: 5))
            ru.terminate()
        }
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

        let selectedShiftIdentifier = try firstShiftCardIdentifier(in: relaunchedApp)
        try verifyPaycheckResult(in: relaunchedApp)
        XCTAssertTrue(relaunchedApp.buttons[homeCardID(for: selectedShiftIdentifier)].exists)
        try openFullShiftHistory(in: relaunchedApp)

        let editedCardIdentifier = try editOneShift(
            cardIdentifier: selectedShiftIdentifier,
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

        let editedCard = try requireElement(
            relaunchedApp.buttons[editedCardIdentifier],
            message: "Edited Shift must preserve its persisted identifier"
        )

        let editedLabel = normalizedWhitespace(editedCard.label)

        try requireCondition(
            editedCard.isSelected,
            message: "Edited Shift must remain selected after saving"
        )

        try requireCondition(
            String(describing: editedCard.value).contains("Collapsed"),
            message: "Edited Shift must return collapsed after saving"
        )

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

        selectHome(in: relaunchedApp)
        try assertShiftCount(
            2,
            expectedHeroAmount: "2.01",
            in: relaunchedApp
        )

        try openFullShiftHistory(in: relaunchedApp)
        let deletedIdentifier =
            try deleteShiftWithCancellationThenConfirmation(
                cardIdentifier: editedCardIdentifier,
                in: relaunchedApp
            )

        XCTAssertFalse(relaunchedApp.buttons[deletedIdentifier].exists)
        selectHome(in: relaunchedApp)
        try assertShiftCount(
            1,
            expectedHeroAmount: "1.00",
            in: relaunchedApp
        )

        try assertButtonDoesNotExist(
            identifier: homeCardID(for: deletedIdentifier),
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
            identifier: homeCardID(for: deletedIdentifier),
            in: finalRelaunch,
            message: "Deleted Shift must not return after relaunch"
        )

        attachScreenshot(
            named: "08-overview-after-delete-relaunch",
            from: finalRelaunch
        )

        finalRelaunch.terminate()
    }

    // MARK: - SL-507

    @MainActor
    func testReceiptPerShiftSelectionKeepsPayrollContext() throws {
        let app = makeApplication(resetStore: true)
        app.launch()
        defer { app.terminate() }
        try completeFixedPerShiftOnboarding(in: app, scheduledPayroll: false)
        _ = try requireElement(app.staticTexts["overview.navigation.brand"], message: "Empty PerShift must retain navigation branding")
        _ = try requireElement(app.staticTexts["home.latestShifts.empty"], message: "Empty PerShift must explain how to begin")
        XCTAssertFalse(app.buttons["overview.checkPaycheck"].isEnabled)
        attachScreenshot(named: "SL511-final-empty-per-shift-receipt", from: app)
        try addShift(
            start: ShiftTime(hour: 8, minute: 0, meridiem: "AM"),
            end: ShiftTime(hour: 9, minute: 0, meridiem: "AM"), in: app
        )
        let olderID = try firstShiftCardIdentifier(in: app)
        let period = try requireElement(
            app.staticTexts["overview.receipt.perShiftPeriod"],
            message: "PerShift receipt must describe its selected Shift"
        )
        let olderPeriod = period.label
        try addShift(
            start: ShiftTime(hour: 10, minute: 0, meridiem: "AM"),
            end: ShiftTime(hour: 11, minute: 0, meridiem: "AM"), in: app
        )
        try assertShiftCount(2, expectedHeroAmount: "1.00", in: app)
        XCTAssertEqual(normalizedWhitespace(app.staticTexts["overview.expectedGross.amount"].label),
                       "Expected gross · EUR, 1.00")
        let identities = Set(homeRecentCards(in: app).map { ledgerCardID(for: $0.identifier) })
        XCTAssertEqual(identities.count, 2)
        XCTAssertTrue(identities.contains(olderID))
        let newIdentities = identities.subtracting([olderID])
        XCTAssertEqual(newIdentities.count, 1)
        let newerID = try XCTUnwrap(newIdentities.first)
        XCTAssertTrue(app.buttons[homeCardID(for: newerID)].exists)
        XCTAssertNotEqual(period.label, olderPeriod)
        XCTAssertFalse(app.scrollViews["overview.period.rail"].isHittable)
        _ = try scrollToHittable(
            requerying: { app.staticTexts["overview.receipt.perShiftPeriod"] },
            in: app, direction: .towardBottom, message: "PerShift receipt heading must be reachable"
        )
        attachScreenshot(named: "SL511-receipt-per-shift-two-records", from: app)
        let picker = try scrollToHittable(
            requerying: { app.buttons["home.calculation.chooseShift"] },
            in: app, direction: .towardBottom, message: "PerShift calculation picker must be reachable"
        )
        picker.tap()
        let olderChoice = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "8:00")).firstMatch
        XCTAssertTrue(olderChoice.waitForExistence(timeout: 5))
        olderChoice.tap()
        let selectedPeriod = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", olderPeriod), object: period
        )
        XCTAssertEqual(XCTWaiter().wait(for: [selectedPeriod], timeout: 5), .completed)
        XCTAssertEqual(normalizedWhitespace(app.staticTexts["overview.expectedGross.amount"].label),
                       "Expected gross · EUR, 1.00")
        let check = try scrollToHittable(
            requerying: { app.buttons["overview.checkPaycheck"] },
            in: app, direction: .towardTop, message: "Check Paycheck must be reachable after selecting an older Shift"
        )
        check.tap()
        XCTAssertTrue(app.otherElements["actualGrossEntry.screen"].waitForExistence(timeout: 5))
        XCTAssertEqual(normalizedWhitespace(app.staticTexts["actualGrossEntry.period"].label),
                       normalizedWhitespace(olderPeriod))
        app.navigationBars.buttons.firstMatch.tap()
        try openFullShiftHistory(in: app)
        let olderRow = try scrollToHittable(
            requerying: { app.buttons[olderID] }, in: app, direction: .towardBottom,
            message: "Older Shift must be reachable in full history"
        )
        olderRow.tap()
        let expanded = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Expanded"), object: app.buttons[olderID]
        )
        XCTAssertEqual(XCTWaiter().wait(for: [expanded], timeout: 5), .completed)
        XCTAssertTrue(app.buttons[olderID].label.contains("Rate: €1.004 / shift"))
        XCTAssertTrue(app.buttons[olderID].label.contains("Exact contribution: €1.004"))
        XCTAssertEqual(app.buttons[olderID].label.components(separatedBy: "Paid time:").count, 2)
        XCTAssertEqual(Set(shiftCards(in: app).map(\.identifier)), identities)
        attachScreenshot(named: "SL511-receipt-per-shift-historical-expanded", from: app)
        let expandedHeight = app.buttons[olderID].frame.height
        app.buttons[olderID].tap()
        let collapsed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "selected == YES AND value == %@", "Collapsed"),
            object: app.buttons[olderID]
        )
        XCTAssertEqual(XCTWaiter().wait(for: [collapsed], timeout: 5), .completed)
        XCTAssertLessThan(app.buttons[olderID].frame.height, expandedHeight)
        XCTAssertEqual(Set(shiftCards(in: app).map(\.identifier)), identities)
        selectHome(in: app)
        XCTAssertEqual(period.label, olderPeriod)
        _ = try scrollToHittable(
            requerying: { app.staticTexts["overview.receipt.perShiftPeriod"] },
            in: app, direction: .towardBottom, message: "Collapsed receipt must resize and remain scrollable"
        )
        attachScreenshot(named: "SL511-receipt-per-shift-historical-collapsed", from: app)
        let identitiesEvidence = XCTAttachment(string:
            "Older: \(olderID), \(olderPeriod)\nNewer: \(newerID)\nExpected gross for either selected Shift: EUR 1.00; exact contribution 1.004")
        identitiesEvidence.name = "SL511-PerShift-persisted-identities"
        identitiesEvidence.lifetime = .keepAlways
        add(identitiesEvidence)
    }

    @MainActor
    func testReceiptAccessibilityHistoryAndActionsRemainReachable() throws {
        var app = makeApplication(resetStore: true)
        app.launch()
        defer { app.terminate() }
        try completeFixedPerShiftOnboarding(in: app)
        try addShift(
            start: ShiftTime(hour: 8, minute: 0, meridiem: "AM"),
            end: ShiftTime(hour: 9, minute: 0, meridiem: "AM"),
            in: app
        )
        let persistedID = try firstShiftCardIdentifier(in: app)
        app.terminate()
        app = makeApplication()
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXL"
        ]
        app.launch()
        try assertShiftCount(1, expectedHeroAmount: "1.00", in: app)
        _ = try scrollToHittable(
            requerying: { app.staticTexts["overview.period.label"] },
            in: app, direction: .towardBottom,
            message: "Accessibility receipt heading must remain readable"
        )
        attachScreenshot(named: "SL511-receipt-accessibility-xxl-top", from: app)
        try openFullShiftHistory(in: app)
        let row = try scrollToHittable(
            requerying: { app.buttons[persistedID] },
            in: app, direction: .towardBottom,
            message: "Accessibility receipt history must remain reachable"
        )
        row.tap()
        let selected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "selected == YES"),
            object: app.buttons[persistedID]
        )
        XCTAssertEqual(XCTWaiter().wait(for: [selected], timeout: 5), .completed)
        let expanded = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "selected == YES AND value == %@", "Expanded"),
            object: app.buttons[persistedID]
        )
        XCTAssertEqual(XCTWaiter().wait(for: [expanded], timeout: 5), .completed)
        _ = try scrollToHittable(
            requerying: { app.buttons[persistedID] },
            in: app, direction: .towardBottom,
            message: "Expanded accessibility receipt record must stay reachable"
        )
        XCTAssertTrue(app.buttons[persistedID].label.contains("Rate: €1.004 / shift"))
        XCTAssertTrue(app.buttons[persistedID].label.contains("Exact contribution: €1.004"))
        XCTAssertEqual(app.buttons[persistedID].label.components(separatedBy: "Paid time:").count, 2)
        attachScreenshot(named: "SL511-receipt-accessibility-xxl-history", from: app)
        XCTAssertEqual(shiftCards(in: app).map(\.identifier), [persistedID])
        selectHome(in: app)
        for identifier in ["overview.checkPaycheck", "overview.addShift"] {
            let button = try scrollToHittable(
                requerying: { app.buttons[identifier] },
                in: app, direction: .towardBottom,
                message: "Receipt action \(identifier) must remain reachable at Accessibility XXL"
            )
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
        }
        XCTAssertEqual(homeRecentCards(in: app).map(\.identifier), [homeCardID(for: persistedID)])
        attachScreenshot(named: "SL511-receipt-accessibility-xxl-actions", from: app)

        // Same persisted record, no reset: inspect the longer Russian receipt labels too.
        app.terminate()
        app = makeApplication()
        app.launchArguments = app.launchArguments.map { argument in
            switch argument {
            case "(en)": "(ru)"
            case "en_US": "ru_RU"
            default: argument
            }
        }
        app.launch()
        _ = try scrollToHittable(
            requerying: { app.scrollViews["overview.period.rail"] },
            in: app, direction: .towardBottom, message: "Russian receipt heading must be reachable"
        )
        attachScreenshot(named: "SL511-refinement-russian-top", from: app)
        try openFullShiftHistory(in: app)
        let russianRow = try scrollToHittable(
            requerying: { app.buttons[persistedID] }, in: app, direction: .towardBottom,
            message: "Same persisted Shift must remain selectable in Russian"
        )
        russianRow.tap()
        let expandedRussian = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Развернута"), object: app.buttons[persistedID])
        XCTAssertEqual(XCTWaiter().wait(for: [expandedRussian], timeout: 5), .completed)
        XCTAssertTrue(normalizedWhitespace(app.buttons[persistedID].label).contains("Точный вклад: 1,004 €"))
        attachScreenshot(named: "SL511-refinement-russian-expanded", from: app)

        app.terminate()
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXL"
        ]
        app.launch()
        _ = try scrollToHittable(
            requerying: { app.staticTexts["overview.period.label"] }, in: app,
            direction: .towardTop, message: "Russian XXL receipt heading must be reachable"
        )
        attachScreenshot(named: "SL511-final-russian-xxl-top", from: app)
        try openFullShiftHistory(in: app)
        let russianAccessibilityRow = try scrollToHittable(
            requerying: { app.buttons[persistedID] }, in: app, direction: .towardBottom,
            message: "Russian XXL persisted Shift must remain selectable"
        )
        russianAccessibilityRow.tap()
        let russianAccessibilitySelected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "selected == YES"), object: app.buttons[persistedID])
        XCTAssertEqual(XCTWaiter().wait(for: [russianAccessibilitySelected], timeout: 5), .completed)
        let russianAccessibilityExpanded = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Развернута"), object: app.buttons[persistedID])
        XCTAssertEqual(XCTWaiter().wait(for: [russianAccessibilityExpanded], timeout: 5), .completed)
        XCTAssertTrue(normalizedWhitespace(app.buttons[persistedID].label).contains("Точный вклад: 1,004 €"))
        attachScreenshot(named: "SL511-final-russian-xxl-details", from: app)
        selectHome(in: app)
        _ = try scrollToHittable(
            requerying: { app.buttons["overview.addShift"] }, in: app, direction: .towardBottom,
            message: "Russian XXL actions must remain reachable"
        )
        attachScreenshot(named: "SL511-final-russian-xxl-actions", from: app)
    }

    @MainActor
    func testShiftsSwitchExpandedCardsWithOneTap() throws {
        let app = makeApplication(resetStore: true)
        app.launch()
        try completeFixedPerShiftOnboarding(in: app)

        for hour in [8, 9, 10] {
            try addShift(
                start: ShiftTime(hour: hour, minute: 0, meridiem: "AM"),
                end: ShiftTime(hour: hour + 1, minute: 0, meridiem: "AM"),
                in: app
            )
        }

        try openFullShiftHistory(in: app)
        let identifiers = shiftCards(in: app).map(\.identifier)
        XCTAssertEqual(identifiers.count, 3)
        guard identifiers.count == 3 else { return }

        for (index, shouldExpand) in [(0, true), (1, true), (2, true), (2, false), (2, true)] {
            let id = identifiers[index]
            let card = try scrollToHittable(
                requerying: { app.buttons[id] }, in: app, direction: .towardBottom,
                message: "Shift \(id) must be reachable"
            )
            card.tap()
            let current = app.buttons[id]
            XCTAssertTrue(current.isSelected)
            XCTAssertEqual(current.value as? String, shouldExpand ? "Expanded" : "Collapsed")

            for otherID in identifiers where otherID != id {
                XCTAssertEqual(app.buttons[otherID].value as? String, "Collapsed")
            }
            if shouldExpand {
                let startHour = 10 - index
                XCTAssertTrue(current.label.contains("\(startHour):00"))
                XCTAssertTrue(current.label.contains("Exact contribution: €1.004"))
                XCTAssertTrue(app.buttons[id + ".edit"].exists)
                attachScreenshot(named: "SL556-expanded-card-\(index + 1)", from: app)
            }
        }
    }

    @MainActor
    func testLedgerTwelvePersistedShiftsRemainScrollable() throws {
        let app = makeApplication(resetStore: true)
        app.launch()
        defer { app.terminate() }
        try completeFixedPerShiftOnboarding(in: app)
        try assertShiftCount(0, expectedHeroAmount: "0.00", in: app)
        XCTAssertEqual(normalizedWhitespace(app.staticTexts["overview.expectedGross.amount"].label),
                       "Expected gross · EUR, 0.00")
        attachScreenshot(named: "SL511-final-empty-scheduled-receipt", from: app)

        var identifiersByStartTime: [String] = []
        for hour in 0..<12 {
            let startHour = hour == 0 ? 12 : hour
            let endHour = hour + 1
            try addShift(
                start: ShiftTime(hour: startHour, minute: 0, meridiem: "AM"),
                end: ShiftTime(hour: endHour, minute: 0, meridiem: endHour == 12 ? "PM" : "AM"),
                in: app
            )
            let currentIdentifiers = Set(homeRecentCards(in: app).map { ledgerCardID(for: $0.identifier) })
            let newlyPersisted = currentIdentifiers.subtracting(identifiersByStartTime)
            XCTAssertEqual(newlyPersisted.count, 1)
            identifiersByStartTime.append(try XCTUnwrap(newlyPersisted.first))
        }

        XCTAssertEqual(homeRecentCards(in: app).map { ledgerCardID(for: $0.identifier) },
                       Array(identifiersByStartTime.reversed().prefix(4)))
        try openFullShiftHistory(in: app)
        let cards = shiftCards(in: app)
        XCTAssertEqual(cards.count, 12)
        let identifiers = cards.map(\.identifier)
        XCTAssertEqual(Set(identifiers).count, 12)
        XCTAssertEqual(identifiers, Array(identifiersByStartTime.reversed()))
        selectHome(in: app)
        let hero = try requireElement(
            app.staticTexts["overview.expectedGross.amount"],
            message: "Twelve one-euro-and-fraction Shifts must have a period Expected Gross"
        )
        XCTAssertEqual(normalizedWhitespace(hero.label), "Expected gross · EUR, 12.05")
        let precision = try requireElement(
            app.staticTexts["overview.receipt.precision"],
            message: "Receipt must explain the exact period amount behind rounded Shift lines"
        )
        XCTAssertEqual(precision.label, "Amounts rounded for display")
        XCTAssertEqual(normalizedWhitespace(app.otherElements["overview.receipt.precision.exactField"].label), "Exact total, €12.048")
        XCTAssertEqual(normalizedWhitespace(app.otherElements["overview.receipt.precision.displayedField"].label), "Displayed, €12.05")
        let pageScroll = try requireElement(app.scrollViews["overview.pageScroll"],
                                            message: "Home page must be scrollable")
        _ = try scrollToHittable(
            requerying: { app.scrollViews["overview.period.rail"] },
            in: app,
            direction: .towardBottom,
            scrollView: pageScroll,
            message: "Receipt period selection must be reachable"
        )
        for identifier in ["overview.receipt.precision.exactField",
                           "overview.receipt.precision.displayedField",
                           "overview.receipt.precision"] {
            _ = try scrollToHittable(
                requerying: { app.descendants(matching: .any)[identifier] },
                in: app,
                direction: .towardBottom,
                scrollView: pageScroll,
                message: "Receipt field \(identifier) must be reachable"
            )
        }
        attachScreenshot(named: "SL511-receipt-12-shifts-precision", from: app)

        try openFullShiftHistory(in: app)
        let bottomRecordID = try XCTUnwrap(identifiers.last)
        let bottomRecord = try scrollToHittable(
            requerying: { app.buttons[bottomRecordID] },
            in: app,
            direction: .towardBottom,
            message: "Last of twelve persisted ledger records must be reachable"
        )
        bottomRecord.tap()
        let selected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "selected == YES"),
            object: app.buttons[bottomRecordID]
        )
        XCTAssertEqual(XCTWaiter().wait(for: [selected], timeout: 5), .completed)
        let expanded = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Expanded"),
            object: app.buttons[bottomRecordID]
        )
        XCTAssertEqual(XCTWaiter().wait(for: [expanded], timeout: 5), .completed)
        attachScreenshot(named: "SL511-receipt-12-shifts-expanded", from: app)
        selectHome(in: app)

        _ = try scrollToHittable(
            requerying: { app.buttons["overview.addShift"] },
            in: app,
            direction: .towardBottom,
            message: "Add Shift must remain reachable below twelve records"
        )
        attachScreenshot(named: "SL511-receipt-12-shifts-bottom", from: app)
        _ = try scrollToHittable(
            requerying: { app.buttons["overview.checkPaycheck"] },
            in: app,
            direction: .towardBottom,
            message: "Check Paycheck must remain reachable below the receipt"
        )
        try openFullShiftHistory(in: app)
        XCTAssertEqual(Set(shiftCards(in: app).map(\.identifier)), Set(identifiers))

        let expandedRecord = try scrollToHittable(
            requerying: { app.buttons[bottomRecordID] },
            in: app,
            direction: .towardBottom,
            message: "Expanded last record must remain reachable for Edit"
        )
        XCTAssertEqual(expandedRecord.value as? String, "Expanded")
        try openEdit(forCardIdentifier: bottomRecordID, in: app)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        let oldestStart = calendar.startOfDay(for: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = calendar
        dateFormatter.timeZone = calendar.timeZone
        dateFormatter.dateFormat = "MMMM d, yyyy 'at' h:mm a"
        for (identifier, date) in [
            ("editShift.start", oldestStart),
            ("editShift.end", oldestStart.addingTimeInterval(3600))
        ] {
            let endpoint = try requireElement(app.buttons[identifier], message: "Edit must expose the oldest Shift's endpoint")
            XCTAssertEqual(normalizedWhitespace(try XCTUnwrap(endpoint.value as? String)),
                           normalizedWhitespace(dateFormatter.string(from: date)))
        }
        attachScreenshot(named: "SL511-final-edit-oldest-shift", from: app)
        let back = app.navigationBars.buttons.element(boundBy: 0)
        _ = try requireHittable(back, message: "Edit Back must remain usable")
        back.tap()
        try assertShiftsExists(in: app)
        XCTAssertEqual(Set(shiftCards(in: app).map(\.identifier)), Set(identifiers))
        XCTAssertTrue(app.buttons[bottomRecordID].isSelected)
        XCTAssertEqual(app.buttons[bottomRecordID].value as? String, "Expanded")

        app.terminate()
        let accessibilityApp = makeApplication()
        accessibilityApp.launchArguments += [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXL"
        ]
        accessibilityApp.launch()
        defer { accessibilityApp.terminate() }
        try assertShiftCount(12, expectedHeroAmount: "12.05", in: accessibilityApp)
        XCTAssertEqual(normalizedWhitespace(accessibilityApp.staticTexts["overview.expectedGross.amount"].label), "Expected gross · EUR, 12.05")
        try openFullShiftHistory(in: accessibilityApp)
        XCTAssertEqual(Set(shiftCards(in: accessibilityApp).map(\.identifier)), Set(identifiers))
        selectHome(in: accessibilityApp)
        _ = try scrollToHittable(
            requerying: { accessibilityApp.staticTexts["overview.period.label"] },
            in: accessibilityApp, direction: .towardBottom,
            message: "Twelve-Shift receipt heading must remain reachable at Accessibility XXL"
        )
        attachScreenshot(named: "SL511-refinement-12-xxl-top", from: accessibilityApp)
        _ = try scrollToHittable(
            requerying: { accessibilityApp.staticTexts["overview.receipt.precision"] },
            in: accessibilityApp, direction: .towardBottom,
            message: "Precision fields and rounding note must remain reachable at Accessibility XXL"
        )
        XCTAssertEqual(normalizedWhitespace(accessibilityApp.otherElements["overview.receipt.precision.exactField"].label), "Exact total, €12.048")
        XCTAssertEqual(normalizedWhitespace(accessibilityApp.otherElements["overview.receipt.precision.displayedField"].label), "Displayed, €12.05")
        attachScreenshot(named: "SL511-refinement-12-xxl-precision", from: accessibilityApp)
    }

    @MainActor
    func testScheduledPayrollKeepsGlobalShiftHistoryAcrossMonths() throws {
        var app = makeApplication(resetStore: true)
        app.launch()
        defer { app.terminate() }
        try completeFixedPerShiftOnboarding(in: app)
        try assertOverviewExists(in: app)

        var calendar = Calendar(identifier: .gregorian)
        // Job setup stores the application's autoupdating current time zone.
        // Match it so the selected local dates stay inside their intended months.
        calendar.timeZone = .autoupdatingCurrent
        let currencyFormatter = NumberFormatter()
        currencyFormatter.locale = Locale(identifier: "en_US")
        currencyFormatter.numberStyle = .currency
        currencyFormatter.currencyCode = "EUR"
        currencyFormatter.minimumFractionDigits = 2
        currencyFormatter.maximumFractionDigits = 2
        let expectedCardContribution = try XCTUnwrap(
            currencyFormatter.string(from: NSDecimalNumber(decimal: 1.004))
        )
        let expectedEmptyPaycheckAmount = try XCTUnwrap(
            currencyFormatter.string(from: NSDecimalNumber(decimal: .zero))
        )
        let newerMonth = try XCTUnwrap(calendar.dateInterval(of: .month, for: Date())?.start)
        let emptyMonth = try XCTUnwrap(calendar.date(byAdding: .month, value: -1, to: newerMonth))
        let olderMonth = try XCTUnwrap(calendar.date(byAdding: .month, value: -2, to: newerMonth))
        let olderDay = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: emptyMonth))
        let olderStart = try XCTUnwrap(calendar.date(bySettingHour: 8, minute: 0, second: 0, of: olderDay))
        let newerStart = try XCTUnwrap(calendar.date(bySettingHour: 8, minute: 0, second: 0, of: newerMonth))
        try addCalendarShift(start: olderStart, calendar: calendar, in: app)
        try assertShiftCount(1, expectedHeroAmount: "1.00", in: app)
        let olderID = try firstShiftCardIdentifier(in: app)
        try requireCondition(UUID(uuidString: String(olderID.dropFirst("overview.shift.".count))) != nil,
                             message: "Historical Shift must expose its persisted UUID")

        try addCalendarShift(start: newerStart, calendar: calendar, in: app)
        try assertShiftCount(2, expectedHeroAmount: "1.00", in: app)
        let newerID = try XCTUnwrap(homeRecentCards(in: app).map { ledgerCardID(for: $0.identifier) }.first { $0 != olderID })
        try requireCondition(UUID(uuidString: String(newerID.dropFirst("overview.shift.".count))) != nil,
                             message: "Newer Shift must expose a distinct persisted UUID")
        let identities = Set([olderID, newerID])
        try requireCondition(homeRecentCards(in: app).first?.identifier == homeCardID(for: newerID), message: "Post-save reload must show the newest Shift first")

        app.terminate()
        app = makeApplication()
        app.launch()
        try assertOverviewExists(in: app)
        try assertGlobalHistory(
            month: newerMonth,
            amount: "1.00",
            expectedCardContribution: expectedCardContribution,
            identities: identities,
            in: app
        )
        let newestCard = try scrollToHittable(
            requerying: { app.buttons[homeCardID(for: newerID)] },
            in: app,
            direction: .towardBottom,
            message: "Newest persisted Shift must remain reachable after relaunch"
        )
        try requireCondition(
            normalizedWhitespace(newestCard.label).contains(
                "Expected: \(expectedCardContribution)"
            ),
            message: "Newest card accessibility summary must include its exact contribution; observed \(newestCard.label)"
        )
        attachScreenshot(named: "SL507-01-populated-current-period", from: app)

        try navigatePayroll(identifier: "overview.period.previous", in: app)
        try assertGlobalHistory(
            month: emptyMonth,
            amount: "0.00",
            expectedCardContribution: expectedCardContribution,
            identities: identities,
            in: app
        )
        try requireCondition(!app.staticTexts["overview.shiftHistory.empty"].exists,
                             message: "An empty payroll month must not show empty persisted history")
        attachScreenshot(named: "SL507-03-empty-period-global-history", from: app)
        try navigatePayroll(identifier: "overview.period.previous", in: app)
        try assertGlobalHistory(
            month: olderMonth,
            amount: "1.00",
            expectedCardContribution: expectedCardContribution,
            identities: identities,
            in: app
        )
        attachScreenshot(named: "SL507-02-populated-historical-period", from: app)

        try navigatePayroll(identifier: "overview.period.next", in: app)
        try navigatePayroll(identifier: "overview.period.next", in: app)
        try assertGlobalHistory(
            month: newerMonth,
            amount: "1.00",
            expectedCardContribution: expectedCardContribution,
            identities: identities,
            in: app
        )
        try openFullShiftHistory(in: app)
        let olderCard = try scrollToHittable(requerying: { app.buttons[olderID] }, in: app,
                                            direction: .towardBottom, message: "Historical card header must be tappable")
        olderCard.tap()
        let selectedExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "selected == YES"),
            object: app.buttons[olderID]
        )
        try requireCondition(
            XCTWaiter().wait(for: [selectedExpectation], timeout: 5) == .completed,
            message: "Historical UUID must become selected"
        )
        let selectedCard = try scrollToHittable(
            requerying: { app.buttons[olderID] },
            in: app,
            direction: .towardBottom,
            message: "Selected historical Shift must remain reachable"
        )
        try requireCondition(
            normalizedWhitespace(selectedCard.label).contains(
                "Expected: \(expectedCardContribution)"
            ),
            message: "Selected card accessibility summary must retain its exact contribution; observed \(selectedCard.label)"
        )
        try assertGlobalHistory(
            month: newerMonth,
            amount: "1.00",
            expectedCardContribution: expectedCardContribution,
            identities: identities,
            in: app
        )
        try openFullShiftHistory(in: app)
        let expandedExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Expanded"),
            object: app.buttons[olderID]
        )
        try requireCondition(
            XCTWaiter().wait(for: [expandedExpectation], timeout: 5) == .completed,
            message: "Historical card must expand"
        )
        selectHome(in: app)
        try navigatePayroll(identifier: "overview.period.previous", in: app)
        try assertGlobalHistory(
            month: emptyMonth,
            amount: "0.00",
            expectedCardContribution: expectedCardContribution,
            identities: identities,
            in: app
        )
        try openFullShiftHistory(in: app)
        let preservedExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "selected == YES AND value == %@", "Expanded"),
            object: app.buttons[olderID]
        )
        try requireCondition(
            XCTWaiter().wait(for: [preservedExpectation], timeout: 5) == .completed,
            message: "Empty-month navigation must retain the selected expanded UUID"
        )
        _ = try scrollToHittable(requerying: { app.buttons[olderID] }, in: app,
                                direction: .towardBottom, message: "Expanded historical card must remain visible")
        attachScreenshot(named: "SL507-04-cross-period-selected-expanded", from: app)

        selectHome(in: app)
        let check = try scrollToHittable(requerying: { app.buttons["overview.checkPaycheck"] }, in: app,
                                        direction: .towardBottom, message: "Check Paycheck must be reachable")
        check.tap()
        _ = try requireElement(app.otherElements["actualGrossEntry.screen"], message: "Actual Gross entry must appear")
        let input = try scrollToHittable(requerying: { app.textFields["actualGrossEntry.amount.input"] }, in: app,
                                        direction: .towardBottom, message: "Actual Gross input must be reachable")
        input.tap()
        input.typeText("1.00")
        let compare = try scrollToHittable(requerying: { app.buttons["actualGrossEntry.compare"] }, in: app,
                                          direction: .towardBottom, message: "Compare must be reachable")
        compare.tap()
        _ = try requireElement(app.otherElements["paycheckResult.screen"], message: "Paycheck Result must appear")
        let paycheckExpected = try requireElement(
            app.staticTexts["paycheckResult.expected.value"],
            message: "Paycheck must use the empty selected payroll month"
        )
        try requireCondition(
            normalizedWhitespace(paycheckExpected.label) == normalizedWhitespace(expectedEmptyPaycheckAmount),
            message: "Paycheck Expected must be exactly \(expectedEmptyPaycheckAmount); observed \(paycheckExpected.label)"
        )
        try requireCondition(breakdownAmountElements(in: app).isEmpty, message: "Empty selected month must produce no paycheck contributions")
        attachScreenshot(named: "SL507-05-empty-period-paycheck-result", from: app)
        let done = try scrollToHittable(requerying: { app.buttons["paycheckResult.done"] }, in: app,
                                       direction: .towardBottom, message: "Result Done must be reachable")
        done.tap()
        try assertOverviewExists(in: app)
        try assertGlobalHistory(
            month: emptyMonth,
            amount: "0.00",
            expectedCardContribution: expectedCardContribution,
            identities: identities,
            in: app
        )
        try navigatePayroll(identifier: "overview.period.previous", in: app)
        try assertGlobalHistory(
            month: olderMonth,
            amount: "1.00",
            expectedCardContribution: expectedCardContribution,
            identities: identities,
            in: app
        )
        try openFullShiftHistory(in: app)
        let historicalPreservationExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "selected == YES AND value == %@", "Expanded"),
            object: app.buttons[olderID]
        )
        try requireCondition(
            XCTWaiter().wait(for: [historicalPreservationExpectation], timeout: 5) == .completed,
            message: "Historical-period navigation must preserve expanded UUID"
        )
        let evidence = XCTAttachment(string: "Newer: \(newerID), \(newerStart)\nOlder: \(olderID), \(olderStart)\nEmpty month: \(emptyMonth)\nBoth populated months: EUR 1.00 (exact rate 1.004); empty month: EUR 0.00")
        evidence.name = "SL507-persisted-identities-and-periods"
        evidence.lifetime = .keepAlways
        add(evidence)
    }

    @MainActor
    private func addCalendarShift(start: Date, calendar: Calendar, in app: XCUIApplication) throws {
        let add = try scrollToHittable(requerying: { app.buttons["overview.addShift"] }, in: app,
                                      direction: .towardBottom, message: "Add Shift must be reachable")
        add.tap()
        _ = try requireElement(app.scrollViews["addShift.screen"], message: "Add Shift screen must appear")
        try selectCalendarDate(start, rowIdentifier: "addShift.start", calendar: calendar, in: app)
        try selectCalendarDate(start.addingTimeInterval(60 * 60), rowIdentifier: "addShift.end", calendar: calendar, in: app)
        let save = try requireElement(app.navigationBars.buttons["Save"], message: "Save must exist")
        _ = try requireHittable(save, message: "Save must be reachable")
        try requireCondition(save.isEnabled, message: "Selected dates must form a valid Shift")
        save.tap()
        try assertOverviewExists(in: app)
    }

    @MainActor
    private func selectCalendarDate(_ date: Date, rowIdentifier: String, calendar: Calendar, in app: XCUIApplication) throws {
        let row = try scrollToHittable(requerying: { app.buttons[rowIdentifier] }, in: app,
                                      direction: .towardBottom, message: "Date row must be reachable")
        row.tap()
        let picker = try requireElement(app.datePickers.firstMatch, message: "Real UIDatePicker must appear")
        let wheels = picker.pickerWheels.allElementsBoundByIndex
        try requireCondition(wheels.count == 4, message: "Expected date/hour/minute/meridiem wheels: \(picker.debugDescription)")
        let targetDay = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        var observations: [String] = []
        func readDay(near context: Date) throws -> Date {
            let value = try XCTUnwrap(picker.pickerWheels.element(boundBy: 0).value as? String)
            observations.append(value)
            let relative = normalizedWhitespace(value).lowercased()
            if relative == "today" { return today }
            if relative == "tomorrow" { return try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: today)) }
            if relative == "yesterday" { return try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: today)) }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US")
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.isLenient = false
            var candidates = Set<Date>()
            for year in (calendar.component(.year, from: context) - 1)...(calendar.component(.year, from: context) + 1) {
                formatter.defaultDate = try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: 1, day: 1)))
                for format in ["EEE, MMM d", "EEE MMM d", "EEEE, MMMM d", "MMM d", "MMMM d",
                               "EEE, MMM d, yyyy", "EEE MMM d yyyy", "EEEE, MMMM d, yyyy"] {
                    formatter.dateFormat = format
                    if let parsed = formatter.date(from: value),
                       normalizedWhitespace(formatter.string(from: parsed)) == normalizedWhitespace(value) {
                        candidates.insert(calendar.startOfDay(for: parsed))
                    }
                }
            }
            let ordered = candidates.sorted { abs($0.timeIntervalSince(context)) < abs($1.timeIntervalSince(context)) }
            let resolved = try XCTUnwrap(ordered.first, "Unrecognized date wheel: \(observations); requested \(date); \(picker.debugDescription)")
            try requireCondition(
                abs(resolved.timeIntervalSince(context)) < 183 * 24 * 60 * 60,
                message: "Ambiguous wheel year: \(observations); context \(context); requested \(date)"
            )
            return resolved
        }
        var selectedDay = try readDay(near: today)
        let initialFrame = picker.pickerWheels.element(boundBy: 0).frame
        try requireCondition(initialFrame.height > 0, message: "Date wheel needs a visible frame: \(initialFrame)")
        // A 24-point offset did not advance this wheel on the tested iOS 26 runtime.
        // Tap farther into the adjacent row, then measure its calendar direction.
        let rowOffset = 36 / initialFrame.height
        func changedDay(from oldValue: String) throws -> Date? {
            let changed = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value != %@", oldValue),
                object: picker.pickerWheels.element(boundBy: 0)
            )
            guard XCTWaiter().wait(for: [changed], timeout: 3) == .completed else {
                return nil
            }
            return try readDay(near: selectedDay)
        }
        func waitForDayChange(from oldValue: String) throws -> Date {
            try XCTUnwrap(
                try changedDay(from: oldValue),
                "Date wheel stopped moving: \(observations); target \(date); \(picker.debugDescription)"
            )
        }
        // A row tap establishes the exact one-day direction. Larger drag gestures are
        // calibrated from their observed result instead of assuming a fixed day count.
        var rowTapDelta: Int?
        var increasingRowDirection: CGFloat?
        if selectedDay != targetDay {
            let wheel = picker.pickerWheels.element(boundBy: 0)
            for screenDirection: CGFloat in [1, -1] {
                let oldValue = try XCTUnwrap(wheel.value as? String)
                wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5 + screenDirection * rowOffset)).tap()
                guard let nextDay = try changedDay(from: oldValue) else {
                    observations.append("No change after row calibration \(screenDirection)")
                    continue
                }
                let rowDelta = calendar.dateComponents([.day], from: selectedDay, to: nextDay).day ?? 0
                if rowDelta == 0 {
                    observations.append("Calendar day unchanged after row calibration \(screenDirection)")
                    continue
                }
                try requireCondition(abs(rowDelta) == 1,
                                     message: "Cannot calibrate a single calendar day. Frame \(initialFrame); values \(observations); requested \(date); \(picker.debugDescription)")
                rowTapDelta = rowDelta
                increasingRowDirection = screenDirection * CGFloat(rowDelta)
                selectedDay = nextDay
                break
            }
            let calibratedRowDelta = try XCTUnwrap(
                rowTapDelta,
                "Cannot calibrate a single calendar day. Frame \(initialFrame); values \(observations); requested \(date); \(picker.debugDescription)"
            )

            if abs(calendar.dateComponents([.day], from: selectedDay, to: targetDay).day ?? 0) > 8 {
                let probeValue = try XCTUnwrap(wheel.value as? String)
                wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    .press(forDuration: 0.2, thenDragTo: wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)))
                let probeDay = try waitForDayChange(from: probeValue)
                let probeDelta = calendar.dateComponents([.day], from: selectedDay, to: probeDay).day ?? 0
                try requireCondition(probeDelta != 0,
                                     message: "Large date drag did not move the wheel. Frame \(initialFrame); values \(observations); requested \(date); \(picker.debugDescription)")
                selectedDay = probeDay
                var dragDirection: CGFloat = probeDelta > 0 ? -1 : 1
                if (calendar.dateComponents([.day], from: selectedDay, to: targetDay).day ?? 0 > 0) != (probeDelta > 0) {
                    dragDirection *= -1
                }
                for _ in 0..<12 {
                    let remaining = calendar.dateComponents([.day], from: selectedDay, to: targetDay).day ?? 0
                    if abs(remaining) <= 8 { break }
                    let oldValue = try XCTUnwrap(wheel.value as? String)
                    let endpoint = wheel.coordinate(
                        withNormalizedOffset: CGVector(dx: 0.5, dy: dragDirection > 0 ? 0.88 : 0.12)
                    )
                    wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                        .press(forDuration: 0.2, thenDragTo: endpoint)
                    let nextDay = try waitForDayChange(from: oldValue)
                    let movement = calendar.dateComponents([.day], from: selectedDay, to: nextDay).day ?? 0
                    try requireCondition(movement != 0 && (movement > 0) == (remaining > 0),
                                         message: "Large date drag moved unexpectedly by \(movement): \(observations); target \(date); \(picker.debugDescription)")
                    selectedDay = nextDay
                }
            }
            // Retain the observed direction for exact final row taps.
            rowTapDelta = calibratedRowDelta
        }
        for _ in 0..<12 {
            if selectedDay == targetDay { break }
            let remaining = calendar.dateComponents([.day], from: selectedDay, to: targetDay).day ?? 0
            let wheel = picker.pickerWheels.element(boundBy: 0)
            let oldValue = try XCTUnwrap(wheel.value as? String)
            let increasingDirection = try XCTUnwrap(increasingRowDirection)
            let rowDirection: CGFloat = (remaining > 0 ? 1 : -1) * increasingDirection
            wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5 + rowDirection * rowOffset)).tap()
            let nextDay = try waitForDayChange(from: oldValue)
            let movement = calendar.dateComponents([.day], from: selectedDay, to: nextDay).day ?? 0
            try requireCondition(movement == (remaining > 0 ? 1 : -1),
                                 message: "Row tap moved unexpectedly by \(movement): \(observations); target \(date); \(picker.debugDescription)")
            selectedDay = nextDay
        }
        let evidence = XCTAttachment(string: "Requested \(date), timezone \(calendar.timeZone.identifier), frame \(initialFrame), values \(observations)")
        evidence.name = "SL507-date-wheel-gestures-\(rowIdentifier)"
        evidence.lifetime = .keepAlways
        add(evidence)
        try requireCondition(selectedDay == targetDay,
                             message: "Date gesture limit exceeded: \(observations); requested \(date); \(picker.debugDescription)")
        let hour = calendar.component(.hour, from: date)
        wheels[1].adjust(toPickerWheelValue: String(hour % 12 == 0 ? 12 : hour % 12))
        wheels[2].adjust(toPickerWheelValue: String(format: "%02d", calendar.component(.minute, from: date)))
        wheels[3].adjust(toPickerWheelValue: hour < 12 ? "AM" : "PM")
        let done = try requireElement(app.navigationBars.buttons["Done"], message: "Picker Done must exist")
        _ = try requireHittable(done, message: "Picker Done must be reachable")
        done.tap()
        _ = try requireElement(app.buttons[rowIdentifier], message: "Date row must return")
        let rowFormatter = DateFormatter()
        rowFormatter.locale = Locale(identifier: "en_US_POSIX")
        rowFormatter.calendar = calendar
        rowFormatter.timeZone = calendar.timeZone
        let expected = [
            "MMMM d, yyyy 'at' h:mm a",
            "d MMMM yyyy 'г.' 'at' h:mm a"
        ].map { format in
            rowFormatter.dateFormat = format
            return normalizedWhitespace(rowFormatter.string(from: date))
        }
        let actual = normalizedWhitespace(app.buttons[rowIdentifier].value as? String ?? app.buttons[rowIdentifier].label)
        let lastPickerValue = observations.last ?? "none"
        // The second rendering preserves the known mixed-locale presentation while still
        // requiring the complete requested Gregorian date and local time.
        try requireCondition(
            expected.contains(actual),
            message: "Date row must represent exactly one of \(expected); observed \(actual); requested \(date); timezone \(calendar.timeZone.identifier); last picker value \(lastPickerValue)"
        )
    }

    @MainActor
    private func assertGlobalHistory(
        month: Date,
        amount: String,
        expectedCardContribution: String,
        identities: Set<String>,
        in app: XCUIApplication
    ) throws {
        try assertShiftCount(2, expectedHeroAmount: amount, in: app)
        let hero = try requireElement(
            app.staticTexts["overview.expectedGross.amount"],
            message: "Expected Gross hero must exist"
        )
        let expectedHeroLabel = "Expected gross · EUR, \(amount)"
        let heroExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", expectedHeroLabel),
            object: hero
        )
        try requireCondition(
            XCTWaiter().wait(for: [heroExpectation], timeout: 5) == .completed,
            message: "Expected hero must exactly equal \(expectedHeroLabel); observed \(hero.label)"
        )
        try openFullShiftHistory(in: app)
        let cards = shiftCards(in: app)
        try requireCondition(Set(cards.map(\.identifier)) == identities, message: "Every persisted UUID must remain in global history")
        try requireCondition(
            cards.allSatisfy { normalizedWhitespace($0.label).contains("Expected: \(expectedCardContribution)") },
            message: "Every persisted card accessibility summary must include \(expectedCardContribution); observed \(cards.map(\.label))"
        )
        selectHome(in: app)
        _ = try scrollToHittable(
            requerying: { app.buttons["overview.period.previous"] },
            in: app,
            direction: .towardTop,
            message: "Overview period navigation must be reachable before checking its representation"
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        let railFormatter = DateFormatter()
        railFormatter.locale = Locale(identifier: "en_US")
        railFormatter.calendar = calendar
        railFormatter.timeZone = calendar.timeZone
        railFormatter.setLocalizedDateFormatFromTemplate("yMMMM")
        let expectedRailPeriod = normalizedWhitespace(railFormatter.string(from: month))
        let nextMonth = try XCTUnwrap(
            calendar.date(byAdding: .month, value: 1, to: month)
        )
        let visibleEnd = try XCTUnwrap(
            calendar.date(byAdding: .day, value: -1, to: nextMonth)
        )
        let labelFormatter = DateIntervalFormatter()
        labelFormatter.locale = Locale(identifier: "en_US")
        labelFormatter.calendar = calendar
        labelFormatter.timeZone = calendar.timeZone
        labelFormatter.dateStyle = .medium
        labelFormatter.timeStyle = .none
        let expectedAccessibilityPeriod = normalizedWhitespace(labelFormatter.string(from: month, to: visibleEnd))
        let periodLabel = app.staticTexts["overview.period.label"]
        if periodLabel.isHittable {
            let visiblePeriodLabel = try requireHittable(periodLabel, message: "Accessibility period label must be visible")
            try requireCondition(
                normalizedWhitespace(visiblePeriodLabel.label) == expectedAccessibilityPeriod,
                message: "Accessibility period label must be \(expectedAccessibilityPeriod); observed \(visiblePeriodLabel.label)"
            )
        } else {
            _ = try requireHittable(
                app.scrollViews["overview.period.rail"],
                message: "Normal-size period rail must be visible"
            )
            let selectedPeriods = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "overview.period.item.")).allElementsBoundByIndex.filter(\.isSelected)
            try requireCondition(
                selectedPeriods.contains { normalizedWhitespace($0.label) == expectedRailPeriod },
                message: "Selected normal-size payroll rail item must be \(expectedRailPeriod); observed \(selectedPeriods.map(\.label))"
            )
        }
    }

    @MainActor
    private func navigatePayroll(identifier: String, in app: XCUIApplication) throws {
        let control = try scrollToHittable(requerying: { app.buttons[identifier] }, in: app,
                                          direction: .towardBottom, message: "Payroll navigation must be reachable")
        try requireCondition(control.isEnabled, message: "Requested payroll navigation must be enabled")
        control.tap()
    }

    // MARK: - Onboarding

    @MainActor
    private func completeFixedPerShiftOnboarding(
        in app: XCUIApplication,
        scheduledPayroll: Bool = true,
        name: String = "Runtime shift",
        pay: String = "1.004"
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
        workTypeName.typeText(name)

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
        reachableAmount.typeText(pay)

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

        let cycleTitle = scheduledPayroll ? "Calendar month" : "One shift"
        let calendarMonth = try requireElement(
            app.buttons[cycleTitle],
            message: "\(cycleTitle) option must exist"
        )

        let reachableCalendarMonth = try scrollToHittable(
            calendarMonth,
            in: app,
            direction: .towardBottom,
            message: "\(cycleTitle) option must be reachable"
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

        let difference = try requireElement(
            app.staticTexts["paycheckResult.difference.value"],
            message: "Difference must exist"
        )
        XCTAssertTrue(difference.label.contains("Positive difference less than"))
        XCTAssertTrue(normalizedAmountLabel(difference.label).contains("0.01"))
        XCTAssertFalse(app.descendants(matching: .any)["paycheckResult.exact.difference"].exists)
        attachScreenshot(named: "04-paycheck-result-top", from: app)

        let toggle = try scrollToHittable(
            requerying: { app.buttons["paycheckResult.exact.toggle"] },
            in: app, direction: .towardBottom,
            message: "Exact amounts disclosure must be reachable"
        )
        toggle.tap()
        XCTAssertEqual(toggle.label, "Hide exact amounts")

        let exactValues = [
            ("paycheckResult.exact.expected", "2.008 EUR"),
            ("paycheckResult.exact.actual", "2.01 EUR"),
            ("paycheckResult.exact.difference", "+0.002 EUR")
        ] + (0 ... 1).flatMap { index in
            [
                ("paycheckResult.breakdown.row.\(index).exactRate", "1.004 EUR / shift"),
                ("paycheckResult.breakdown.row.\(index).exactAmount", "1.004 EUR")
            ]
        }
        for (identifier, amount) in exactValues {
            let field = try requireElement(app.descendants(matching: .any)[identifier],
                                           message: "Exact evidence must remain available for \(identifier)")
            XCTAssertEqual(field.value as? String, amount)
        }

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
        cardIdentifier: String,
        in app: XCUIApplication,
        newStart: ShiftTime,
        newEnd: ShiftTime
    ) throws -> String {
        let identifier = cardIdentifier

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

        try assertShiftsExists(in: app)

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

        try assertShiftsExists(in: app)

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
        let count = try requireElement(app.buttons["home.savedShifts"], message: "Saved Shifts count must exist")
        XCTAssertEqual(count.value as? String, String(expected))
        XCTAssertEqual(homeRecentCards(in: app).count, min(expected, 4))
        try openFullShiftHistory(in: app)
        XCTAssertEqual(shiftCards(in: app).count, expected)
        selectHome(in: app)

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

    @MainActor
    private func selectHome(in app: XCUIApplication) {
        app.tabBars.firstMatch.buttons.element(boundBy: 0).tap()
    }

    @MainActor
    private func assertShiftsExists(in app: XCUIApplication) throws {
        _ = try requireElement(app.otherElements["shifts.screen"], message: "Full Shifts tab must be visible")
        XCTAssertTrue(app.tabBars.firstMatch.buttons.element(boundBy: 1).isSelected)
    }

    @MainActor
    private func openFullShiftHistory(in app: XCUIApplication) throws {
        let shortcut = try scrollToHittable(
            requerying: { app.buttons["home.savedShifts"] },
            in: app, direction: .towardTop, message: "Saved Shifts shortcut must be reachable"
        )
        shortcut.tap()
        try assertShiftsExists(in: app)
    }

    private func ledgerCardID(for homeID: String) -> String {
        "overview.shift." + homeID.dropFirst("home.recentShift.".count)
    }

    private func homeCardID(for ledgerID: String) -> String {
        "home.recentShift." + ledgerID.dropFirst("overview.shift.".count)
    }

    @MainActor
    private func homeRecentCards(in app: XCUIApplication) -> [XCUIElement] {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.recentShift."))
            .allElementsBoundByIndex
    }

    // MARK: - Shift identity

    @MainActor
    private func firstShiftCardIdentifier(
        in app: XCUIApplication
    ) throws -> String {
        let first = try XCTUnwrap(
            homeRecentCards(in: app).first,
            "Expected at least one persisted Shift card"
        )

        return try XCTUnwrap(
            first.identifier.isEmpty
                ? nil
                : ledgerCardID(for: first.identifier),
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
            XCTAssertFalse(app.buttons[cardIdentifier + ".edit"].exists)
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

        attachScreenshot(
            named: "03b-overview-expanded",
            from: app
        )

        let editIdentifier = "\(cardIdentifier).edit"
        let edit = try scrollToHittable(
            requerying: { app.buttons[editIdentifier] },
            in: app,
            direction: .towardBottom,
            message: "Edit Shift for \(cardIdentifier) must be reachable"
        )
        XCTAssertEqual(app.buttons.matching(identifier: editIdentifier).count, 1)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "Expanded Shift accessibility hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        attachScreenshot(named: "03b-edit-action-hittable", from: app)
        XCTAssertTrue(expandedCard.isSelected)
        XCTAssertTrue(String(describing: expandedCard.value).contains("Expanded"))
        edit.tap()

        _ = try requireElement(
            app.scrollViews["editShift.screen"],
            message: "Edit Shift screen must appear after tapping \(editIdentifier)"
        )

        attachScreenshot(
            named: "03c-edit-shift",
            from: app
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
        scrollView targetScrollView: XCUIElement? = nil,
        message: String
    ) throws -> XCUIElement {
        var element = try requireElement(query(), message: message)

        if element.isHittable {
            return element
        }

        let scrollView = targetScrollView ?? app.scrollViews.firstMatch

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
    private func isolatedApplication() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SHIFTLEDGER_UI_TEST_STORE"] = "1"
        return app
    }

    @MainActor
    private func makeApplication(
        resetStore: Bool = false
    ) -> XCUIApplication {
        let app = isolatedApplication()

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

extension ShiftLedgerUITests {
    @MainActor
    func testSL567ShiftHistoryFiltersAndSort() throws {
        let app = makeApplication(resetStore: true)
        app.launch()
        try completeFixedPerShiftOnboarding(in: app, scheduledPayroll: false, name: "Desk", pay: "1.004")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        let today = try XCTUnwrap(calendar.date(bySettingHour: 8, minute: 0, second: 0, of: .now))
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: today))
        try addCalendarShift(start: yesterday, calendar: calendar, in: app)
        let oldID = try firstShiftCardIdentifier(in: app)

        app.tabBars.buttons["Settings"].tap()
        app.buttons["settings.workTypes"].tap()
        app.buttons["workTypes.add"].tap()
        let name = app.textFields["addWorkType.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Field\n")
        app.buttons["addWorkType.basis.fixedPerShift"].tap()
        let rate = try scrollToHittable(app.textFields["addWorkType.amount"], in: app,
                                        direction: .towardBottom, message: "Work type rate")
        rate.tap()
        rate.typeText("1.003")
        let saveType = app.navigationBars.buttons["addWorkType.save"]
        XCTAssertTrue(saveType.isEnabled)
        saveType.tap()
        app.tabBars.buttons["Home"].tap()

        let add = try scrollToHittable(app.buttons["overview.addShift"], in: app,
                                       direction: .towardBottom, message: "Add shift for Field")
        add.tap()
        app.buttons["addShift.workType"].tap()
        app.cells["Field"].tap()
        try selectCalendarDate(today, rowIdentifier: "addShift.start", calendar: calendar, in: app)
        let end = today.addingTimeInterval(3 * 3600)
        try selectCalendarDate(end, rowIdentifier: "addShift.end", calendar: calendar, in: app)
        app.switches["addShift.unpaidBreak"].tap()
        try selectCalendarDate(today.addingTimeInterval(3600), rowIdentifier: "addShift.breakStart", calendar: calendar, in: app)
        try selectCalendarDate(today.addingTimeInterval(5400), rowIdentifier: "addShift.breakEnd", calendar: calendar, in: app)
        app.navigationBars.buttons["Save"].tap()
        try assertOverviewExists(in: app)
        let homeIDs = homeRecentCards(in: app).map(\.identifier)
        XCTAssertEqual(homeIDs.count, 2)
        let newID = try XCTUnwrap(homeIDs.map(ledgerCardID(for:)).first { $0 != oldID })
        app.tabBars.buttons["Shifts"].tap()

        let filters = app.buttons["shiftHistory.filters"]
        let sort = app.buttons["shiftHistory.sort"]
        let apply = app.buttons["shiftHistory.apply"]
        let filterScroll = app.scrollViews["shiftHistory.filterScroll"]
        let historyScroll = app.scrollViews["overview.pageScroll"]
        let rows = app.buttons.matching(NSPredicate(format: "identifier MATCHES %@", "overview[.]shift[.][0-9A-Fa-f-]{36}"))
        func sheetButton(_ id: String) throws -> XCUIElement {
            try scrollToHittable(requerying: { app.buttons["shiftHistory." + id] }, in: app, direction: .towardBottom, scrollView: filterScroll, message: "Filter action \(id)")
        }
        filters.tap()
        XCTAssertTrue(filterScroll.waitForExistence(timeout: 5))
        attachScreenshot(named: "SL567-en-filters", from: app)
        app.buttons["shiftHistory.date.month"].tap()
        app.navigationBars.buttons["shiftHistory.cancel"].tap()
        XCTAssertEqual(rows.allElementsBoundByIndex.map(\.identifier), [newID, oldID])

        sort.tap()
        attachScreenshot(named: "SL567-en-sort", from: app)
        for (index, scenario) in [
            ("Oldest first", [oldID, newID]),
            ("Newest first", [newID, oldID]),
            ("Lowest amount first", [newID, oldID]),
            ("Highest amount first", [oldID, newID])
        ].enumerated() {
            if index > 0 { sort.tap() }
            app.buttons[scenario.0].tap()
            XCTAssertEqual(sort.value as? String, scenario.0)
            XCTAssertEqual(rows.allElementsBoundByIndex.map(\.identifier), scenario.1)
            sort.tap()
            let selected = app.buttons[scenario.0]
            XCTAssertTrue(selected.exists)
            XCTAssertTrue(selected.isSelected, "Current sort should expose its selected state")
            selected.tap()
        }
        app.buttons[oldID].tap()
        XCTAssertTrue(app.buttons[oldID + ".edit"].exists)
        try scrollToHittable(requerying: { app.buttons[newID] }, in: app, direction: .towardBottom, scrollView: historyScroll, message: "Next sorted shift").tap()
        XCTAssertTrue(app.buttons[newID + ".edit"].exists)
        XCTAssertFalse(app.buttons[oldID + ".edit"].exists)
        try scrollToHittable(filters, in: app, direction: .towardTop, message: "Filters after expansion").tap()
        let field = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@",
                                                      "shiftHistory.workType.", "Field")).firstMatch
        XCTAssertTrue(field.exists)
        field.tap()
        let minimum = app.textFields["shiftHistory.amount.minimum"]
        try scrollToHittable(requerying: { minimum }, in: app, direction: .towardBottom, scrollView: filterScroll, message: "Exact minimum").tap()
        minimum.typeText("1.003")
        app.toolbars.buttons["Done"].tap()
        try sheetButton("apply").tap()
        XCTAssertTrue(app.staticTexts["Showing 1 of 2"].waitForExistence(timeout: 5))
        XCTAssertEqual(filters.value as? String, "2 active filter groups")
        XCTAssertEqual(rows.allElementsBoundByIndex.map(\.identifier), [newID])
        attachScreenshot(named: "SL567-en-active", from: app)
        let edit = try scrollToHittable(requerying: { app.buttons[newID + ".edit"] }, in: app,
                                        direction: .towardBottom, scrollView: historyScroll, message: "Filtered edit")
        edit.tap()
        XCTAssertTrue(app.scrollViews["editShift.screen"].waitForExistence(timeout: 5))
        app.buttons["editShift.workType"].tap()
        app.cells["Desk"].tap()
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Showing 0 of 2"].waitForExistence(timeout: 5))
        XCTAssertEqual(filters.value as? String, "2 active filter groups")
        XCTAssertFalse(app.buttons[newID].exists)
        XCTAssertFalse(app.buttons[newID + ".edit"].exists)
        attachScreenshot(named: "SL567-en-edit-exits", from: app)
        app.buttons["shiftHistory.reset"].tap()
        XCTAssertTrue(app.buttons[newID].exists)
        attachScreenshot(named: "SL567-en-edit-restored", from: app)
        XCTAssertEqual(rows.allElementsBoundByIndex.map(\.identifier), [newID, oldID])
        for id in [newID, oldID] {
            let row = try scrollToHittable(requerying: { app.buttons[id] }, in: app,
                                           direction: .towardBottom, scrollView: historyScroll,
                                           message: "Verify edited shift details")
            row.tap()
            XCTAssertTrue(app.buttons[id + ".edit"].waitForExistence(timeout: 5))
            let description = app.buttons[id].label
            XCTAssertTrue(description.contains("Work type: Desk"), description)
            XCTAssertTrue(description.contains("Rate: €1.004 / shift"), description)
            XCTAssertTrue(description.contains("Exact contribution: €1.004"), description)
        }

        try scrollToHittable(filters, in: app, direction: .towardTop, message: "Filters after edit").tap()
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "shiftHistory.workType.", "Desk")).firstMatch.tap()
        let minAfterEdit = app.textFields["shiftHistory.amount.minimum"]
        try scrollToHittable(requerying: { minAfterEdit }, in: app, direction: .towardBottom, scrollView: filterScroll, message: "Minimum after edit").tap()
        minAfterEdit.typeText("1.003")
        app.toolbars.buttons["Done"].tap()
        try sheetButton("apply").tap()
        XCTAssertTrue(app.staticTexts["Showing 2 of 2"].waitForExistence(timeout: 5))
        try scrollToHittable(filters, in: app, direction: .towardTop, message: "Filters before draft reset").tap()
        try sheetButton("resetDraft").tap()
        app.navigationBars.buttons["shiftHistory.cancel"].tap()
        XCTAssertTrue(app.staticTexts["Showing 2 of 2"].exists)
        filters.tap()
        let maximum = app.textFields["shiftHistory.amount.maximum"]
        try scrollToHittable(requerying: { maximum }, in: app, direction: .towardBottom, scrollView: filterScroll, message: "Maximum amount").tap()
        maximum.typeText("0")
        app.toolbars.buttons["Done"].tap()
        XCTAssertFalse(apply.isEnabled)
        XCTAssertTrue(app.staticTexts["shiftHistory.validation"].exists)
        try sheetButton("resetDraft").tap()
        try scrollToHittable(requerying: { maximum }, in: app, direction: .towardTop, scrollView: filterScroll, message: "Maximum after draft reset").tap()
        maximum.typeText("0")
        app.toolbars.buttons["Done"].tap()
        try sheetButton("apply").tap()
        XCTAssertTrue(app.staticTexts["shiftHistory.noMatches"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Showing 0 of 2"].exists)
        attachScreenshot(named: "SL567-en-empty", from: app)
        app.buttons["shiftHistory.reset"].tap()
        XCTAssertEqual(rows.allElementsBoundByIndex.map(\.identifier), [newID, oldID])
        XCTAssertEqual(sort.value as? String, "Highest amount first")
        app.tabBars.buttons["Home"].tap()
        XCTAssertEqual(homeRecentCards(in: app).map(\.identifier), homeIDs)
        app.terminate()

        for size in ["L", "AccessibilityXXXL"] {
            let russian = launchRussianTabs(size: size)
            russian.tabBars.buttons["Смены"].tap()
            let button = russian.buttons["shiftHistory.filters"]
            _ = try scrollToHittable(button, in: russian, direction: .towardBottom, message: "RU filter controls")
            attachScreenshot(named: "SL567-ru-\(size)-header", from: russian)
            button.tap()
            let form = russian.scrollViews["shiftHistory.filterScroll"]
            XCTAssertTrue(form.waitForExistence(timeout: 5))
            XCTAssertTrue(russian.buttons["shiftHistory.date.all"].exists)
            attachScreenshot(named: "SL567-ru-\(size)-filters", from: russian)
            if size != "L" {
                _ = try scrollToHittable(requerying: { russian.buttons["shiftHistory.apply"] }, in: russian,
                                          direction: .towardBottom, scrollView: form, message: "AXXXL Apply")
                attachScreenshot(named: "SL567-ru-AXXXL-filters-bottom", from: russian)
            }
            russian.terminate()
        }
    }
    @MainActor
    func testSL567AccessibilityEvidence() throws {
        let app = makeApplication(resetStore: true)
        app.launchArguments.append("-ui-testing-seed-job")
        app.launch()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        let fixtureStart = try XCTUnwrap(calendar.date(bySettingHour: 8, minute: 0, second: 0, of: .now))
        try addCalendarShift(start: fixtureStart, calendar: calendar, in: app)
        app.tabBars.buttons["Shifts"].tap()
        XCTAssertTrue(app.buttons["shiftHistory.filters"].waitForExistence(timeout: 10))
        attachScreenshot(named: "SL567-en-L-header", from: app)
        app.terminate()

        let english = isolatedApplication()
        english.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                                   "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        english.launch()
        english.tabBars.buttons["Shifts"].tap()
        let enFilter = english.buttons["shiftHistory.filters"]
        _ = try scrollToHittable(enFilter, in: english, direction: .towardBottom, message: "English AXXXL controls")
        attachScreenshot(named: "SL567-en-AXXXL-header", from: english)
        english.terminate()

        let appRU = launchRussianTabs(size: "AccessibilityXXXL")
        appRU.tabBars.buttons["Смены"].tap()
        let filter = appRU.buttons["shiftHistory.filters"]
        _ = try scrollToHittable(filter, in: appRU, direction: .towardBottom, message: "RU AXXXL filters")
        filter.tap()
        let scroll = appRU.scrollViews["shiftHistory.filterScroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        let custom = appRU.buttons["shiftHistory.date.custom"]
        try scrollToHittable(requerying: { custom }, in: appRU, direction: .towardBottom,
                             scrollView: scroll, message: "Custom dates").tap()
        let start = appRU.datePickers["shiftHistory.date.start"]
        _ = try scrollToHittable(requerying: { start }, in: appRU, direction: .towardBottom,
                                 scrollView: scroll, message: "Date start")
        attachScreenshot(named: "SL567-ru-AXXXL-custom", from: appRU)
        let minimum = appRU.textFields["shiftHistory.amount.minimum"]
        try scrollToHittable(requerying: { minimum }, in: appRU, direction: .towardBottom,
                             scrollView: scroll, message: "Minimum amount").tap()
        XCTAssertTrue(appRU.keyboards.firstMatch.waitForExistence(timeout: 5))
        minimum.typeText("1")
        XCTAssertEqual(minimum.value as? String, "1")
        let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screen.name = "SL567-ru-AXXXL-software-keyboard"
        screen.lifetime = .keepAlways
        add(screen)
        scroll.swipeUp()
        XCTAssertTrue(appRU.keyboards.firstMatch.exists)
        let hierarchy = XCTAttachment(string: appRU.debugDescription)
        hierarchy.name = "SL567-filter-accessibility-hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        appRU.toolbars.buttons.firstMatch.tap()
        XCTAssertTrue(appRU.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        _ = try scrollToHittable(requerying: { appRU.buttons["shiftHistory.resetDraft"] }, in: appRU,
                                 direction: .towardBottom, scrollView: scroll, message: "Reset after keyboard")
        let apply = appRU.buttons["shiftHistory.apply"]
        try scrollToHittable(requerying: { apply }, in: appRU, direction: .towardBottom,
                             scrollView: scroll, message: "Apply after keyboard").tap()
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
        _ = try scrollToHittable(filter, in: appRU, direction: .towardTop, message: "Active RU filter")
        attachScreenshot(named: "SL567-ru-AXXXL-active", from: appRU)
        appRU.terminate()
    }

}
