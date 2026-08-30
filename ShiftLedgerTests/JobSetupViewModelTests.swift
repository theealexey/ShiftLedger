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

    @Test("Пустое имя не проходит name validation")
    func emptyNameIsInvalid() {
        let viewModel = makeViewModel()

        #expect(viewModel.hasValidName == false)
    }

    @Test("Имя из пробелов и переводов строк не проходит name validation")
    func whitespaceOnlyNameIsInvalid() {
        let viewModel = makeViewModel()
        viewModel.updateName(" \n\t ")

        #expect(viewModel.hasValidName == false)
    }

    @Test("Обычное имя проходит name validation")
    func validNameIsValid() {
        let viewModel = makeViewModel()
        viewModel.updateName("Clinic")

        #expect(viewModel.hasValidName)
    }

    @Test("Имя с внешними пробелами сохраняется без нормализации")
    func preservesUnnormalizedNameWhileAllowingContinue() {
        let viewModel = makeViewModel()
        viewModel.updateName("  Clinic  ")

        #expect(viewModel.draft.name == "  Clinic  ")
        #expect(viewModel.hasValidName)
    }

    @Test("updateName обновляет draft")
    func updatesNameInDraft() {
        let viewModel = makeViewModel()

        viewModel.updateName("Night clinic")

        #expect(viewModel.draft.name == "Night clinic")
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

    @Test("Пустая ставка не позволяет продолжить")
    func emptyHourlyRateDisablesContinue() {
        let viewModel = makeViewModel()

        #expect(viewModel.hourlyRate == nil)
        #expect(viewModel.canContinue == false)
    }

    @Test("Положительная дробная ставка сохраняет Decimal точность")
    func parsesPositiveHourlyRateWithoutRounding() {
        let viewModel = makeViewModel()

        viewModel.updateHourlyRateText("17.125")

        #expect(viewModel.draft.hourlyRateText == "17.125")
        #expect(viewModel.hourlyRate == Decimal(string: "17.125"))
        #expect(viewModel.canContinue)
    }

    @Test("Нулевая и отрицательная ставки не позволяют продолжить", arguments: ["0", "-17.125"])
    func rejectsNonPositiveHourlyRate(_ value: String) {
        let viewModel = makeViewModel()

        viewModel.updateHourlyRateText(value)

        #expect(viewModel.hourlyRate == nil)
        #expect(viewModel.canContinue == false)
    }

    @Test("Ставка с локальным десятичным разделителем парсится как Decimal")
    func parsesHourlyRateWithLocaleDecimalSeparator() {
        let viewModel = JobSetupViewModel(
            initialCurrencyCode: "SEK",
            initialTimeZoneIdentifier: "Europe/Stockholm",
            decimalInputLocale: Locale(identifier: "sv_SE")
        )

        viewModel.updateHourlyRateText("17,125")

        #expect(viewModel.hourlyRate == Decimal(string: "17.125"))
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
