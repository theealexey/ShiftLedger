import Foundation
import Testing
@testable import ShiftLedger

@MainActor
struct PayPeriodSetupViewModelTests {
    @Test("Без выбора периода продолжить нельзя")
    func noFrequencyDisablesContinue() {
        let viewModel = makeViewModel()

        #expect(viewModel.selectedFrequency == nil)
        #expect(viewModel.canContinue == false)
        #expect(viewModel.payPeriodSchedule == nil)
    }

    @Test("Недельный период без anchor не готов")
    func weeklyWithoutAnchorDisablesContinue() {
        let viewModel = makeViewModel()
        viewModel.selectFrequency(.weekly)

        #expect(viewModel.requiresAnchorDate)
        #expect(viewModel.canContinue == false)
        #expect(viewModel.payPeriodSchedule == nil)
    }

    @Test("Недельный период с anchor готов")
    func weeklyWithAnchorEnablesContinue() throws {
        let anchor = try makeDate(year: 2026, month: 8, day: 3)
        let viewModel = makeViewModel()
        viewModel.selectFrequency(.weekly)
        viewModel.selectAnchorDate(anchor)

        #expect(viewModel.canContinue)
        #expect(viewModel.payPeriodSchedule == .weekly(anchorDate: anchor))
    }

    @Test("Двухнедельный период без anchor не готов")
    func biweeklyWithoutAnchorDisablesContinue() {
        let viewModel = makeViewModel()
        viewModel.selectFrequency(.biweekly)

        #expect(viewModel.requiresAnchorDate)
        #expect(viewModel.canContinue == false)
        #expect(viewModel.payPeriodSchedule == nil)
    }

    @Test("Двухнедельный период с anchor готов")
    func biweeklyWithAnchorEnablesContinue() throws {
        let anchor = try makeDate(year: 2026, month: 8, day: 3)
        let viewModel = makeViewModel()
        viewModel.selectFrequency(.biweekly)
        viewModel.selectAnchorDate(anchor)

        #expect(viewModel.canContinue)
        #expect(viewModel.payPeriodSchedule == .biweekly(anchorDate: anchor))
    }

    @Test("Календарный месяц не требует anchor")
    func calendarMonthlyEnablesContinueWithoutAnchor() {
        let viewModel = makeViewModel()
        viewModel.selectFrequency(.calendarMonthly)

        #expect(viewModel.requiresAnchorDate == false)
        #expect(viewModel.canContinue)
        #expect(viewModel.payPeriodSchedule == .calendarMonthly)
    }

    @Test("Выбранный недельный период точно маппится в Domain")
    func weeklyMappingIsExact() throws {
        let anchor = try makeDate(year: 2026, month: 8, day: 3)
        let viewModel = makeViewModel()
        viewModel.selectFrequency(.weekly)
        viewModel.selectAnchorDate(anchor)

        #expect(viewModel.payPeriodSchedule == PayPeriodSchedule.weekly(anchorDate: anchor))
    }

    @Test("Выбранный двухнедельный период точно маппится в Domain")
    func biweeklyMappingIsExact() throws {
        let anchor = try makeDate(year: 2026, month: 8, day: 3)
        let viewModel = makeViewModel()
        viewModel.selectFrequency(.biweekly)
        viewModel.selectAnchorDate(anchor)

        #expect(viewModel.payPeriodSchedule == PayPeriodSchedule.biweekly(anchorDate: anchor))
    }

    @Test("Выбранный календарный месяц точно маппится в Domain")
    func calendarMonthlyMappingIsExact() {
        let viewModel = makeViewModel()
        viewModel.selectFrequency(.calendarMonthly)

        #expect(viewModel.payPeriodSchedule == PayPeriodSchedule.calendarMonthly)
    }

    @Test("Переключение частоты сохраняет anchor")
    func switchingFrequencyPreservesAnchor() throws {
        let anchor = try makeDate(year: 2026, month: 8, day: 14)
        let viewModel = makeViewModel()
        viewModel.selectFrequency(.weekly)
        viewModel.selectAnchorDate(anchor)
        viewModel.selectFrequency(.biweekly)

        #expect(viewModel.anchorDate == anchor)
        #expect(viewModel.payPeriodSchedule == .biweekly(anchorDate: anchor))
    }

    @Test("Состояние ставки и валюты из Step 1 сохраняется")
    func stepOneValuesArePreserved() {
        let viewModel = makeViewModel()
        viewModel.selectFrequency(.calendarMonthly)

        #expect(viewModel.draft.hourlyRateText == "24.50")
        #expect(viewModel.draft.currencyCode == "EUR")
    }

    @Test("Выбранный anchor LocalDate сохраняется без изменения")
    func anchorLocalDateIsPreservedExactly() throws {
        let anchor = try makeDate(year: 2026, month: 12, day: 31)
        let viewModel = makeViewModel()
        viewModel.selectFrequency(.weekly)
        viewModel.selectAnchorDate(anchor)

        #expect(viewModel.anchorDate == anchor)
        #expect(viewModel.draft.payPeriodAnchorDate == anchor)
    }

    @Test("Domain period использует выбранный двухнедельный anchor")
    func selectedScheduleCalculatesExistingDomainPeriod() throws {
        let anchor = try makeDate(year: 2026, month: 8, day: 3)
        let date = try makeDate(year: 2026, month: 8, day: 16)
        let expectedEnd = try makeDate(year: 2026, month: 8, day: 17)
        let viewModel = makeViewModel()
        viewModel.selectFrequency(.biweekly)
        viewModel.selectAnchorDate(anchor)

        let schedule = try #require(viewModel.payPeriodSchedule)
        let period = try schedule.period(containing: date)

        #expect(period == PayPeriod(start: anchor, endExclusive: expectedEnd))
    }

    private func makeViewModel() -> PayPeriodSetupViewModel {
        let jobSetupViewModel = JobSetupViewModel(
            initialCurrencyCode: "EUR",
            initialTimeZoneIdentifier: "Europe/Stockholm",
            decimalInputLocale: Locale(identifier: "en_US")
        )
        jobSetupViewModel.updateHourlyRateText("24.50")
        return PayPeriodSetupViewModel(draft: jobSetupViewModel.draft)
    }

    private func makeDate(year: Int, month: Int, day: Int) throws -> LocalDate {
        try LocalDate(year: year, month: month, day: day)
    }
}
