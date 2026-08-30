import Foundation
import Testing
@testable import ShiftLedger

@MainActor
struct JobSetupViewModelTests {
    @Test("Начальный код валюты сохраняется")
    func preservesInitialCurrencyCode() {
        let viewModel = makeViewModel()

        #expect(viewModel.draft.currencyCode == "EUR")
    }

    @Test("Начальный идентификатор зоны времени сохраняется")
    func preservesInitialTimeZoneIdentifier() {
        let viewModel = makeViewModel()

        #expect(viewModel.draft.timeZoneIdentifier == "Europe/Stockholm")
    }

    @Test("Выбор валюты обновляет draft")
    func updatesCurrencyInDraft() {
        let viewModel = makeViewModel()

        #expect(viewModel.selectCurrency(code: "SEK"))
        #expect(viewModel.draft.currencyCode == "SEK")
    }

    @Test("Выбор зоны времени обновляет draft")
    func updatesTimeZoneInDraft() {
        let viewModel = makeViewModel()

        #expect(viewModel.selectTimeZone(identifier: "Europe/Helsinki"))
        #expect(viewModel.draft.timeZoneIdentifier == "Europe/Helsinki")
    }

    @Test("Некорректная валюта отклоняется без изменения draft")
    func rejectsInvalidCurrencyWithoutChangingDraft() {
        let viewModel = makeViewModel()

        #expect(viewModel.selectCurrency(code: "EURO") == false)
        #expect(viewModel.draft.currencyCode == "EUR")
    }

    @Test("Некорректная зона времени отклоняется без изменения draft")
    func rejectsInvalidTimeZoneWithoutChangingDraft() {
        let viewModel = makeViewModel()

        #expect(viewModel.selectTimeZone(identifier: "GMT+2") == false)
        #expect(viewModel.draft.timeZoneIdentifier == "Europe/Stockholm")
    }

    @Test("Без базы оплаты продолжить нельзя")
    func emptyBasePayDisablesContinue() {
        let viewModel = makeViewModel()

        #expect(viewModel.basePayAmount == nil)
        #expect(viewModel.canContinue == false)
    }

    @Test("Почасовая база с точкой парсится без округления")
    func parsesEnglishBasePayWithoutRounding() {
        let viewModel = makeViewModel()

        viewModel.selectBasePayBasis(.hourly)
        viewModel.updateBasePayAmountText("24.50")

        #expect(viewModel.draft.basePayAmountText == "24.50")
        #expect(viewModel.basePayAmount == Decimal(string: "24.50"))
        #expect(viewModel.canContinue)
    }

    @Test("Точная дробная ставка сохраняет Decimal точность")
    func preservesExactHourlyRateWithoutRounding() {
        let viewModel = makeViewModel()

        viewModel.selectBasePayBasis(.hourly)
        viewModel.updateBasePayAmountText("17.125")

        #expect(viewModel.basePayAmount == Decimal(string: "17.125"))
        #expect(viewModel.canContinue)
    }

    @Test("Нулевая ставка парсится, но не позволяет продолжить")
    func zeroHourlyRateDisablesContinue() {
        let viewModel = makeViewModel()

        viewModel.selectBasePayBasis(.hourly)
        viewModel.updateBasePayAmountText("0")

        #expect(viewModel.basePayAmount == .zero)
        #expect(viewModel.canContinue == false)
    }

    @Test(
        "Некорректная английская запись ставки отклоняется",
        arguments: ["1234ю50", "1234abc", "24.", "1..2", "1e3", "-10", "+10", "€24.50", "1,234.50", "12 34"]
    )
    func rejectsMalformedEnglishBasePay(_ value: String) {
        let viewModel = makeViewModel()

        viewModel.selectBasePayBasis(.hourly)
        viewModel.updateBasePayAmountText(value)

        #expect(viewModel.basePayAmount == nil)
        #expect(viewModel.canContinue == false)
    }

    @Test("Ставка с локальным десятичным разделителем парсится как Decimal")
    func parsesHourlyRateWithLocaleDecimalSeparator() {
        let viewModel = JobSetupViewModel(
            initialCurrencyCode: "SEK",
            initialTimeZoneIdentifier: "Europe/Stockholm",
            decimalInputLocale: Locale(identifier: "sv_SE")
        )

        viewModel.selectBasePayBasis(.hourly)
        viewModel.updateBasePayAmountText("17,125")

        #expect(viewModel.basePayAmount == Decimal(string: "17.125"))
        #expect(viewModel.canContinue)
    }

    @Test("Запись с запятой принимается для русского locale")
    func parsesRussianHourlyRateWithCommaSeparator() {
        let viewModel = JobSetupViewModel(
            initialCurrencyCode: "EUR",
            initialTimeZoneIdentifier: "Europe/Stockholm",
            decimalInputLocale: Locale(identifier: "ru_RU")
        )

        viewModel.selectBasePayBasis(.hourly)
        viewModel.updateBasePayAmountText("24,50")

        #expect(viewModel.basePayAmount == Decimal(string: "24.50"))
        #expect(viewModel.canContinue)
    }

    @Test("Некорректная запись с запятой отклоняется", arguments: ["24.50", "24,", "12,3,4"])
    func rejectsMalformedSwedishBasePay(_ value: String) {
        let viewModel = JobSetupViewModel(
            initialCurrencyCode: "SEK",
            initialTimeZoneIdentifier: "Europe/Stockholm",
            decimalInputLocale: Locale(identifier: "sv_SE")
        )

        viewModel.selectBasePayBasis(.hourly)
        viewModel.updateBasePayAmountText(value)

        #expect(viewModel.basePayAmount == nil)
        #expect(viewModel.canContinue == false)
    }

    @Test("Фиксированная база за смену позволяет продолжить")
    func fixedPerShiftBasePayEnablesContinue() {
        let viewModel = makeViewModel()
        viewModel.selectBasePayBasis(.fixedPerShift)
        viewModel.updateBasePayAmountText("4000")

        #expect(viewModel.basePayBasis == .fixedPerShift)
        #expect(viewModel.basePayAmount == Decimal(string: "4000"))
        #expect(viewModel.canContinue)
    }

    @Test("Переключение базы очищает существующую сумму")
    func switchingBasePayBasisClearsAmount() {
        let viewModel = makeViewModel()
        viewModel.selectBasePayBasis(.hourly)
        viewModel.updateBasePayAmountText("500")
        viewModel.selectBasePayBasis(.fixedPerShift)

        #expect(viewModel.basePayAmount == nil)
        #expect(viewModel.draft.basePayAmountText.isEmpty)
        #expect(viewModel.canContinue == false)
    }

    @Test("Повторный выбор той же базы не очищает сумму")
    func reselectingSameBasePayBasisPreservesAmount() {
        let viewModel = makeViewModel()
        viewModel.selectBasePayBasis(.fixedPerShift)
        viewModel.updateBasePayAmountText("4000")
        viewModel.selectBasePayBasis(.fixedPerShift)

        #expect(viewModel.draft.basePayAmountText == "4000")
        #expect(viewModel.canContinue)
    }

    private func makeViewModel() -> JobSetupViewModel {
        JobSetupViewModel(
            initialCurrencyCode: "EUR",
            initialTimeZoneIdentifier: "Europe/Stockholm",
            decimalInputLocale: Locale(identifier: "en_US")
        )
    }
}
