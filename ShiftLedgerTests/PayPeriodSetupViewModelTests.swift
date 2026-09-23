import Foundation
import Testing
@testable import ShiftLedger

@MainActor
struct PayPeriodSetupViewModelTests {
    @Test("Оплата за смену готова без anchor")
    func perShiftEnablesContinueWithoutAnchor() {
        let viewModel = makeViewModel()
        viewModel.selectCycleKind(.perShift)

        #expect(viewModel.canContinue)
    }

    @Test("Оплата за смену сохраняет ранее выбранный anchor")
    func perShiftPreservesAnchor() throws {
        let anchor = try makeDate(year: 2026, month: 8, day: 30)
        let viewModel = makeViewModel()
        viewModel.selectCycleKind(.weekly)
        viewModel.selectAnchorDate(anchor)
        viewModel.selectCycleKind(.perShift)

        #expect(viewModel.anchorDate == anchor)
    }

    @Test("Выбор расчётного цикла сохраняет данные предыдущих шагов")
    func cycleSelectionPreservesPreviousStepValues() throws {
        let anchor = try makeDate(year: 2026, month: 8, day: 30)
        var draft = makeViewModel().draft
        draft.currencyCode = "AUD"
        draft.timeZoneIdentifier = "Europe/Stockholm"
        draft.payPeriodAnchorDate = anchor
        let viewModel = PayPeriodSetupViewModel(draft: draft)

        viewModel.selectCycleKind(.perShift)

        #expect(viewModel.draft.basePayAmountText == "24.50")
        #expect(viewModel.draft.currencyCode == "AUD")
        #expect(viewModel.draft.timeZoneIdentifier == "Europe/Stockholm")
        #expect(viewModel.draft.payPeriodAnchorDate == anchor)
    }

    @Test("Переключение обратно на неделю восстанавливает anchor")
    func switchingBackFromPerShiftRestoresWeeklySelection() throws {
        let anchor = try makeDate(year: 2026, month: 8, day: 30)
        let viewModel = makeViewModel()
        viewModel.selectCycleKind(.weekly)
        viewModel.selectAnchorDate(anchor)
        viewModel.selectCycleKind(.perShift)
        viewModel.selectCycleKind(.weekly)

        #expect(viewModel.selectedCycleKind == .weekly)
        #expect(viewModel.anchorDate == anchor)
    }

    @Test("Без выбора периода продолжить нельзя")
    func noFrequencyDisablesContinue() {
        let viewModel = makeViewModel()

        #expect(viewModel.selectedCycleKind == nil)
        #expect(viewModel.canContinue == false)
    }

    @Test("Недельный период без anchor не готов")
    func weeklyWithoutAnchorDisablesContinue() {
        let viewModel = makeViewModel()
        viewModel.selectCycleKind(.weekly)

        #expect(viewModel.canContinue == false)
    }

    @Test("Недельный период с anchor готов")
    func weeklyWithAnchorEnablesContinue() throws {
        let anchor = try makeDate(year: 2026, month: 8, day: 3)
        let viewModel = makeViewModel()
        viewModel.selectCycleKind(.weekly)
        viewModel.selectAnchorDate(anchor)

        #expect(viewModel.canContinue)
        #expect(viewModel.selectedCycleKind == .weekly)
        #expect(viewModel.anchorDate == anchor)
    }

    @Test("Двухнедельный период без anchor не готов")
    func biweeklyWithoutAnchorDisablesContinue() {
        let viewModel = makeViewModel()
        viewModel.selectCycleKind(.biweekly)

        #expect(viewModel.canContinue == false)
    }

    @Test("Двухнедельный период с anchor готов")
    func biweeklyWithAnchorEnablesContinue() throws {
        let anchor = try makeDate(year: 2026, month: 8, day: 3)
        let viewModel = makeViewModel()
        viewModel.selectCycleKind(.biweekly)
        viewModel.selectAnchorDate(anchor)

        #expect(viewModel.canContinue)
        #expect(viewModel.selectedCycleKind == .biweekly)
        #expect(viewModel.anchorDate == anchor)
    }

    @Test("Календарный месяц не требует anchor")
    func calendarMonthlyEnablesContinueWithoutAnchor() {
        let viewModel = makeViewModel()
        viewModel.selectCycleKind(.calendarMonthly)

        #expect(viewModel.canContinue)
        #expect(viewModel.selectedCycleKind == .calendarMonthly)
    }

    @Test("Переключение частоты сохраняет anchor")
    func switchingFrequencyPreservesAnchor() throws {
        let anchor = try makeDate(year: 2026, month: 8, day: 14)
        let viewModel = makeViewModel()
        viewModel.selectCycleKind(.weekly)
        viewModel.selectAnchorDate(anchor)
        viewModel.selectCycleKind(.biweekly)

        #expect(viewModel.anchorDate == anchor)
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
