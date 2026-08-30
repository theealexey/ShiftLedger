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

    @Test("Положительная ставка с точкой парсится без округления")
    func parsesEnglishHourlyRateWithoutRounding() {
        let viewModel = makeViewModel()

        viewModel.updateHourlyRateText("24.50")

        #expect(viewModel.draft.hourlyRateText == "24.50")
        #expect(viewModel.hourlyRate == Decimal(string: "24.50"))
        #expect(viewModel.canContinue)
    }

    @Test("Точная дробная ставка сохраняет Decimal точность")
    func preservesExactHourlyRateWithoutRounding() {
        let viewModel = makeViewModel()

        viewModel.updateHourlyRateText("17.125")

        #expect(viewModel.hourlyRate == Decimal(string: "17.125"))
        #expect(viewModel.canContinue)
    }

    @Test("Нулевая ставка парсится, но не позволяет продолжить")
    func zeroHourlyRateDisablesContinue() {
        let viewModel = makeViewModel()

        viewModel.updateHourlyRateText("0")

        #expect(viewModel.hourlyRate == .zero)
        #expect(viewModel.canContinue == false)
    }

    @Test(
        "Некорректная английская запись ставки отклоняется",
        arguments: ["1234ю50", "1234abc", "24.", "1..2", "1e3", "-10", "+10", "€24.50", "1,234.50", "12 34"]
    )
    func rejectsMalformedEnglishHourlyRate(_ value: String) {
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

    @Test("Запись с запятой принимается для русского locale")
    func parsesRussianHourlyRateWithCommaSeparator() {
        let viewModel = JobSetupViewModel(
            initialCurrencyCode: "EUR",
            initialTimeZoneIdentifier: "Europe/Stockholm",
            decimalInputLocale: Locale(identifier: "ru_RU")
        )

        viewModel.updateHourlyRateText("24,50")

        #expect(viewModel.hourlyRate == Decimal(string: "24.50"))
        #expect(viewModel.canContinue)
    }

    @Test("Некорректная запись с запятой отклоняется", arguments: ["24.50", "24,", "12,3,4"])
    func rejectsMalformedSwedishHourlyRate(_ value: String) {
        let viewModel = JobSetupViewModel(
            initialCurrencyCode: "SEK",
            initialTimeZoneIdentifier: "Europe/Stockholm",
            decimalInputLocale: Locale(identifier: "sv_SE")
        )

        viewModel.updateHourlyRateText(value)

        #expect(viewModel.hourlyRate == nil)
        #expect(viewModel.canContinue == false)
    }

    private func makeViewModel() -> JobSetupViewModel {
        JobSetupViewModel(
            initialCurrencyCode: "EUR",
            initialTimeZoneIdentifier: "Europe/Stockholm",
            decimalInputLocale: Locale(identifier: "en_US")
        )
    }
}
