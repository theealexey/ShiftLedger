import Foundation
import Testing
@testable import ShiftLedger

@MainActor
struct PayPeriodSetupViewModelTests {
    @Test("Оплата за смену готова без anchor")
    func perShiftEnablesContinueWithoutAnchor() {
        let viewModel = makeViewModel()
        viewModel.selectCycleKind(.perShift)

        #expect(viewModel.requiresAnchorDate == false)
        #expect(viewModel.canContinue)
        #expect(viewModel.payCalculationCycle == .perShift)
    }

    @Test("Оплата за смену не передаёт anchor в Domain")
    func perShiftIgnoresPreservedAnchorInDomain() throws {
        let anchor = try makeDate(year: 2026, month: 8, day: 30)
        let viewModel = makeViewModel()
        viewModel.selectCycleKind(.weekly)
        viewModel.selectAnchorDate(anchor)
        viewModel.selectCycleKind(.perShift)

        #expect(viewModel.anchorDate == anchor)
        #expect(viewModel.payCalculationCycle == .perShift)
    }

    @Test("Выбор расчётного цикла сохраняет данные предыдущих шагов")
    func cycleSelectionPreservesPreviousStepValues() throws {
        let anchor = try makeDate(year: 2026, month: 8, day: 30)
        var draft = makeViewModel().draft
        draft.name = "Karolinska Hospital"
        draft.currencyCode = "AUD"
        draft.timeZoneIdentifier = "Europe/Stockholm"
        draft.payPeriodAnchorDate = anchor
        let viewModel = PayPeriodSetupViewModel(draft: draft)

        viewModel.selectCycleKind(.perShift)

        #expect(viewModel.draft.basePayAmountText == "24.50")
        #expect(viewModel.draft.currencyCode == "AUD")
        #expect(viewModel.draft.timeZoneIdentifier == "Europe/Stockholm")
        #expect(viewModel.draft.name == "Karolinska Hospital")
        #expect(viewModel.draft.payPeriodAnchorDate == anchor)
    }

    @Test("Переключение обратно на неделю восстанавливает anchor")
    func switchingBackFromPerShiftRestoresScheduledWeekly() throws {
        let anchor = try makeDate(year: 2026, month: 8, day: 30)
        let viewModel = makeViewModel()
        viewModel.selectCycleKind(.weekly)
        viewModel.selectAnchorDate(anchor)
        viewModel.selectCycleKind(.perShift)
        viewModel.selectCycleKind(.weekly)

        #expect(viewModel.payCalculationCycle == .scheduled(.weekly(anchorDate: anchor)))
    }

    @Test("Без выбора периода продолжить нельзя")
    func noFrequencyDisablesContinue() {
        let viewModel = makeViewModel()

        #expect(viewModel.selectedCycleKind == nil)
        #expect(viewModel.canContinue == false)
        #expect(viewModel.payCalculationCycle == nil)
    }

    @Test("Недельный период без anchor не готов")
    func weeklyWithoutAnchorDisablesContinue() {
        let viewModel = makeViewModel()
        viewModel.selectCycleKind(.weekly)

        #expect(viewModel.requiresAnchorDate)
        #expect(viewModel.canContinue == false)
        #expect(viewModel.payCalculationCycle == nil)
    }

    @Test("Недельный период с anchor готов")
    func weeklyWithAnchorEnablesContinue() throws {
        let anchor = try makeDate(year: 2026, month: 8, day: 3)
        let viewModel = makeViewModel()
        viewModel.selectCycleKind(.weekly)
        viewModel.selectAnchorDate(anchor)

        #expect(viewModel.canContinue)
        #expect(viewModel.payCalculationCycle == .scheduled(.weekly(anchorDate: anchor)))
    }

    @Test("Двухнедельный период без anchor не готов")
    func biweeklyWithoutAnchorDisablesContinue() {
        let viewModel = makeViewModel()
        viewModel.selectCycleKind(.biweekly)

        #expect(viewModel.requiresAnchorDate)
        #expect(viewModel.canContinue == false)
        #expect(viewModel.payCalculationCycle == nil)
    }

    @Test("Двухнедельный период с anchor готов")
    func biweeklyWithAnchorEnablesContinue() throws {
        let anchor = try makeDate(year: 2026, month: 8, day: 3)
        let viewModel = makeViewModel()
        viewModel.selectCycleKind(.biweekly)
        viewModel.selectAnchorDate(anchor)

        #expect(viewModel.canContinue)
        #expect(viewModel.payCalculationCycle == .scheduled(.biweekly(anchorDate: anchor)))
    }

    @Test("Календарный месяц не требует anchor")
    func calendarMonthlyEnablesContinueWithoutAnchor() {
        let viewModel = makeViewModel()
        viewModel.selectCycleKind(.calendarMonthly)

        #expect(viewModel.requiresAnchorDate == false)
        #expect(viewModel.canContinue)
        #expect(viewModel.payCalculationCycle == .scheduled(.calendarMonthly))
    }

    @Test("Выбранный недельный период точно маппится в Domain")
    func weeklyMappingIsExact() throws {
        let anchor = try makeDate(year: 2026, month: 8, day: 3)
        let viewModel = makeViewModel()
        viewModel.selectCycleKind(.weekly)
        viewModel.selectAnchorDate(anchor)

        #expect(viewModel.payCalculationCycle == .scheduled(.weekly(anchorDate: anchor)))
    }

    @Test("Выбранный двухнедельный период точно маппится в Domain")
    func biweeklyMappingIsExact() throws {
        let anchor = try makeDate(year: 2026, month: 8, day: 3)
        let viewModel = makeViewModel()
        viewModel.selectCycleKind(.biweekly)
        viewModel.selectAnchorDate(anchor)

        #expect(viewModel.payCalculationCycle == .scheduled(.biweekly(anchorDate: anchor)))
    }

    @Test("Выбранный календарный месяц точно маппится в Domain")
    func calendarMonthlyMappingIsExact() {
        let viewModel = makeViewModel()
        viewModel.selectCycleKind(.calendarMonthly)

        #expect(viewModel.payCalculationCycle == .scheduled(.calendarMonthly))
    }

    @Test("Переключение частоты сохраняет anchor")
    func switchingFrequencyPreservesAnchor() throws {
        let anchor = try makeDate(year: 2026, month: 8, day: 14)
        let viewModel = makeViewModel()
        viewModel.selectCycleKind(.weekly)
        viewModel.selectAnchorDate(anchor)
        viewModel.selectCycleKind(.biweekly)

        #expect(viewModel.anchorDate == anchor)
        #expect(viewModel.payCalculationCycle == .scheduled(.biweekly(anchorDate: anchor)))
    }

    @Test("Состояние ставки и валюты из Step 1 сохраняется")
    func stepOneValuesArePreserved() {
        let viewModel = makeViewModel()
        viewModel.selectCycleKind(.calendarMonthly)

        #expect(viewModel.draft.basePayAmountText == "24.50")
        #expect(viewModel.draft.currencyCode == "EUR")
    }

    @Test("Выбранный anchor LocalDate сохраняется без изменения")
    func anchorLocalDateIsPreservedExactly() throws {
        let anchor = try makeDate(year: 2026, month: 12, day: 31)
        let viewModel = makeViewModel()
        viewModel.selectCycleKind(.weekly)
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
        viewModel.selectCycleKind(.biweekly)
        viewModel.selectAnchorDate(anchor)

        let cycle = try #require(viewModel.payCalculationCycle)
        let schedule: PayPeriodSchedule
        switch cycle {
        case let .scheduled(value): schedule = value
        case .perShift: return
        }
        let period = try schedule.period(containing: date)

        #expect(period == PayPeriod(start: anchor, endExclusive: expectedEnd))
    }

    private func makeViewModel() -> PayPeriodSetupViewModel {
        let jobSetupViewModel = JobSetupViewModel(
            initialCurrencyCode: "EUR",
            initialTimeZoneIdentifier: "Europe/Stockholm",
            decimalInputLocale: Locale(identifier: "en_US")
        )
        jobSetupViewModel.selectBasePayBasis(.hourly)
        jobSetupViewModel.updateBasePayAmountText("24.50")
        return PayPeriodSetupViewModel(draft: jobSetupViewModel.draft)
    }

    private func makeDate(year: Int, month: Int, day: Int) throws -> LocalDate {
        try LocalDate(year: year, month: month, day: day)
    }
}
